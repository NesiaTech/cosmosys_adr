class CreateCosmosysAdr < ActiveRecord::Migration[6.1]
  ISSUE_COLUMNS = {
    adr_number: :integer,
    adr_format: :string,
    adr_date: :date,
    adr_in_force_until: :date,
    adr_decision_makers: :text,
    adr_consulted: :text,
    adr_informed: :text,
    adr_supersedes_id: :bigint,
    adr_source: :string
  }.freeze
  NUMBER_INDEX = 'idx_issues_adr_number_per_project'.freeze
  MENTION_TARGET_INDEX = 'idx_cosmosys_adr_mentions_target'.freeze

  TRACKER_KEY = 'adr'.freeze
  TRACKER_NAME = 'csAdr'.freeze
  TRACKER_DESCRIPTION = 'Architecture Decision Record (cosmoSys ADR).'.freeze
  MODULE_NAME = 'adrs'.freeze
  MANAGEMENT_FIELDS = %w[assigned_to_id start_date due_date estimated_hours done_ratio].freeze

  # name => [is_closed, csys_closed_outcome, csys_maturity]. A retired ADR
  # (Rejected, Deprecated, Superseded) closes unsuccessfully, like the
  # Rejected and Erased statuses of cosmoSys and cosmoSys Requirements; an
  # accepted one closes successfully, like Approved.
  STATUSES = {
    proposed: ['Proposed', false, nil, 1],
    accepted: ['Accepted', true, 'successful', 4],
    rejected: ['Rejected', true, 'unsuccessful', 0],
    deprecated: ['Deprecated', true, 'unsuccessful', 0],
    superseded: ['Superseded', true, 'unsuccessful', 0]
  }.freeze
  # Accepted -> Superseded is not a workflow transition: the plugin makes it
  # when the superseding ADR is accepted, and the issue validation refuses it
  # from anywhere else.
  TRANSITIONS = [%i[proposed accepted], %i[proposed rejected], %i[accepted deprecated]].freeze

  def up
    ISSUE_COLUMNS.each do |name, type|
      add_column :issues, name, type unless column_exists?(:issues, name)
    end
    unless index_exists?(:issues, %i[project_id adr_number], name: NUMBER_INDEX)
      add_index :issues, %i[project_id adr_number], unique: true, where: 'adr_number IS NOT NULL', name: NUMBER_INDEX
    end
    add_index :issues, :adr_supersedes_id unless index_exists?(:issues, :adr_supersedes_id)

    create_project_settings
    create_mentions

    statuses = STATUSES.to_h { |key, definition| [key, ensure_status(*definition)] }
    tracker = ensure_tracker(statuses.fetch(:proposed))
    reset_workflow(tracker.id, statuses)
    store_status_ids(statuses)
    enable_tracker_where_module_is_enabled(tracker.id)
  end

  def down
    tracker = tracker_class.find_by(csys_key: TRACKER_KEY)
    if tracker && select_value("SELECT 1 FROM issues WHERE tracker_id = #{tracker.id} LIMIT 1")
      # Rolling back would drop every ADR number, format and link of the
      # existing ADRs. Delete or move those issues first.
      raise ActiveRecord::IrreversibleMigration, 'csAdr issues exist; delete them before rolling cosmosys_adr back'
    end

    if tracker
      execute "DELETE FROM workflows WHERE tracker_id = #{tracker.id}"
      execute "DELETE FROM projects_trackers WHERE tracker_id = #{tracker.id}"
      execute "DELETE FROM custom_fields_trackers WHERE tracker_id = #{tracker.id}" if table_exists?(:custom_fields_trackers)
      tracker.destroy!
    end
    execute "DELETE FROM settings WHERE name = 'plugin_cosmosys_adr'"

    drop_table :cosmosys_adr_mentions if table_exists?(:cosmosys_adr_mentions)
    drop_table :cosmosys_adr_project_settings if table_exists?(:cosmosys_adr_project_settings)
    remove_index :issues, name: NUMBER_INDEX if index_exists?(:issues, %i[project_id adr_number], name: NUMBER_INDEX)
    remove_index :issues, :adr_supersedes_id if index_exists?(:issues, :adr_supersedes_id)
    ISSUE_COLUMNS.keys.reverse_each do |name|
      remove_column :issues, name if column_exists?(:issues, name)
    end
    # Statuses are shared with every tracker and may be in use elsewhere, so
    # they stay, as cosmoSys Requirements does with its own.
  end

  private

  def create_project_settings
    unless table_exists?(:cosmosys_adr_project_settings)
      create_table :cosmosys_adr_project_settings do |t|
        t.integer :project_id, null: false
        t.string :template, null: false, default: 'nygard'
        t.text :decider_role_ids
        t.integer :last_number, null: false, default: 0
        t.timestamps null: false
      end
    end
    unless index_exists?(:cosmosys_adr_project_settings, :project_id, unique: true)
      add_index :cosmosys_adr_project_settings, :project_id, unique: true
    end
    return if foreign_key_exists?(:cosmosys_adr_project_settings, :projects)

    add_foreign_key :cosmosys_adr_project_settings, :projects, on_delete: :cascade
  end

  def create_mentions
    unless table_exists?(:cosmosys_adr_mentions)
      create_table :cosmosys_adr_mentions do |t|
        t.integer :issue_id, null: false
        t.integer :journal_id
        t.string :source, null: false
        t.integer :target_project_id, null: false
        t.integer :target_number, null: false
        t.datetime :created_at, null: false
      end
    end
    add_index :cosmosys_adr_mentions, :issue_id unless index_exists?(:cosmosys_adr_mentions, :issue_id)
    add_index :cosmosys_adr_mentions, :journal_id unless index_exists?(:cosmosys_adr_mentions, :journal_id)
    unless index_exists?(:cosmosys_adr_mentions, %i[target_project_id target_number], name: MENTION_TARGET_INDEX)
      add_index :cosmosys_adr_mentions, %i[target_project_id target_number], name: MENTION_TARGET_INDEX
    end
    add_foreign_key :cosmosys_adr_mentions, :issues, on_delete: :cascade unless foreign_key_exists?(:cosmosys_adr_mentions, :issues)
    add_foreign_key :cosmosys_adr_mentions, :journals, on_delete: :cascade unless foreign_key_exists?(:cosmosys_adr_mentions, :journals)
    return if foreign_key_exists?(:cosmosys_adr_mentions, :projects, column: :target_project_id)

    add_foreign_key :cosmosys_adr_mentions, :projects, column: :target_project_id, on_delete: :cascade
  end

  def tracker_class
    @tracker_class ||= Class.new(ActiveRecord::Base) { self.table_name = 'trackers' }.tap(&:reset_column_information)
  end

  def status_class
    @status_class ||= Class.new(ActiveRecord::Base) { self.table_name = 'issue_statuses' }.tap(&:reset_column_information)
  end

  # An existing status of the same name is reused as it is: other trackers
  # may rely on it. Only the cosmoSys outcome and maturity are filled in, and
  # only where they are missing.
  def ensure_status(name, closed, outcome, maturity)
    status = status_class.where('LOWER(name) = ?', name.downcase).first
    unless status
      status = status_class.new(name: name, is_closed: closed)
      status.position = status_class.maximum(:position).to_i + 1
    end
    if status.has_attribute?(:csys_closed_outcome) && status.csys_closed_outcome.blank? && outcome && status.is_closed
      status.csys_closed_outcome = outcome
    end
    status.csys_maturity = maturity if status.has_attribute?(:csys_maturity) && status.csys_maturity.nil?
    status.save!
    status
  end

  def ensure_tracker(default_status)
    tracker = tracker_class.find_by(csys_key: TRACKER_KEY) ||
              tracker_class.where('LOWER(name) = ?', TRACKER_NAME.downcase).first ||
              tracker_class.new(name: TRACKER_NAME, position: tracker_class.maximum(:position).to_i + 1)
    tracker.assign_attributes(csys_key: TRACKER_KEY, csys_item_kind: TRACKER_KEY, default_status_id: default_status.id)
    tracker.description = TRACKER_DESCRIPTION if tracker.has_attribute?(:description) && tracker.description.blank?
    tracker.fields_bits = management_fields_bits
    tracker.save!
    tracker
  end

  # Same encoding as Tracker#core_fields=: one bit per disabled core field.
  def management_fields_bits
    Tracker::CORE_FIELDS.each_with_index.sum do |field, index|
      MANAGEMENT_FIELDS.include?(field) ? 2**index : 0
    end
  end

  def reset_workflow(tracker_id, statuses)
    execute "DELETE FROM workflows WHERE tracker_id = #{tracker_id}"
    role_ids = select_values('SELECT id FROM roles WHERE builtin = 0')
    role_ids.product(TRANSITIONS).each do |role_id, (from, to)|
      execute <<~SQL.squish
        INSERT INTO workflows (type, tracker_id, role_id, old_status_id, new_status_id, author, assignee)
        VALUES ('WorkflowTransition', #{tracker_id}, #{role_id}, #{statuses.fetch(from).id}, #{statuses.fetch(to).id},
                #{connection.quoted_false}, #{connection.quoted_false})
      SQL
    end
  end

  def store_status_ids(statuses)
    Setting.plugin_cosmosys_adr = Setting.plugin_cosmosys_adr.to_h.merge(
      'status_ids' => statuses.transform_keys(&:to_s).transform_values(&:id)
    )
  end

  def enable_tracker_where_module_is_enabled(tracker_id)
    execute <<~SQL.squish
      INSERT INTO projects_trackers (project_id, tracker_id)
      SELECT enabled_modules.project_id, #{tracker_id}
      FROM enabled_modules
      WHERE enabled_modules.name = '#{MODULE_NAME}'
        AND NOT EXISTS (
          SELECT 1 FROM projects_trackers
          WHERE projects_trackers.project_id = enabled_modules.project_id
            AND projects_trackers.tracker_id = #{tracker_id}
        )
    SQL
  end
end
