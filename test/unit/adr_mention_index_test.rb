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

  def test_a_mention_of_a_future_adr_resolves_once_it_exists
    bug = create_bug(@project, description: 'Will follow ADR#0002.')
    assert_empty CosmosysAdr::Links.for_issue(bug, @developer)

    later = create_adr(@project, subject: 'Later decision')
    entry = CosmosysAdr::Links.for_issue(bug, @developer).first
    assert_equal later, entry.issue
    assert_equal :mention, entry.origin
  end

  def test_mentions_and_links_show_on_both_sides
    linked = create_bug(@project, subject: 'Linked')
    IssueRelation.create!(issue_from: linked, issue_to: @adr, relation_type: 'relates')
    mentioning = create_bug(@project, subject: 'Mentions', description: 'Per ADR#1')

    adr_side = CosmosysAdr::Links.for_adr(@adr, @developer).map { |entry| [entry.issue, entry.origin] }
    assert_includes adr_side, [linked, :link]
    assert_includes adr_side, [mentioning, :mention]
    assert_equal [[@adr, :link]], CosmosysAdr::Links.for_issue(linked, @developer).map { |entry| [entry.issue, entry.origin] }
    assert_equal [[@adr, :mention]], CosmosysAdr::Links.for_issue(mentioning, @developer).map { |entry| [entry.issue, entry.origin] }
  end

  def test_the_adrs_tab_counts_mentions_and_links_once_per_issue
    both = create_bug(@project, description: 'ADR#1')
    IssueRelation.create!(issue_from: both, issue_to: @adr, relation_type: 'relates')
    create_bug(@project, description: 'Also ADR#1')

    assert_equal 2, CosmosysAdr::Links.counts([fresh(@adr)], @developer)[@adr.id]
  end

  def test_a_private_note_mention_is_hidden_from_users_without_access
    bug = fresh(create_bug(@project))
    bug.init_journal(@developer, 'Secretly ADR#1')
    bug.current_journal.private_notes = true
    bug.save!
    @reporter_role.remove_permission!(:view_private_notes)
    @developer_role.add_permission!(:view_private_notes)

    assert CosmosysAdr::Links.for_adr(@adr, User.find(@developer.id)).any? { |entry| entry.issue == bug }
    assert_not CosmosysAdr::Links.for_adr(@adr, User.find(@reporter.id)).any? { |entry| entry.issue == bug }
    assert_equal 1, CosmosysAdr::Links.counts([fresh(@adr)], User.find(@developer.id))[@adr.id]
    assert_equal 0, CosmosysAdr::Links.counts([fresh(@adr)], User.find(@reporter.id))[@adr.id]
  end

  def test_a_mention_in_a_custom_field_the_user_cannot_see_stays_hidden
    field = IssueCustomField.create!(name: 'Internal notes', field_format: 'text', is_for_all: true,
                                     trackers: [@bug_tracker], visible: false, role_ids: [@manager_role.id])
    # Written by a manager, who can see and edit the field.
    User.current = @manager
    bug = create_bug(Project.find(@project.id), author: @manager, custom_field_values: { field.id.to_s => 'See ADR#0001' })
    User.current = nil

    assert_equal [["cf:#{field.id}", @project.id, 1]], mentions_of(bug)
    assert_includes CosmosysAdr::Links.for_adr(@adr, User.find(@manager.id)).map(&:issue), bug
    assert_not_includes CosmosysAdr::Links.for_adr(@adr, User.find(@developer.id)).map(&:issue), bug
    assert_empty CosmosysAdr::Links.for_issue(fresh(bug), User.find(@developer.id))
    assert_equal 0, CosmosysAdr::Links.counts([fresh(@adr)], User.find(@developer.id))[@adr.id]
  ensure
    User.current = nil
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
