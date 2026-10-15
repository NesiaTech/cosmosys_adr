require_dependency 'enabled_module'

module CosmosysAdr
  # Project#enable_module! and #disable_module! create and destroy one
  # EnabledModule without saving the project.
  module EnabledModulePatch
    def self.included(base)
      base.class_eval do
        after_commit :cosmosys_adr_sync_module, on: %i[create destroy], if: :cosmosys_adr_module?
      end
    end

    private

    def cosmosys_adr_module?
      name.to_s == CosmosysAdr::MODULE_NAME
    end

    def cosmosys_adr_sync_module
      CosmosysAdr::ModuleSync.call(Project.find_by(id: project_id))
    end
  end
end
