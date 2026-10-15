require File.expand_path('../test_helper', __dir__)

class CosmosysAdr::ProjectSettingsControllerTest < Redmine::ControllerTest
  tests CosmosysAdr::ProjectSettingsController

  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-settings')
  end

  def test_a_manager_sets_template_and_deciding_roles
    @request.session[:user_id] = @manager.id
    patch :update, params: { project_id: @project.identifier,
                             cosmosys_adr_setting: { template: 'madr', decider_role_ids: ['', @manager_role.id.to_s] } }

    assert_redirected_to "/projects/#{@project.identifier}/settings/cosmosys_adr"
    setting = CosmosysAdr::ProjectSetting.for(@project)
    assert_equal 'madr', setting.template
    assert_equal [@manager_role.id], setting.decider_role_ids
  end

  def test_at_least_one_role_must_decide
    @request.session[:user_id] = @manager.id
    patch :update, params: { project_id: @project.identifier, cosmosys_adr_setting: { template: 'nygard', decider_role_ids: [''] } }

    assert_not_nil flash[:error]
    assert_equal [@manager_role.id, @developer_role.id].sort, CosmosysAdr::ProjectSetting.for(@project).decider_role_ids.sort
  end

  def test_a_role_without_edit_project_cannot_change_settings
    @developer_role.remove_permission!(:edit_project)
    @request.session[:user_id] = @developer.id
    patch :update, params: { project_id: @project.identifier, cosmosys_adr_setting: { template: 'madr', decider_role_ids: [@developer_role.id.to_s] } }

    assert_response :forbidden
  end
end

class CosmosysAdrProjectSettingsTabTest < Redmine::ControllerTest
  tests ProjectsController

  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-settings-tab', template: 'madr')
  end

  def test_the_settings_have_an_adrs_tab
    @request.session[:user_id] = @manager.id
    get :settings, params: { id: @project.identifier, tab: 'cosmosys_adr' }

    assert_response :success
    assert_select '#tab-cosmosys_adr'
    assert_select '#cosmosys-adr-settings-form select#cosmosys_adr_setting_template option[selected][value=madr]'
    assert_select "#cosmosys-adr-settings-form input#cosmosys_adr_setting_role_#{@manager_role.id}[checked]"
    assert_select "#cosmosys-adr-settings-form input#cosmosys_adr_setting_role_#{@reporter_role.id}:not([checked])"
  end

  def test_projects_without_the_module_have_no_adrs_tab
    project = create_adr_project('adr-settings-tab-off', adrs: false)
    @request.session[:user_id] = @manager.id
    get :settings, params: { id: project.identifier }

    assert_select '#tab-cosmosys_adr', 0
  end
end
