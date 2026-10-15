# frozen_string_literal: true

# Prints, on a line of its own, what this plugin's migrations leave in the
# database, with no ids, so that test-in-image.sh can compare the database
# before a rollback, after it and after migrating again. Statuses are left
# out: the rollback keeps them on purpose.
#
#   bundle exec rails runner plugins/cosmosys_adr/.github/ci/migration_state.rb

connection = ActiveRecord::Base.connection
tables = %w[cosmosys_adr_mentions cosmosys_adr_project_settings].select { |table| connection.table_exists?(table) }
columns = connection.columns(:issues).map(&:name).grep(/\Aadr_/).sort
# An expression index has its columns as a string.
indexes = connection.indexes(:issues).select { |index| Array(index.columns).any? { |column| column.include?('adr_') } }
tracker_ids = connection.select_values("SELECT id FROM trackers WHERE csys_key = 'adr'")
workflows = tracker_ids.empty? ? 0 : connection.select_value("SELECT COUNT(*) FROM workflows WHERE tracker_id IN (#{tracker_ids.join(',')})")
settings = connection.select_value("SELECT COUNT(*) FROM settings WHERE name = 'plugin_cosmosys_adr'")
migrations = connection.select_values("SELECT version FROM schema_migrations WHERE version LIKE '%-cosmosys_adr'").sort

puts "STATE tracker=#{tracker_ids.size} columns=[#{columns.join(' ')}] indexes=[#{indexes.map(&:name).sort.join(' ')}] " \
     "tables=[#{tables.join(' ')}] workflows=#{workflows} settings=#{settings} migrations=[#{migrations.join(' ')}]"
