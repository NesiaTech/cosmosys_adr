require_dependency 'issue'

module CosmosysAdr
  # An ADR is an issue of the csAdr tracker. This patch numbers ADRs, keeps
  # their lifecycle and locks their content once they leave Proposed. Every
  # rule is a model validation, so the form, bulk edit and the REST API all
  # go through it.
  module IssuePatch
    # What an ADR says. None of it may change once the ADR is decided.
    CONTENT_ATTRIBUTES = %w[
      subject description project_id tracker_id
      adr_number adr_format adr_date adr_in_force_until adr_decision_makers adr_consulted adr_informed
      adr_supersedes_id adr_source
    ].freeze
    # Set when the ADR is created and never changed afterwards.
    IDENTITY_ATTRIBUTES = %w[adr_number adr_format adr_source].freeze
    # Dates the plugin writes when the status moves: the decision date when
    # the ADR is accepted or rejected, and the date it stops being in force
    # when it is deprecated or superseded. Nobody sets them by hand.
    STAMPED_ATTRIBUTES = %w[adr_date adr_in_force_until].freeze

    def self.included(base)
      base.class_eval do
        belongs_to :adr_supersedes, class_name: 'Issue', optional: true
        # Deleting an ADR (administrators only) clears the pointer of the ADR
        # that superseded it, so no ADR points to a missing one.
        has_many :adr_superseding_issues, class_name: 'Issue', foreign_key: :adr_supersedes_id,
                 dependent: :nullify, inverse_of: :adr_supersedes

        safe_attributes 'adr_supersedes_id',
                        if: ->(issue, _user) { issue.cosmosys_adr? }

        before_validation :cosmosys_adr_apply_defaults, on: :create
        validate :cosmosys_adr_validate
        before_create :cosmosys_adr_assign_number
        before_save :cosmosys_adr_stamp_dates
        before_save :cosmosys_adr_capture_changes
        after_save :cosmosys_adr_apply_supersession
        after_commit :cosmosys_adr_forget_request
        after_rollback :cosmosys_adr_forget_request
      end
    end

    def cosmosys_adr?
      CosmosysAdr.adr_tracker?(tracker)
    end

    def cosmosys_adr_label
      CosmosysAdr.label(adr_number)
    end

    def cosmosys_adr_status_key
      CosmosysAdr.status_key(status_id)
    end

    def cosmosys_adr_status_key_in_database
      CosmosysAdr.status_key(status_id_in_database)
    end

    # Decided ADRs are locked: only notes, relations and the transitions of
    # their lifecycle are allowed.
    def cosmosys_adr_locked?
      cosmosys_adr? && persisted? && cosmosys_adr_status_key_in_database != :proposed
    end

    # The ADR this one supersedes once accepted.
    def cosmosys_adr_superseded_by
      return nil unless cosmosys_adr? && persisted?

      superseded_ids = [CosmosysAdr.status_ids[:proposed], CosmosysAdr.status_ids[:rejected]].compact
      Issue.where(adr_supersedes_id: id).where.not(status_id: superseded_ids).order(:id).first
    end

    # ADRs of the same project this ADR may supersede: accepted ones.
    def cosmosys_adr_supersedable
      return Issue.none unless project && CosmosysAdr.status_ids[:accepted]

      scope = Issue.visible.where(project_id: project.id, status_id: CosmosysAdr.status_ids[:accepted])
                   .where.not(adr_number: nil)
      scope = scope.where.not(id: id) if persisted?
      scope.order(:adr_number)
    end

    def cosmosys_adr_actor
      @current_journal&.user || @attributes_set_by || User.current
    end

    private

    def cosmosys_adr_apply_defaults
      return unless cosmosys_adr?

      self.adr_format = CosmosysAdr::ProjectSetting.template_for(project) if adr_format.blank? && project
      self.adr_source ||= CosmosysAdr::SOURCE_COSMOSYS
      # A new ADR is a proposal: it has no decision yet.
      STAMPED_ATTRIBUTES.each { |name| self[name] = nil }
    end

    def cosmosys_adr_validate
      was_adr = persisted? && CosmosysAdr.adr_tracker_id?(tracker_id_in_database)
      if persisted? && will_save_change_to_tracker_id? && (was_adr || cosmosys_adr?)
        errors.add(:tracker_id, :cosmosys_adr_tracker_change)
      end
      return unless cosmosys_adr?

      new_record? ? cosmosys_adr_validate_create : cosmosys_adr_validate_update
      cosmosys_adr_validate_fields
    end

    def cosmosys_adr_validate_create
      errors.add(:base, I18n.t(:error_cosmosys_adr_module_disabled)) unless CosmosysAdr.module_enabled?(project)
      unless cosmosys_adr_status_key == :proposed
        errors.add(:status_id, :cosmosys_adr_must_start_proposed)
      end
      cosmosys_adr_validate_supersedes(require_accepted: true)
    end

    def cosmosys_adr_validate_update
      cosmosys_adr_validate_requested_status

      changed_identity = IDENTITY_ATTRIBUTES.select { |name| will_save_change_to_attribute?(name) }
      changed_identity.each { |name| errors.add(name, :cosmosys_adr_immutable) }
      changed_stamps = STAMPED_ATTRIBUTES.select { |name| will_save_change_to_attribute?(name) }
      changed_stamps.each { |name| errors.add(name, :cosmosys_adr_stamped) }

      if cosmosys_adr_locked? && cosmosys_adr_content_changed?
        errors.add(:base, I18n.t(:error_cosmosys_adr_locked, label: cosmosys_adr_label))
      end
      cosmosys_adr_validate_transition if will_save_change_to_status_id?
      if will_save_change_to_adr_supersedes_id?
        cosmosys_adr_validate_supersedes(require_accepted: true)
      elsif will_save_change_to_status_id? && cosmosys_adr_status_key == :accepted
        cosmosys_adr_validate_supersedes(require_accepted: true)
      end
    end

    # A status asked for through the form or the API that the user may not
    # reach. Redmine would drop it silently; for an ADR it is an error, so the
    # API answers 422 instead of pretending the decision was made.
    def cosmosys_adr_validate_requested_status
      requested = @cosmosys_adr_requested_status_key
      return if requested.nil?

      from = cosmosys_adr_status_key_in_database
      if CosmosysAdr::DECISION_TRANSITIONS.fetch(from, []).include?(requested)
        errors.add(:base, I18n.t(:error_cosmosys_adr_role_not_allowed, label: cosmosys_adr_label))
      else
        errors.add(:status_id, :cosmosys_adr_invalid_transition)
      end
    end

    def cosmosys_adr_content_changed?
      (CONTENT_ATTRIBUTES - IDENTITY_ATTRIBUTES).any? { |name| will_save_change_to_attribute?(name) } ||
        (respond_to?(:custom_field_values_changed?) && custom_field_values_changed?) ||
        saved_attachments.present?
    end

    def cosmosys_adr_validate_transition
      from = cosmosys_adr_status_key_in_database
      to = cosmosys_adr_status_key
      unless CosmosysAdr::ALLOWED_TRANSITIONS.fetch(from, []).include?(to)
        errors.add(:status_id, :cosmosys_adr_invalid_transition)
        return
      end

      if to == :superseded
        errors.add(:status_id, :cosmosys_adr_superseded_by_plugin) unless CosmosysAdr::Supersession.active_for?(self)
      elsif !CosmosysAdr.decider?(cosmosys_adr_actor, project)
        errors.add(:base, I18n.t(:error_cosmosys_adr_role_not_allowed, label: cosmosys_adr_label))
      end
    end

    def cosmosys_adr_validate_supersedes(require_accepted:)
      return if adr_supersedes_id.blank?

      target = Issue.find_by(id: adr_supersedes_id)
      valid = target.present? && target.cosmosys_adr? && target.project_id == project_id && target.id != id
      unless valid
        errors.add(:adr_supersedes_id, :invalid)
        return
      end
      return unless require_accepted && target.cosmosys_adr_status_key != :accepted

      errors.add(:adr_supersedes_id, :cosmosys_adr_supersedes_not_accepted)
    end

    def cosmosys_adr_validate_fields
      errors.add(:adr_format, :inclusion) unless CosmosysAdr::FORMATS.include?(adr_format.to_s)
      errors.add(:adr_source, :inclusion) unless CosmosysAdr::SOURCES.include?(adr_source.to_s)
      errors.add(:adr_number, :blank) if persisted? && adr_number.blank?
    end

    def cosmosys_adr_assign_number
      return unless cosmosys_adr?

      setting = CosmosysAdr::ProjectSetting.for!(project)
      self.adr_number = setting.reserve_number!
    end

    # Runs after validation, so the dates it writes are never taken for a
    # change made by hand.
    def cosmosys_adr_stamp_dates
      return unless cosmosys_adr? && persisted? && will_save_change_to_status_id?

      today = cosmosys_adr_actor&.today || Date.current
      case cosmosys_adr_status_key
      when :accepted, :rejected
        self.adr_date = today if cosmosys_adr_status_key_in_database == :proposed
      when :deprecated, :superseded
        self.adr_in_force_until = today
      end
    end

    def cosmosys_adr_capture_changes
      @cosmosys_adr_superseding = cosmosys_adr? && will_save_change_to_status_id? &&
                                  cosmosys_adr_status_key == :accepted && adr_supersedes_id.present?
      return unless @cosmosys_adr_superseding && current_journal

      current_journal.details << JournalDetail.new(
        property: 'attr', prop_key: 'adr_superseded',
        value: CosmosysAdr.label(Issue.where(id: adr_supersedes_id).pick(:adr_number))
      )
    end

    def cosmosys_adr_forget_request
      @cosmosys_adr_requested_status_key = nil
    end

    def cosmosys_adr_apply_supersession
      return unless @cosmosys_adr_superseding

      @cosmosys_adr_superseding = false
      CosmosysAdr::Supersession.new(self, cosmosys_adr_actor).call
    end
  end
end
