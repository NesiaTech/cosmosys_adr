module CosmosysAdr
  # The heading of an ADR page carries its number, and the history shows ADR
  # numbers instead of issue ids for the supersession pointer of an ADR.
  module IssuesHelperPatch
    # The page of an ADR names it by its ADR number too.
    def issue_heading(issue)
      heading = super
      return heading unless issue.respond_to?(:cosmosys_adr?) && issue.cosmosys_adr? && issue.adr_number

      safe_join([heading, ' · ', issue.cosmosys_adr_label])
    end

    def show_detail(detail, no_html = false, options = {})
      return super unless detail.property == 'attr' && detail.prop_key == 'adr_supersedes_id'

      shown = detail.dup
      shown.value = cosmosys_adr_history_label(detail.value)
      shown.old_value = cosmosys_adr_history_label(detail.old_value)
      super(shown, no_html, options)
    end

    private

    # An ADR the user cannot see keeps its plain issue id, as Redmine shows it.
    def cosmosys_adr_history_label(issue_id)
      return nil if issue_id.blank?

      issue = Issue.find_by(id: issue_id)
      return "##{issue_id}" unless issue&.visible?

      CosmosysAdr.label(issue.adr_number) || "##{issue_id}"
    end
  end
end
