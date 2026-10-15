require File.expand_path('../test_helper', __dir__)

# Bulk edit and the context menu go through Redmine's bulk_update.
class CosmosysAdrBulkEditTest < Redmine::ControllerTest
  tests IssuesController

  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-issues', template: 'madr')
    @old = accepted_adr(@project, subject: 'Keep sessions in SQLite')
    @adr = create_adr(@project, subject: 'Store sessions in PostgreSQL', adr_supersedes_id: @old.id,
                                adr_decision_makers: 'tech lead')
    @bug = create_bug(@project)
  end

  def test_bulk_edit_keeps_decided_adrs_decided
    @request.session[:user_id] = @manager.id
    priority = IssuePriority.where.not(id: @old.priority_id).first
    post :bulk_update, params: { ids: [@old.id], issue: { priority_id: priority.id.to_s }, notes: 'bulk' }
    assert_equal priority, fresh(@old).priority

    post :bulk_update, params: { ids: [@old.id], issue: { status_id: adr_status(:proposed).id.to_s } }
    assert_equal :accepted, fresh(@old).cosmosys_adr_status_key
  end

  def test_bulk_status_change_by_a_reporter_is_refused
    @request.session[:user_id] = @reporter.id
    post :bulk_update, params: { ids: [@adr.id], issue: { status_id: adr_status(:accepted).id.to_s } }

    assert_equal :proposed, fresh(@adr).cosmosys_adr_status_key
  end

  def test_bulk_edit_of_the_content_of_a_decided_adr_is_refused
    @request.session[:user_id] = @manager.id
    field = IssueCustomField.create!(name: 'Area', field_format: 'string', is_for_all: true,
                                     trackers: [@adr_tracker, @bug_tracker])
    post :bulk_update, params: { ids: [@old.id, @bug.id], issue: { custom_field_values: { field.id.to_s => 'storage' } } }

    assert_nil fresh(@old).custom_field_value(field)
    assert_equal 'storage', fresh(@bug).custom_field_value(field)
  end
end
