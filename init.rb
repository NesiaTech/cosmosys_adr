require 'redmine'

Redmine::Plugin.register :cosmosys_adr do
  name 'cosmoSys ADR'
  author 'Nesia Tech'
  description 'Architecture Decision Records for cosmoSys.'
  version '0.1.0'
  url 'https://github.com/NesiaTech/cosmosys_adr'
  author_url 'https://nesia.tech'

  requires_redmine_plugin :cosmosys, version_or_higher: '0.1.7'

  # Status ids are written by the migration, so renaming or translating a
  # status in the administration does not break the plugin.
  settings default: { 'status_ids' => {} }

  project_module :adrs do
    # The module grants nothing by itself: who can see, create or edit ADRs
    # is decided by Redmine's own issue permissions on the csAdr tracker.
    permission :view_adrs, {}, public: true, read: true
  end
end

require_dependency 'issue'
require_dependency 'project'
require_dependency 'enabled_module'
require_dependency 'projects_helper'
require_dependency File.expand_path('lib/cosmosys_adr', __dir__)
require_dependency File.expand_path('app/models/cosmosys_adr/project_setting', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/profile_registration', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/templates', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/supersession', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/module_sync', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/issue_patch', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/issue_workflow_patch', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/project_patch', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/enabled_module_patch', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/projects_helper_patch', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/ods_fields', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/hooks', __dir__)

Cosmosys::ProjectCopyReferenceRegistry.register(:adr_supersedes_id)

patch_cosmosys_adr = proc do
  Issue.include CosmosysAdr::IssuePatch unless Issue < CosmosysAdr::IssuePatch
  Issue.prepend CosmosysAdr::IssueWorkflowPatch unless Issue < CosmosysAdr::IssueWorkflowPatch
  Project.include CosmosysAdr::ProjectPatch unless Project < CosmosysAdr::ProjectPatch
  EnabledModule.include CosmosysAdr::EnabledModulePatch unless EnabledModule < CosmosysAdr::EnabledModulePatch
  ProjectsHelper.prepend CosmosysAdr::ProjectsHelperPatch unless ProjectsHelper < CosmosysAdr::ProjectsHelperPatch
end

patch_cosmosys_adr.call
Rails.application.config.to_prepare(&patch_cosmosys_adr)
