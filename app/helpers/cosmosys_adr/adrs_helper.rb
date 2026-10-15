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

    def cosmosys_adr_format_pill(format)
      content_tag(:span, cosmosys_adr_format_label(format), class: 'cosmosys-adr-pill cosmosys-adr-pill-format')
    end

    def cosmosys_adr_format_label(format)
      l(:"label_cosmosys_adr_format_#{CosmosysAdr::FORMATS.include?(format.to_s) ? format : CosmosysAdr::DEFAULT_FORMAT}")
    end

    def cosmosys_adr_lock_badge(issue)
      if issue.cosmosys_adr_locked?
        content_tag(:span, l(:label_cosmosys_adr_locked), class: 'cosmosys-adr-lock cosmosys-adr-lock-closed')
      else
        content_tag(:span, l(:label_cosmosys_adr_editable), class: 'cosmosys-adr-lock cosmosys-adr-lock-open')
      end
    end

    def cosmosys_adr_link(issue, with_subject: true)
      text = with_subject ? "#{issue.cosmosys_adr_label} #{issue.subject}" : issue.cosmosys_adr_label
      classes = ['cosmosys-adr-ref', "cosmosys-adr-ref-#{issue.cosmosys_adr_status_key}"]
      classes << 'cosmosys-adr-ref-retired' if CosmosysAdr::RETIRED_STATUS_KEYS.include?(issue.cosmosys_adr_status_key)
      link_to(text, issue_path(issue), class: classes.join(' '), title: issue.subject)
    end

    def cosmosys_adr_role_names(setting)
      names = setting.decider_roles.map(&:name)
      names.any? ? names.join(', ') : l(:label_none)
    end

    def cosmosys_adr_origin_label(entry)
      entry.explicit? ? l(:label_cosmosys_adr_origin_link) : l(:label_cosmosys_adr_origin_mention)
    end

    def cosmosys_adr_transition_button(issue, action, css_class)
      button_to(l(:"button_cosmosys_adr_#{action}"), issue_cosmosys_adr_transition_path(issue),
                params: { to: action }, method: :post, class: "cosmosys-adr-button #{css_class}",
                form_class: 'cosmosys-adr-transition-form')
    end
  end
end
