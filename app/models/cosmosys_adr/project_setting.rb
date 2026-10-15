require 'json'

module CosmosysAdr
  # ADR settings of one project: the template of new ADRs and the roles
  # that decide, stored by role id.
  class ProjectSetting < ApplicationRecord
    self.table_name = 'cosmosys_adr_project_settings'

    DEFAULT_ROLE_KEYS = %i[default_role_manager default_role_developer].freeze

    belongs_to :project

    validates :project_id, presence: true, uniqueness: true
    validates :template, inclusion: { in: CosmosysAdr::FORMATS }
    validate :validate_decider_roles
    # Saved from the settings tab, a project must keep at least one role that
    # decides, or nobody could ever accept an ADR there.
    validate :validate_decider_roles_present, on: :settings_form

    # Settings of a project, unsaved with the defaults when the project has
    # none yet. Reading settings never writes.
    def self.for(project)
      find_by(project_id: project.id) || new(project: project, template: CosmosysAdr::DEFAULT_FORMAT,
                                             decider_role_ids: default_decider_role_ids)
    end

    # Settings of a project, created with the defaults if missing. Two
    # requests creating them at once end with the same row.
    def self.for!(project)
      find_by(project_id: project.id) || begin
        transaction(requires_new: true) do
          create!(project: project, template: CosmosysAdr::DEFAULT_FORMAT, decider_role_ids: default_decider_role_ids)
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        find_by!(project_id: project.id)
      end
    end

    def self.template_for(project)
      project.present? ? self.for(project).template : CosmosysAdr::DEFAULT_FORMAT
    end

    # Manager and Developer by default, found by the names Redmine gives them
    # when it loads its default data in any language. They are stored by id.
    def self.default_decider_role_ids
      names = DEFAULT_ROLE_KEYS.flat_map do |key|
        I18n.available_locales.map { |locale| I18n.t(key, locale: locale, default: '') }
      end
      names = (names + %w[Manager Developer]).compact_blank.uniq
      Role.givable.where(name: names).order(:position).pluck(:id)
    end

    def decider_role_ids
      JSON.parse(self[:decider_role_ids].presence || '[]').map(&:to_i)
    rescue JSON::ParserError
      []
    end

    def decider_role_ids=(ids)
      self[:decider_role_ids] = Array(ids).reject(&:blank?).map(&:to_i).uniq.sort.to_json
    end

    def decider_roles
      Role.where(id: decider_role_ids).sorted.to_a
    end

    private

    def validate_decider_roles
      errors.add(:decider_role_ids, :invalid) if (decider_role_ids - Role.givable.pluck(:id)).any?
    end

    def validate_decider_roles_present
      errors.add(:decider_role_ids, :blank) if decider_role_ids.empty?
    end
  end
end
