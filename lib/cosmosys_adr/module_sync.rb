module CosmosysAdr
  # The ADRs module owns the csAdr tracker of a project: turning the module on
  # adds the tracker, turning it off removes it. The ADRs themselves stay, and
  # come back to the tab when the module is turned on again.
  module ModuleSync
    module_function

    def call(project)
      return unless project&.persisted?

      adr_tracker = CosmosysAdr.tracker
      return unless adr_tracker

      enabled = EnabledModule.where(project_id: project.id, name: CosmosysAdr::MODULE_NAME).exists?
      linked = project_tracker_scope(project, adr_tracker).exists?
      if enabled && !linked
        add_tracker(project, adr_tracker)
        CosmosysAdr::ProjectSetting.for!(project)
      elsif !enabled && linked
        project_tracker_scope(project, adr_tracker).delete_all
      end
      project.trackers.reset if project.association(:trackers).loaded?
    end

    def project_tracker_scope(project, adr_tracker)
      join_model.where(project_id: project.id, tracker_id: adr_tracker.id)
    end

    def add_tracker(project, adr_tracker)
      join_model.insert_all([{ project_id: project.id, tracker_id: adr_tracker.id }],
                            unique_by: %i[project_id tracker_id])
    rescue ArgumentError
      # No unique index to resolve conflicts on: insert only when absent.
      join_model.create!(project_id: project.id, tracker_id: adr_tracker.id) unless project_tracker_scope(project, adr_tracker).exists?
    end

    def join_model
      @join_model ||= Class.new(ActiveRecord::Base) do
        self.table_name = 'projects_trackers'
        self.primary_key = nil
      end
    end
  end
end
