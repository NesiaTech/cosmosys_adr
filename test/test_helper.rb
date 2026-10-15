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

    def create_adr_project(identifier, template: 'nygard', adrs: true, is_public: false, parent: nil)
      project = Project.new(name: identifier.tr('-', ' ').capitalize, identifier: identifier, is_public: is_public,
                            cscode: identifier.delete('-_').upcase.first(8))
      project.parent = parent if parent
      project.csys_modules_explicit = '1'
      project.enabled_module_names = adrs ? %w[issue_tracking adrs] : %w[issue_tracking]
      project.tracker_ids = [@bug_tracker.id]
      project.save!
      CosmosysAdr::ModuleSync.call(project)
      project.reload
      if adrs
        setting = CosmosysAdr::ProjectSetting.for!(project)
        setting.update!(template: template)
      end
      add_member(project, @manager, @manager_role)
      add_member(project, @developer, @developer_role)
      add_member(project, @reporter, @reporter_role)
      project
    end

    def add_member(project, user, role)
      Member.create!(principal: user, project: project, role_ids: [role.id])
    end

    def new_adr(project, author: @developer, subject: 'Use PostgreSQL', **attributes)
      issue = Issue.new(project: project, tracker: @adr_tracker, author: author, subject: subject)
      issue.assign_attributes(attributes)
      issue
    end

    def create_adr(project, author: @developer, **attributes)
      issue = new_adr(project, author: author, **attributes)
      issue.save!
      issue
    end

    def create_bug(project, author: @developer, subject: 'Implement the decision', **attributes)
      Issue.create!(project: project, tracker: @bug_tracker, author: author, subject: subject, **attributes)
    end

    # A freshly loaded copy, as a new request would see it. Redmine keeps the
    # journal being written in the object (init_journal uses ||=) and
    # cosmoSys moves lock_version after a save, so tests that save the same
    # issue twice work on fresh objects like the application does.
    def fresh(issue)
      Issue.find(issue.id)
    end

    # Moves an ADR through the lifecycle as `user`, like the issue form does.
    def transition!(issue, key, user: @manager)
      issue = fresh(issue)
      issue.init_journal(user)
      issue.status = adr_status(key)
      User.current = user
      issue.save!
      fresh(issue)
    ensure
      User.current = nil
    end

    def accepted_adr(project, **attributes)
      transition!(create_adr(project, **attributes), :accepted)
    end
  end
end

class ActiveSupport::TestCase
  include CosmosysAdr::TestHelper
end
