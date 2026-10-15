require File.expand_path('../test_helper', __dir__)

class CosmosysAdrMentionIndexTest < ActiveSupport::TestCase
  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-mentions')
    @meta = create_adr_project('adr-meta')
    @adr = accepted_adr(@project, subject: 'Use PostgreSQL')
    @cross = accepted_adr(@meta, subject: 'Shared database')
  end

  def mentions_of(issue)
    CosmosysAdr::Mention.where(issue_id: issue.id).order(:id).pluck(:source, :target_project_id, :target_number)
  end

  def test_a_mention_in_the_description_is_indexed
    bug = create_bug(@project, description: 'Implements ADR#0001 and ADR#adr-meta#1.')

    assert_equal [['description', @project.id, 1], ['description', @meta.id, 1]], mentions_of(bug)
  end

  def test_removing_the_mention_removes_it_from_the_index
    bug = create_bug(@project, description: 'Implements ADR#0001.')
    bug = fresh(bug)
    bug.description = 'No decision referenced any more.'
    bug.save!

    assert_empty mentions_of(bug)
  end

  def test_notes_are_indexed_when_created_and_edited
    bug = fresh(create_bug(@project))
    bug.init_journal(@developer, 'As decided in ADR#1.')
    bug.save!
    journal = bug.journals.last

    assert_equal [['notes', @project.id, 1]], CosmosysAdr::Mention.where(journal_id: journal.id).pluck(:source, :target_project_id, :target_number)
    journal.update!(notes: 'Never mind.')
    assert_empty CosmosysAdr::Mention.where(journal_id: journal.id)
  end

  def test_long_text_custom_fields_are_indexed
    field = IssueCustomField.create!(name: 'Rationale', field_format: 'text', is_for_all: true, trackers: [@bug_tracker])
    # A fresh project, as in a request: the old object caches its custom fields.
    bug = create_bug(Project.find(@project.id), custom_field_values: { field.id.to_s => 'See ADR#0001' })

    assert_equal [["cf:#{field.id}", @project.id, 1]], mentions_of(bug)
  end

  def test_code_and_escaped_references_are_not_mentions
    bug = create_bug(@project, description: "`ADR#0001`\n\n```\nADR#0001\n```\n\n!ADR#0001")

    assert_empty mentions_of(bug)
  end

  def test_deleting_the_issue_deletes_its_mentions
    bug = create_bug(@project, description: 'ADR#1')
    User.current = @admin
    fresh(bug).destroy

    assert_empty CosmosysAdr::Mention.where(issue_id: bug.id)
  ensure
    User.current = nil
  end
end
