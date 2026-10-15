module CosmosysAdr
  TRACKER_KEY = 'adr'.freeze
  TRACKER_NAME = 'csAdr'.freeze
  ITEM_KIND = 'adr'.freeze
  FORMATS = %w[nygard madr].freeze
  DEFAULT_FORMAT = 'nygard'.freeze

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
end
