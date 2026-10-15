module CosmosysAdr
  # View helpers of the ADR panels on issue pages. Included into
  # ApplicationHelper so hook partials can use them.
  module AdrsHelper
    def cosmosys_adr_status_pill(issue)
      key = issue.cosmosys_adr_status_key
      text = issue.status&.name.to_s
      if key == :superseded && (successor = issue.cosmosys_adr_superseded_by)
        text = l(:label_cosmosys_adr_superseded_by_pill, label: successor.cosmosys_adr_label)
      end
      content_tag(:span, text, class: "cosmosys-adr-pill cosmosys-adr-pill-#{key || 'unknown'}")
    end

    def cosmosys_adr_link(issue, with_subject: true)
      text = with_subject ? "#{issue.cosmosys_adr_label} #{issue.subject}" : issue.cosmosys_adr_label
      classes = ['cosmosys-adr-ref', "cosmosys-adr-ref-#{issue.cosmosys_adr_status_key}"]
      classes << 'cosmosys-adr-ref-retired' if CosmosysAdr::RETIRED_STATUS_KEYS.include?(issue.cosmosys_adr_status_key)
      link_to(text, issue_path(issue), class: classes.join(' '), title: issue.subject)
    end

    def cosmosys_adr_origin_label(entry)
      entry.explicit? ? l(:label_cosmosys_adr_origin_link) : l(:label_cosmosys_adr_origin_mention)
    end
  end
end
