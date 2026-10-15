require_dependency 'issue'

module CosmosysAdr
  # An ADR is an issue of the csAdr tracker. This patch numbers ADRs and keeps
  # their lifecycle. Every rule is a model validation, so the form, bulk edit
  # and the REST API all go through it.
  module IssuePatch
    # Set when the ADR is created and never changed afterwards.
    IDENTITY_ATTRIBUTES = %w[adr_number adr_format adr_source].freeze

    def self.included(base)
      base.class_eval do
        before_validation :cosmosys_adr_apply_defaults, on: :create
        validate :cosmosys_adr_validate
        before_create :cosmosys_adr_assign_number
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

    def cosmosys_adr_actor
      @current_journal&.user || @attributes_set_by || User.current
    end

    private

    def cosmosys_adr_apply_defaults
      return unless cosmosys_adr?

      self.adr_format = CosmosysAdr::ProjectSetting.template_for(project) if adr_format.blank? && project
      self.adr_source ||= CosmosysAdr::SOURCE_COSMOSYS
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
    end

    def cosmosys_adr_validate_update
      cosmosys_adr_validate_requested_status

      changed_identity = IDENTITY_ATTRIBUTES.select { |name| will_save_change_to_attribute?(name) }
      changed_identity.each { |name| errors.add(name, :cosmosys_adr_immutable) }
      cosmosys_adr_validate_transition if will_save_change_to_status_id?
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

    def cosmosys_adr_validate_transition
      from = cosmosys_adr_status_key_in_database
      to = cosmosys_adr_status_key
      unless CosmosysAdr::ALLOWED_TRANSITIONS.fetch(from, []).include?(to)
        errors.add(:status_id, :cosmosys_adr_invalid_transition)
        return
      end

      return if CosmosysAdr.decider?(cosmosys_adr_actor, project)

      errors.add(:base, I18n.t(:error_cosmosys_adr_role_not_allowed, label: cosmosys_adr_label))
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

    def cosmosys_adr_forget_request
      @cosmosys_adr_requested_status_key = nil
    end
  end
end
