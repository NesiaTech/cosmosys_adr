require 'json'

module CosmosysAdr
  # ADR settings of one project: the template of new ADRs, the roles that
  # decide (stored by role id) and the counter that numbers ADRs. The counter
  # only moves forward, so a deleted ADR never gives its number away.
  class ProjectSetting < ApplicationRecord
    self.table_name = 'cosmosys_adr_project_settings'

    DEFAULT_ROLE_KEYS = %i[default_role_manager default_role_developer].freeze

    belongs_to :project

    validates :project_id, presence: true, uniqueness: true
    validates :template, inclusion: { in: CosmosysAdr::FORMATS }
    validates :last_number, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
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

    # A copied project takes the template and the deciding roles of the
    # original. The counter keeps the higher of both, so the copy never
    # hands out a number the original had already used for one of its ADRs.
    def self.copy!(source, destination)
      original = find_by(project_id: source.id)
      return unless original && destination&.persisted?

      setting = for!(destination)
      setting.template = original.template
      setting.decider_role_ids = original.decider_role_ids
      setting.last_number = [setting.last_number.to_i, original.last_number.to_i].max
      setting.save!
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

    # Reserves the next ADR number under a row lock held until the caller's
    # transaction ends. The number is also kept above any number already used
    # in the project, so it never moves backwards.
    def reserve_number!(preferred = nil)
      save! if new_record?
      with_lock do
        used = Issue.where(project_id: project_id).maximum(:adr_number).to_i
        number = preferred.to_i.positive? ? preferred.to_i : [last_number.to_i, used].max + 1
        self.last_number = [last_number.to_i, used, number].max
        save!
        number
      end
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
