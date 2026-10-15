require_dependency 'project'

module CosmosysAdr
  module ProjectPatch
    def self.included(base)
      base.class_eval do
        has_one :cosmosys_adr_setting, class_name: 'CosmosysAdr::ProjectSetting', foreign_key: :project_id,
                dependent: :delete
      end
    end
  end
end
