require File.expand_path('../test_helper', __dir__)

# The "Linked ADRs" panel and inline references on ordinary issues.
class CosmosysAdrLinkedAdrsTest < Redmine::ControllerTest
  tests IssuesController

  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-issues', template: 'madr')
    @old = accepted_adr(@project, subject: 'Keep sessions in SQLite')
    @adr = create_adr(@project, subject: 'Store sessions in PostgreSQL', adr_supersedes_id: @old.id,
                                adr_decision_makers: 'tech lead')
    @bug = create_bug(@project, description: 'Implements ADR#0002 and depends on ADR#1')
  end

  def test_an_issue_page_shows_linked_and_mentioned_adrs_with_references
    @request.session[:user_id] = @developer.id
    get :show, params: { id: @bug.id }

    assert_select '#cosmosys-adr-linked table.cosmosys-adr-links tr td.cosmosys-adr-number', 2
    assert_select '#issue_description_wiki a.cosmosys-adr-ref', text: 'ADR-0002 Store sessions in PostgreSQL'
    assert_select '#issue_description_wiki a.cosmosys-adr-ref', text: 'ADR-0001 Keep sessions in SQLite'
    assert_select '#cosmosys-adr-link-form select#cosmosys_adr_link_adr_id optgroup'
  end

  def test_the_linked_adrs_panel_stays_out_of_projects_without_adrs
    project = create_adr_project('adr-issues-plain', adrs: false)
    plain = create_bug(project)
    @request.session[:user_id] = @developer.id
    get :show, params: { id: plain.id }

    assert_select '#cosmosys-adr-linked', 0
    get :show, params: { id: @bug.id }
    assert_select '#cosmosys-adr-linked'
  end
end
