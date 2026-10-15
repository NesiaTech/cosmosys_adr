module CosmosysAdr
  TRACKER_KEY = 'adr'.freeze
  TRACKER_NAME = 'csAdr'.freeze
  ITEM_KIND = 'adr'.freeze
  MODULE_NAME = 'adrs'.freeze
  FORMATS = %w[nygard madr].freeze
  DEFAULT_FORMAT = 'nygard'.freeze
  SOURCE_COSMOSYS = 'cosmosys'.freeze
  SOURCES = [SOURCE_COSMOSYS].freeze

  # Canonical names used when the migration creates or finds the statuses.
  # At runtime statuses are resolved through the ids stored by the migration.
  STATUS_NAMES = {
    proposed: 'Proposed',
    accepted: 'Accepted',
    rejected: 'Rejected',
    deprecated: 'Deprecated',
    superseded: 'Superseded'
  }.freeze
  STATUS_KEYS = STATUS_NAMES.keys.freeze
  RETIRED_STATUS_KEYS = %i[rejected deprecated superseded].freeze

  # Transitions a person can make, by role. Superseded is reached only through
  # CosmosysAdr::Supersession when the superseding ADR is accepted.
  DECISION_TRANSITIONS = {
    proposed: %i[accepted rejected],
    accepted: %i[deprecated]
  }.freeze
  ALLOWED_TRANSITIONS = {
    proposed: %i[accepted rejected],
    accepted: %i[deprecated superseded]
  }.freeze

  module_function

  def tracker
    Tracker.find_by(csys_key: TRACKER_KEY)
  end

  def tracker_id
    tracker&.id
  end

  def adr_tracker?(tracker)
    tracker.present? && tracker.csys_key.to_s == TRACKER_KEY
  end

  def adr_tracker_id?(id)
    id.present? && Tracker.where(id: id, csys_key: TRACKER_KEY).exists?
  end

  def status_ids
    stored = Setting.plugin_cosmosys_adr['status_ids'] if Setting.respond_to?(:plugin_cosmosys_adr)
    stored = stored.to_h.transform_keys(&:to_sym) if stored.respond_to?(:to_h)
    STATUS_KEYS.to_h do |key|
      id = stored.is_a?(Hash) ? stored[key].to_i : 0
      id = IssueStatus.where('LOWER(name) = ?', STATUS_NAMES.fetch(key).downcase).pick(:id).to_i if id.zero?
      [key, id.positive? ? id : nil]
    end
  end

  def status(key)
    id = status_ids[key.to_sym]
    id && IssueStatus.find_by(id: id)
  end

  def status_key(status_or_id)
    id = status_or_id.respond_to?(:id) ? status_or_id.id : status_or_id
    return nil if id.blank?

    status_ids.key(id.to_i)
  end

  def label(number)
    return nil if number.blank?

    format('ADR-%04d', number.to_i)
  end

  def module_enabled?(project)
    project.present? && project.module_enabled?(MODULE_NAME).present?
  end

  def adr_creatable?(project, user)
    adr_tracker = tracker
    module_enabled?(project) && adr_tracker.present? &&
      Issue.allowed_target_trackers(project, user).include?(adr_tracker)
  end

  def decider?(user, project)
    return false if user.nil? || project.nil?
    return true if user.admin?

    role_ids = CosmosysAdr::ProjectSetting.for(project).decider_role_ids
    (user.roles_for_project(project).map(&:id) & role_ids).any?
  end

  def html_attribute(value)
    # The text pipeline of cosmoSys and Redmine scans the HTML that resolvers
    # return for `#CSID`, `#123` and `document:diN`. Encoding `#` and `:` keeps
    # titles and subjects inside generated markup from being linked again.
    ERB::Util.html_escape(value.to_s).gsub('#', '&#35;').gsub(':', '&#58;')
  end
end
