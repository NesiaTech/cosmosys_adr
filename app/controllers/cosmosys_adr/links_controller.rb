module CosmosysAdr
  # Explicit links between an issue and an ADR from the "Linked ADRs" panel.
  # A link is a native "relates to" relation, so it also shows in the related
  # issues of both, crosses projects as Redmine allows and is journaled by
  # Redmine. Mentions are not links: they come and go with the text.
  class LinksController < ApplicationController
    before_action :find_issue
    before_action :authorize_links

    def create
      adr = Issue.visible.find_by(id: params[:adr_id])
      unless adr&.cosmosys_adr?
        flash[:error] = l(:error_cosmosys_adr_link_target)
        return redirect_to(issue_path(@issue))
      end

      relation = IssueRelation.new(issue_from: @issue, issue_to: adr, relation_type: IssueRelation::TYPE_RELATES)
      relation.init_journals(User.current)
      if save_relation(relation)
        flash[:notice] = l(:notice_cosmosys_adr_linked, label: adr.cosmosys_adr_label)
      else
        flash[:error] = relation.errors.full_messages.join(' ')
      end
      redirect_to issue_path(@issue)
    end

    def destroy
      relation = IssueRelation.where(relation_type: IssueRelation::TYPE_RELATES)
                              .where('issue_from_id = :id OR issue_to_id = :id', id: @issue.id)
                              .find_by(id: params[:id])
      raise ActiveRecord::RecordNotFound unless relation
      raise ::Unauthorized unless relation.deletable?

      adr = relation.issue_from_id == @issue.id ? relation.issue_to : relation.issue_from
      relation.init_journals(User.current)
      relation.destroy
      flash[:notice] = l(:notice_cosmosys_adr_unlinked, label: adr&.cosmosys_adr_label)
      redirect_to issue_path(@issue)
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    private

    def find_issue
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
      raise ::Unauthorized unless @issue.visible?(User.current)
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def authorize_links
      deny_access unless User.current.allowed_to?(:manage_issue_relations, @project)
    end

    def save_relation(relation)
      relation.save
    rescue ActiveRecord::RecordNotUnique
      relation.errors.add(:base, :taken)
      false
    end
  end
end
