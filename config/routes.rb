RedmineApp::Application.routes.draw do
  patch 'projects/:project_id/adrs/settings', to: 'cosmosys_adr/project_settings#update',
                                              as: :project_cosmosys_adr_settings
  post 'issues/:issue_id/adr/transition', to: 'cosmosys_adr/transitions#create', as: :issue_cosmosys_adr_transition
  post 'issues/:issue_id/adr/links', to: 'cosmosys_adr/links#create', as: :issue_cosmosys_adr_links
  delete 'issues/:issue_id/adr/links/:id', to: 'cosmosys_adr/links#destroy', as: :issue_cosmosys_adr_link
end
