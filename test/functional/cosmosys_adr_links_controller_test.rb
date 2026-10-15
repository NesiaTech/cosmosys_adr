require File.expand_path('../test_helper', __dir__)

class CosmosysAdr::LinksControllerTest < Redmine::ControllerTest
  tests CosmosysAdr::LinksController

  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-links')
    @meta = create_adr_project('adr-links-meta')
    @adr = accepted_adr(@meta, subject: 'Shared database')
    @bug = create_bug(@project)
  end

  def test_linking_creates_a_native_relation_across_projects
    @request.session[:user_id] = @developer.id
    post :create, params: { issue_id: @bug.id, adr_id: @adr.id }

    assert_redirected_to "/issues/#{@bug.id}"
    # Redmine stores symmetric relations with the lower issue id first.
    relation = IssueRelation.where(issue_from_id: [@bug.id, @adr.id], issue_to_id: [@bug.id, @adr.id]).first
    assert_equal 'relates', relation.relation_type
    assert_equal [[@adr, :link]], CosmosysAdr::Links.for_issue(fresh(@bug), @developer).map { |e| [e.issue, e.origin] }
  end

  def test_unlinking_removes_only_the_explicit_link
    relation = IssueRelation.create!(issue_from: @bug, issue_to: @adr, relation_type: 'relates')
    @bug = fresh(@bug)
    @bug.description = 'Also mentions ADR#adr-links-meta#1'
    @bug.save!
    @request.session[:user_id] = @developer.id
    delete :destroy, params: { issue_id: @bug.id, id: relation.id }

    assert_redirected_to "/issues/#{@bug.id}"
    assert_not IssueRelation.exists?(relation.id)
    assert_equal [[@adr, :mention]], CosmosysAdr::Links.for_issue(fresh(@bug), @developer).map { |e| [e.issue, e.origin] }
  end

  def test_other_projects_are_offered_only_when_redmine_allows_relations_between_projects
    local = accepted_adr(@project, subject: 'Local decision')

    assert_equal [@project, @meta].sort_by(&:id), CosmosysAdr::Links.linkable_adrs(@developer, @project).keys.sort_by(&:id)
    Setting.cross_project_issue_relations = '0'
    assert_equal({ @project => [local] }, CosmosysAdr::Links.linkable_adrs(@developer, @project))
  end

  def test_linking_needs_the_relations_permission
    @reporter_role.remove_permission!(:manage_issue_relations)
    @request.session[:user_id] = @reporter.id
    post :create, params: { issue_id: @bug.id, adr_id: @adr.id }

    assert_response :forbidden
  end

  def test_an_invisible_adr_cannot_be_linked
    secret = create_adr_project('adr-links-secret')
    hidden = create_adr(secret)
    Member.where(project_id: secret.id, user_id: @developer.id).destroy_all
    @request.session[:user_id] = @developer.id
    post :create, params: { issue_id: @bug.id, adr_id: hidden.id }

    assert_equal I18n.t(:error_cosmosys_adr_link_target), flash[:error]
    assert_not IssueRelation.where(issue_from_id: [@bug.id, hidden.id], issue_to_id: [@bug.id, hidden.id]).exists?
  end
end
