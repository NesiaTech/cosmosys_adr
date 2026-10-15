module CosmosysAdr
  # Accept, reject and deprecate buttons of the ADR page. They change the
  # status like the issue form does, with the same validations; the status is
  # offered only if Redmine's workflow and the project's deciding roles allow
  # it for the current user.
  class TransitionsController < ApplicationController
    ACTIONS = { 'accept' => :accepted, 'reject' => :rejected, 'deprecate' => :deprecated }.freeze

    before_action :find_adr

    def create
      target_key = ACTIONS[params[:to].to_s]
      target = target_key && CosmosysAdr.status(target_key)
      unless target && @issue.editable?(User.current) && @issue.new_statuses_allowed_to(User.current).include?(target)
        return deny_access
      end

      @issue.init_journal(User.current, params[:notes].to_s)
      @issue.status = target
      if @issue.save
        flash[:notice] = l(:"notice_cosmosys_adr_#{target_key}", label: @issue.cosmosys_adr_label)
      else
        flash[:error] = @issue.errors.full_messages.join(' ')
      end
      redirect_to issue_path(@issue)
    end

    private

    def find_adr
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
      raise ::Unauthorized unless @issue.visible?(User.current) && @issue.cosmosys_adr?
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
