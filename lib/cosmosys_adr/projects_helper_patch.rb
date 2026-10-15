module CosmosysAdr
  module ProjectsHelperPatch
    def project_settings_tabs
      tabs = super
      return tabs unless CosmosysAdr.module_enabled?(@project) && User.current.allowed_to?(:edit_project, @project)

      tabs << {
        name: 'cosmosys_adr',
        action: :edit_project,
        partial: 'projects/settings/cosmosys_adr',
        label: :label_cosmosys_adr_settings
      }
      tabs
    end
  end
end
