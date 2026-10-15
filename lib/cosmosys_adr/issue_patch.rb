require_dependency 'issue'

module CosmosysAdr
  # An ADR is an issue of the csAdr tracker. This patch numbers ADRs within
  # their project and keeps what identifies them. Every rule is a model
  # validation, so the form, bulk edit and the REST API all go through it.
  module IssuePatch
    # Set when the ADR is created and never changed afterwards.
    IDENTITY_ATTRIBUTES = %w[adr_number adr_format adr_source].freeze

    def self.included(base)
      base.class_eval do
        before_validation :cosmosys_adr_apply_defaults, on: :create
        validate :cosmosys_adr_validate
        before_create :cosmosys_adr_assign_number
      end
    end

    def cosmosys_adr?
      CosmosysAdr.adr_tracker?(tracker)
    end

    def cosmosys_adr_label
      CosmosysAdr.label(adr_number)
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

      cosmosys_adr_validate_update if persisted?
      cosmosys_adr_validate_fields
    end

    def cosmosys_adr_validate_update
      changed_identity = IDENTITY_ATTRIBUTES.select { |name| will_save_change_to_attribute?(name) }
      changed_identity.each { |name| errors.add(name, :cosmosys_adr_immutable) }
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
  end
end
