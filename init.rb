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
end

require_dependency File.expand_path('lib/cosmosys_adr', __dir__)
require_dependency File.expand_path('lib/cosmosys_adr/profile_registration', __dir__)
