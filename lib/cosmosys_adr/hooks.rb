module CosmosysAdr
  class Hooks < Redmine::Hook::ViewListener
    # Called by Project#copy once the new project exists, for the native copy
    # and for cosmoSys' own.
    def model_project_copy_before_save(context = {})
      CosmosysAdr::ProjectSetting.copy!(context.fetch(:source_project), context.fetch(:destination_project))
    end
  end
end
