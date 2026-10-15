require File.expand_path('../test_helper', __dir__)

class CosmosysAdr::TransitionsControllerTest < Redmine::ControllerTest
  tests CosmosysAdr::TransitionsController

  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-buttons')
    @adr = create_adr(@project)
  end

  def test_a_developer_accepts
    @request.session[:user_id] = @developer.id
    post :create, params: { issue_id: @adr.id, to: 'accept' }

    assert_redirected_to "/issues/#{@adr.id}"
    assert_equal :accepted, fresh(@adr).cosmosys_adr_status_key
    assert_equal I18n.t(:notice_cosmosys_adr_accepted, label: 'ADR-0001'), flash[:notice]
  end

  def test_a_reporter_is_denied
    @request.session[:user_id] = @reporter.id
    post :create, params: { issue_id: @adr.id, to: 'accept' }

    assert_response :forbidden
    assert_equal :proposed, fresh(@adr).cosmosys_adr_status_key
  end

  def test_superseded_cannot_be_asked_for
    @adr = transition!(@adr, :accepted)
    @request.session[:user_id] = @admin.id
    post :create, params: { issue_id: @adr.id, to: 'supersede' }

    assert_response :forbidden
  end
end
