module CosmosysAdr
  # One `ADR#…` reference written in an issue: in its description, in one of
  # its long text fields or in one of its notes. The target is kept as project
  # and number, so a mention of an ADR created later resolves once it exists.
  class Mention < ApplicationRecord
    self.table_name = 'cosmosys_adr_mentions'

    SOURCE_DESCRIPTION = 'description'.freeze
    SOURCE_NOTES = 'notes'.freeze
    FIELD_PREFIX = 'field:'.freeze
    CUSTOM_FIELD_PREFIX = 'cf:'.freeze

    belongs_to :issue
    belongs_to :journal, optional: true
    belongs_to :target_project, class_name: 'Project'

    validates :source, :target_number, presence: true

    scope :for_adr, ->(adr) { where(target_project_id: adr.project_id, target_number: adr.adr_number) }

    # Mentions the user may see: the issue that holds them is visible and so
    # is the text they come from, a note or a custom field.
    def visible?(user = User.current)
      return false unless issue&.visible?(user)
      return custom_field_visible?(user) if source.to_s.start_with?(CUSTOM_FIELD_PREFIX)
      return true unless journal

      !journal.private_notes? || user.allowed_to?(:view_private_notes, issue.project)
    end

    def adr
      Issue.find_by(project_id: target_project_id, adr_number: target_number)
    end

    private

    def custom_field_visible?(user)
      field_id = source.delete_prefix(CUSTOM_FIELD_PREFIX).to_i
      issue.visible_custom_field_values(user).any? { |value| value.custom_field_id == field_id }
    end
  end
end
