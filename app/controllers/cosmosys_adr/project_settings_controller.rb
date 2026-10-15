module CosmosysAdr
  # The ADRs tab of the project settings: template of new ADRs and the roles
  # that accept, reject and deprecate them.
  class ProjectSettingsController < ApplicationController
    menu_item :settings

    before_action :find_project_by_project_id
    before_action :authorize_settings

    def update
      setting = CosmosysAdr::ProjectSetting.for(@project)
      attributes = params.fetch(:cosmosys_adr_setting, {})
      setting.template = attributes[:template].to_s
      setting.decider_role_ids = Array(attributes[:decider_role_ids])
      if setting.save(context: :settings_form)
        flash[:notice] = l(:notice_successful_update)
      else
        flash[:error] = setting.errors.full_messages.join(' ')
      end
      redirect_to settings_project_path(@project, tab: 'cosmosys_adr')
    end

    private

    def authorize_settings
      deny_access unless CosmosysAdr.module_enabled?(@project) && User.current.allowed_to?(:edit_project, @project)
    end
  end
end
