module CosmosysAdr
  # The ADRs tab of a project: the list of its ADRs with filters, and a
  # sidebar with the project's ADR settings, counts and latest changes.
  class AdrsController < ApplicationController
    menu_item :cosmosys_adrs

    before_action :find_project_by_project_id
    before_action :authorize
    before_action :require_adr_visibility

    helper :issues
    helper 'cosmosys_adr/adrs'

    def index
      @tracker = CosmosysAdr.tracker
      @setting = CosmosysAdr::ProjectSetting.for(@project)
      @status_filter = selected_status_keys
      @title_filter = params[:title].to_s.strip
      @format_filter = CosmosysAdr::FORMATS.include?(params[:format_filter].to_s) ? params[:format_filter].to_s : ''
      @show_content = params[:content].to_s == '1'

      @all_adrs = Issue.visible.where(project_id: @project.id, tracker_id: @tracker.id).where.not(adr_number: nil)
                       .includes(:status, :author).order(:adr_number).to_a
      @adrs = @all_adrs.select { |adr| shown?(adr) }
      @counts = CosmosysAdr::STATUS_KEYS.index_with { |key| @all_adrs.count { |adr| adr.cosmosys_adr_status_key == key } }
      @link_counts = CosmosysAdr::Links.counts(@all_adrs, User.current)
      @recent_journals = Journal.visible(User.current).where(journalized_type: 'Issue', journalized_id: @all_adrs.map(&:id))
                                .includes(:details, :user).reorder(created_on: :desc, id: :desc).limit(5).to_a
      @adrs_by_id = @all_adrs.index_by(&:id)
    end

    private

    def require_adr_visibility
      deny_access unless CosmosysAdr.adrs_viewable?(@project, User.current)
    end

    def selected_status_keys
      requested = Array(params[:status]).map(&:to_s)
      keys = CosmosysAdr::STATUS_KEYS.select { |key| requested.include?(key.to_s) }
      params.key?(:status) || params.key?(:filtered) ? keys : CosmosysAdr::STATUS_KEYS
    end

    def shown?(adr)
      return false unless @status_filter.include?(adr.cosmosys_adr_status_key)
      return false if @title_filter.present? && !adr.subject.to_s.downcase.include?(@title_filter.downcase)
      return false if @format_filter.present? && adr.adr_format != @format_filter

      true
    end
  end
end
