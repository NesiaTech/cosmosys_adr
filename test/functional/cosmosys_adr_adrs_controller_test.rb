require File.expand_path('../test_helper', __dir__)

class CosmosysAdr::AdrsControllerTest < Redmine::ControllerTest
  tests CosmosysAdr::AdrsController

  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-tab', template: 'madr')
    @accepted = accepted_adr(@project, subject: 'Use PostgreSQL', description: "## Context\n\nWe need **durable** state.",
                                       adr_decision_makers: 'tech lead')
    @proposed = create_adr(@project, subject: 'Use Redis for caching')
    @rejected = transition!(create_adr(@project, subject: 'Expose a JSON:API'), :rejected)
    IssueRelation.create!(issue_from: create_bug(@project), issue_to: @accepted, relation_type: 'relates')
  end

  def test_index_lists_the_adrs_of_the_project
    @request.session[:user_id] = @reporter.id
    get :index, params: { project_id: @project.identifier }

    assert_response :success
    assert_select 'table.cosmosys-adr-list tbody tr.cosmosys-adr-row', 3
    assert_select "td.cosmosys-adr-number a[href='/issues/#{@accepted.id}']", text: 'ADR-0001'
    assert_select '#main-menu a.cosmosys-adrs.selected', text: 'ADRs'
    assert_select '#sidebar', text: /MADR/
    assert_select '#sidebar', text: /Manager, Developer/
    assert_select '#sidebar .cosmosys-adr-counts li', 5
  end

  def test_index_filters_by_status
    @request.session[:user_id] = @reporter.id
    get :index, params: { project_id: @project.identifier, filtered: '1', status: %w[accepted rejected] }

    assert_response :success
    assert_select 'tr.cosmosys-adr-row', 2
    assert_select 'tr.cosmosys-adr-row td.subject', text: 'Use Redis for caching', count: 0
  end

  def test_index_filters_by_title_and_format
    @request.session[:user_id] = @reporter.id
    get :index, params: { project_id: @project.identifier, title: 'redis' }
    assert_select 'tr.cosmosys-adr-row', 1

    get :index, params: { project_id: @project.identifier, format_filter: 'nygard' }
    assert_select 'tr.cosmosys-adr-row', 0
  end

  def test_index_counts_linked_issues
    @request.session[:user_id] = @reporter.id
    get :index, params: { project_id: @project.identifier }

    assert_select "tr#adr-1 td:last-child", text: '1'
  end

  def test_index_shows_the_rendered_markdown
    @request.session[:user_id] = @reporter.id
    get :index, params: { project_id: @project.identifier, content: '1' }

    assert_select '.cosmosys-adr-content h2', text: /Context/
    assert_select '.cosmosys-adr-content strong', text: 'durable'
  end

  def test_index_is_denied_without_the_module
    project = create_adr_project('adr-tab-off', adrs: false)
    @request.session[:user_id] = @manager.id
    get :index, params: { project_id: project.identifier }

    assert_response :forbidden
  end

  def test_index_is_denied_to_non_members_of_a_private_project
    @request.session[:user_id] = User.generate!.id
    get :index, params: { project_id: @project.identifier }

    assert_response :forbidden
  end

  def test_the_new_adr_link_opens_the_issue_form_with_the_tracker
    @request.session[:user_id] = @developer.id
    get :index, params: { project_id: @project.identifier }

    assert_select "a.cosmosys-adr-new[href=?]", "/projects/#{@project.identifier}/issues/new?issue%5Btracker_id%5D=#{@adr_tracker.id}"
  end
end
