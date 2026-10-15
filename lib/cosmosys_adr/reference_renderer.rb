module CosmosysAdr
  # Turns `ADR#…` references of an HTML fragment into links. It runs inside
  # cosmoSys' text pipeline (Cosmosys::PresentationTextRegistry), which Redmine
  # calls for every text outside <pre> and <code>, so code is never touched.
  # Text inside existing links and inside tags is left alone too.
  class ReferenceRenderer
    TOKEN = /(<[^>]*>)/m

    def initialize(project:, user: User.current)
      @project = project
      @user = user || User.anonymous
      @cache = {}
    end

    def render(html)
      depth = 0
      html.to_s.split(TOKEN).map do |token|
        if token.start_with?('<')
          depth += 1 if token.match?(/\A<a[\s>]/i)
          depth -= 1 if token.match?(/\A<\/a\s*>/i) && depth.positive?
          token
        elsif depth.positive? || !token.include?('ADR#')
          token
        else
          render_text(token)
        end
      end.join
    end

    private

    attr_reader :project, :user

    def render_text(text)
      text.gsub(CosmosysAdr::Reference::PATTERN) do
        match_data = Regexp.last_match
        reference = CosmosysAdr::Reference.parse(match_data)
        next reference.raw if CosmosysAdr::Reference.escaped?(match_data)

        @cache[[reference.project_identifier, reference.number]] ||= render_reference(reference)
      end
    end

    def render_reference(reference)
      target_project = CosmosysAdr::Reference.target_project(reference, project)
      return broken(reference) unless target_project

      adr = Issue.includes(:status, :project).find_by(project_id: target_project.id, adr_number: reference.number)
      return broken(reference) unless adr&.cosmosys_adr?
      return restricted(reference, adr) unless adr.visible?(user)

      link(adr, cross_project: target_project != project)
    end

    def link(adr, cross_project:)
      key = adr.cosmosys_adr_status_key
      label = adr.cosmosys_adr_label
      status_name = adr.status&.name.to_s
      title = "#{label}: #{adr.subject} (#{status_name})"
      title = "#{adr.project.name} › #{title}" if cross_project
      classes = ['cosmosys-adr-ref', "cosmosys-adr-ref-#{key}"]
      classes << 'cosmosys-adr-ref-retired' if CosmosysAdr::RETIRED_STATUS_KEYS.include?(key)
      path = Rails.application.routes.url_helpers.issue_path(adr)

      prefix = cross_project ? %(<span class="cosmosys-adr-ref-project">#{attr(adr.project.name)} › </span>) : ''
      anchor = %(<a href="#{attr(path)}" class="#{classes.join(' ')}" title="#{attr(title)}">#{attr(label)} #{attr(adr.subject)}</a>)
      pill = %(<span class="cosmosys-adr-pill cosmosys-adr-pill-#{key}">#{attr(status_name)}</span>)
      "#{prefix}#{anchor} #{pill}"
    end

    def broken(reference)
      %(<span class="cosmosys-broken-reference" title="#{attr(reference.raw)}">#{attr(I18n.t(:label_cosmosys_broken_reference))}</span>)
    end

    def restricted(reference, adr)
      text = I18n.t(:label_cosmosys_adr_restricted_reference, label: adr.cosmosys_adr_label)
      %(<span class="cosmosys-adr-restricted" title="#{attr(reference.raw)}">#{attr(text)}</span>)
    end

    def attr(value)
      CosmosysAdr.html_attribute(value)
    end
  end
end
