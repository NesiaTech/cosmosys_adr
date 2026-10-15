require_dependency 'project'

module CosmosysAdr
  module ProjectPatch
    def self.included(base)
      base.class_eval do
        has_one :cosmosys_adr_setting, class_name: 'CosmosysAdr::ProjectSetting', foreign_key: :project_id,
                dependent: :delete
        # Modules saved from the project settings are replaced in bulk, without
        # callbacks on the removed records, so the tracker follows the module
        # once the project is committed.
        after_commit :cosmosys_adr_sync_module, on: %i[create update]
      end
    end

    private

    def cosmosys_adr_sync_module
      CosmosysAdr::ModuleSync.call(self)
    end
  end
end
