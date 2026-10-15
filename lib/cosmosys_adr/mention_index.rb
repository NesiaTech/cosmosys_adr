require 'nokogiri'

module CosmosysAdr
  # Keeps cosmosys_adr_mentions in step with the texts of an issue. The text
  # is rendered with Redmine's formatter first, so what counts as a mention is
  # exactly what the page shows as a reference: code blocks, inline code and
  # the text of existing links are skipped, like escaped `!ADR#…`.
  module MentionIndex
    SKIPPED_ANCESTORS = %w[pre code a].freeze

    module_function

    # Description, long text columns and long text custom fields of an issue.
    def reindex_issue(issue)
      return unless issue.persisted? && CosmosysAdr::Mention.table_exists?

      rows = issue_sources(issue).flat_map do |source, text|
        targets(text, issue.project).map { |project_id, number| row(issue, nil, source, project_id, number) }
      end
      CosmosysAdr::Mention.transaction do
        CosmosysAdr::Mention.where(issue_id: issue.id, journal_id: nil).delete_all
        CosmosysAdr::Mention.insert_all(rows) if rows.any?
      end
    end

    # The notes of one journal of an issue.
    def reindex_journal(journal)
      issue = journal.journalized
      return unless issue.is_a?(Issue) && journal.persisted? && CosmosysAdr::Mention.table_exists?

      rows = targets(journal.notes, issue.project).map do |project_id, number|
        row(issue, journal, CosmosysAdr::Mention::SOURCE_NOTES, project_id, number)
      end
      CosmosysAdr::Mention.transaction do
        CosmosysAdr::Mention.where(journal_id: journal.id).delete_all
        CosmosysAdr::Mention.insert_all(rows) if rows.any?
      end
    end

    # [[project_id, number], ...] for the references of a text, resolved
    # against the project the text belongs to. References to projects that do
    # not exist are left out; references to numbers not used yet are kept.
    def targets(text, project)
      return [] if text.blank? || !text.to_s.include?('ADR#') || project.nil?

      visible_text(text).flat_map { |chunk| CosmosysAdr::Reference.scan(chunk) }.filter_map do |reference|
        target = CosmosysAdr::Reference.target_project(reference, project)
        [target.id, reference.number] if target && reference.number.positive?
      end.uniq
    end

    def visible_text(text)
      html = Redmine::WikiFormatting.to_html(Setting.text_formatting, text.to_s)
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      fragment.xpath('.//text()').filter_map do |node|
        next if node.ancestors.any? { |ancestor| SKIPPED_ANCESTORS.include?(ancestor.name) }

        node.text
      end
    end

    def issue_sources(issue)
      sources = { CosmosysAdr::Mention::SOURCE_DESCRIPTION => issue.description }
      text_columns.each do |column|
        sources["#{CosmosysAdr::Mention::FIELD_PREFIX}#{column}"] = issue[column] if issue.has_attribute?(column)
      end
      issue.custom_field_values.each do |value|
        next unless value.custom_field.field_format == 'text'

        sources["#{CosmosysAdr::Mention::CUSTOM_FIELD_PREFIX}#{value.custom_field_id}"] = Array(value.value).join("\n")
      end
      sources.compact_blank
    end

    # Long text columns other plugins add to issues, such as the rationale of
    # a requirement. ADR fields hold names, not prose, and are left out.
    def text_columns
      Issue.columns.select { |column| column.type == :text }.map(&:name) -
        %w[description adr_decision_makers adr_consulted adr_informed]
    end

    def row(issue, journal, source, project_id, number)
      {
        issue_id: issue.id,
        journal_id: journal&.id,
        source: source,
        target_project_id: project_id,
        target_number: number,
        created_at: Time.current
      }
    end
  end
end
