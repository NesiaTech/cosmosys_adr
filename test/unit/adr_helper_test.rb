require File.expand_path('../test_helper', __dir__)

# The status pills and history labels of ADRs name other ADRs only to users
# who can see them.
class CosmosysAdrHelperTest < Redmine::HelperTest
  include ApplicationHelper
  include IssuesHelper
  include CosmosysAdr::TestHelper

  def setup
    super
    setup_cosmosys_adr
    @project = create_adr_project('adr-helpers')
    @old = accepted_adr(@project, subject: 'Keep sessions in SQLite')
    @reporter_role.update!(issues_visibility: 'default')
    @new = create_adr(@project, author: @manager, subject: 'Store sessions in PostgreSQL', adr_supersedes_id: @old.id)
    @new = transition!(@new, :accepted)
    @new.update_column(:is_private, true)
  end

  def teardown
    User.current = nil
  end

  def test_the_superseded_pill_names_the_successor_only_to_who_can_see_it
    User.current = @manager
    assert_includes cosmosys_adr_status_pill(fresh(@old)), 'ADR-0002'

    User.current = User.find(@reporter.id)
    pill = cosmosys_adr_status_pill(fresh(@old))
    assert_not_includes pill, 'ADR-0002'
    assert_includes pill, adr_status(:superseded).name
  end

  def test_the_history_names_an_adr_only_to_who_can_see_it
    detail = JournalDetail.new(property: 'attr', prop_key: 'adr_supersedes_id', value: @old.id.to_s)
    hidden = JournalDetail.new(property: 'attr', prop_key: 'adr_supersedes_id', value: @new.id.to_s)
    User.current = User.find(@reporter.id)

    assert_includes show_detail(detail, true), 'ADR-0001'
    assert_not_includes show_detail(hidden, true), 'ADR-0002'
    assert_includes show_detail(hidden, true), "##{@new.id}"
  end
end
