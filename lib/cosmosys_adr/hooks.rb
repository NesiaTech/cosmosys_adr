module CosmosysAdr
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head,
      { partial: 'hooks/cosmosys_adr/html_head' }
    render_on :view_issues_form_details_bottom,
      { partial: 'hooks/cosmosys_adr/adr_fields' }
    render_on :view_issues_show_details_bottom,
      { partial: 'hooks/cosmosys_adr/adr_details' }
    render_on :view_issues_show_description_bottom,
      { partial: 'hooks/cosmosys_adr/issue_panel' }

    # Called by Project#copy once the new project exists, for the native copy
    # and for cosmoSys' own.
    def model_project_copy_before_save(context = {})
      CosmosysAdr::ProjectSetting.copy!(context.fetch(:source_project), context.fetch(:destination_project))
    end
  end
end
