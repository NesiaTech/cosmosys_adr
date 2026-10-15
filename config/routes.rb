RedmineApp::Application.routes.draw do
  patch 'projects/:project_id/adrs/settings', to: 'cosmosys_adr/project_settings#update',
                                              as: :project_cosmosys_adr_settings
end
