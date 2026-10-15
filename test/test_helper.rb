require File.expand_path('../../../test/test_helper', __dir__)
require File.expand_path('../db/migrate/001_create_cosmosys_adr', __dir__)

module CosmosysAdr
  # Helpers for the plugin tests. Redmine's `fixtures :all` reloads trackers,
  # statuses and workflows before the tests, which removes what the plugin
  # migration seeded, and its projects and issues lack the identity fields
  # cosmoSys requires. Each test therefore seeds the plugin data again, inside
  # its own transaction, and works on projects and issues created here.
  module TestHelper
    PASSWORD = 'adr-test-password-1'.freeze

    def setup_cosmosys_adr
      ActiveRecord::Migration.suppress_messages { CreateCosmosysAdr.new.migrate(:up) }
      Setting.clear_cache
      Setting.cross_project_issue_relations = '1'
      Setting.text_formatting = 'common_mark'
      @adr_tracker = CosmosysAdr.tracker
      @bug_tracker = Tracker.find(1)
      @manager_role = Role.find_by!(name: 'Manager')
      @developer_role = Role.find_by!(name: 'Developer')
      @reporter_role = Role.find_by!(name: 'Reporter')
      @admin = User.find(1)
      @manager = generate_adr_user('adr-manager', 'Ada', 'Manager')
      @developer = generate_adr_user('adr-developer', 'Dev', 'Eloper')
      @reporter = generate_adr_user('adr-reporter', 'Rep', 'Orter')
      User.current = nil
    end

    def generate_adr_user(login, firstname, lastname)
      User.generate!(login: login, firstname: firstname, lastname: lastname) do |user|
        user.password = PASSWORD
        user.password_confirmation = PASSWORD
      end
    end

    def adr_status(key)
      CosmosysAdr.status(key)
    end
  end
end

class ActiveSupport::TestCase
  include CosmosysAdr::TestHelper
end
