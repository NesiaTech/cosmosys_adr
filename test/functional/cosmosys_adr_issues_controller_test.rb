require File.expand_path('../test_helper', __dir__)

# The ADR seen through Redmine's own issue pages and actions.
class CosmosysAdrIssuesControllerTest < Redmine::ControllerTest
  tests IssuesController

  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-issues', template: 'madr')
    @old = accepted_adr(@project, subject: 'Keep sessions in SQLite')
    @adr = create_adr(@project, subject: 'Store sessions in PostgreSQL', adr_supersedes_id: @old.id,
                                adr_decision_makers: 'tech lead')
    @bug = create_bug(@project)
  end

  def test_the_new_form_comes_with_the_template_and_the_adr_fields
    @request.session[:user_id] = @developer.id
    get :new, params: { project_id: @project.identifier, issue: { tracker_id: @adr_tracker.id } }

    assert_response :success
    assert_select 'textarea#issue_description', text: /## Context and Problem Statement/
    assert_select 'fieldset.cosmosys-adr-fields'
    assert_select 'input#issue_adr_decision_makers'
    assert_select 'select#issue_status_id option', 1
  end

  def test_creating_from_the_form_numbers_the_adr
    @request.session[:user_id] = @developer.id
    post :create, params: { project_id: @project.identifier,
                            issue: { tracker_id: @adr_tracker.id, subject: 'Cache with Redis', status_id: adr_status(:accepted).id } }

    issue = Issue.order(:id).last
    assert_redirected_to "/issues/#{issue.id}"
    assert_equal 3, issue.adr_number
    assert_equal :proposed, issue.cosmosys_adr_status_key
  end

  def test_the_adr_page_shows_fields_lock_supersession_links_and_actions
    IssueRelation.create!(issue_from: @bug, issue_to: @adr, relation_type: 'relates')
    @request.session[:user_id] = @developer.id
    get :show, params: { id: @adr.id }

    assert_response :success
    assert_select '#content h2', text: /ADR-0002/
    assert_select '.cosmosys-adr-number .value', text: 'ADR-0002'
    assert_select '.cosmosys-adr-lock-open'
    assert_select '.cosmosys-adr-decision-makers .value', text: 'tech lead'
    assert_select '.cosmosys-adr-banner', text: /ADR-0001/
    assert_select 'form.cosmosys-adr-transition-form input[name=to][value=accept]'
    assert_select 'table.cosmosys-adr-links td.subject', text: /Implement the decision/
  end

  def test_a_decided_adr_page_shows_the_lock_and_who_supersedes_it
    transition!(@adr, :accepted)
    @request.session[:user_id] = @reporter.id
    get :show, params: { id: @old.id }

    assert_select '.cosmosys-adr-lock-closed'
    assert_select '.cosmosys-adr-superseded-by .value a', text: /ADR-0002/
    assert_select '.flash.warning.cosmosys-adr-banner', text: /ADR-0002/
    assert_select 'form.cosmosys-adr-transition-form', 0
    assert_select '#history ul.journal-details li', text: /Superseded by.*ADR-0002/
  end
end
