require File.expand_path('../test_helper', __dir__)

class CosmosysAdrLockTest < ActiveSupport::TestCase
  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-lock', template: 'madr')
    @adr = accepted_adr(@project, subject: 'Keep sessions in SQLite', adr_decision_makers: 'tech lead')
  end

  def test_a_proposed_adr_can_be_edited
    issue = fresh(create_adr(@project))
    issue.subject = 'Reworded'
    issue.description = 'New text'
    issue.adr_decision_makers = 'whole team'

    assert issue.save
  end

  def test_the_content_of_a_decided_adr_is_locked
    {
      subject: 'Changed',
      description: 'Changed',
      adr_date: Date.new(2020, 1, 1),
      adr_in_force_until: Date.new(2020, 1, 1),
      adr_decision_makers: 'someone else',
      adr_consulted: 'operations',
      adr_informed: 'everyone'
    }.each do |attribute, value|
      issue = fresh(@adr)
      issue.public_send("#{attribute}=", value)

      assert_not issue.save, "#{attribute} should be locked"
      assert_includes issue.errors[:base], I18n.t(:error_cosmosys_adr_locked, label: 'ADR-0001')
    end
  end

  def test_the_lock_message_asks_for_a_superseding_adr_in_both_languages
    assert_match 'create a new ADR that supersedes it', I18n.t(:error_cosmosys_adr_locked, label: 'ADR-0001', locale: :en)
    assert_match 'crea un ADR nuevo que lo sustituya', I18n.t(:error_cosmosys_adr_locked, label: 'ADR-0001', locale: :es)
  end

  def test_project_and_tracker_are_locked
    other = create_adr_project('adr-lock-2')
    issue = fresh(@adr)
    issue.project = other

    assert_not issue.save
    issue = fresh(@adr)
    issue.tracker = @bug_tracker
    assert_not issue.save
  end

  def test_rejected_deprecated_and_superseded_adrs_are_locked_too
    rejected = transition!(create_adr(@project), :rejected)
    deprecated = transition!(accepted_adr(@project), :deprecated)
    [rejected, deprecated].map { |issue| fresh(issue) }.each do |issue|
      issue.subject = 'Changed'

      assert_not issue.save
    end
  end

  def test_notes_stay_open
    issue = fresh(@adr)
    issue.init_journal(@reporter, 'This decision still holds after the load test.')

    assert issue.save
    assert_equal 'This decision still holds after the load test.', issue.journals.last.notes
  end

  def test_custom_field_values_are_locked
    field = IssueCustomField.create!(name: 'Area', field_format: 'string', is_for_all: true, trackers: [@adr_tracker])
    issue = fresh(@adr)
    issue.custom_field_values = { field.id.to_s => 'storage' }

    assert_not issue.save
  end

  def test_attachments_are_locked
    issue = fresh(@adr)

    assert_not issue.attachments_addable?(@manager)
    assert_not issue.attachments_deletable?(@manager)
    issue.save_attachments({ 'p0' => { 'file' => uploaded_test_file('testfile.txt', 'text/plain') } }, @manager)
    assert_not issue.save
    assert fresh(create_adr(@project)).attachments_addable?(@manager)
  end

  def test_status_moves_and_relations_are_still_allowed
    bug = create_bug(@project)
    relation = IssueRelation.create!(issue_from: bug, issue_to: @adr, relation_type: 'relates')

    assert relation.persisted?
    assert_equal :deprecated, transition!(@adr, :deprecated).cosmosys_adr_status_key
  end

  def test_the_format_never_changes
    issue = fresh(create_adr(@project))
    issue.adr_format = 'nygard'

    assert_not issue.save
    assert issue.errors.added?(:adr_format, :cosmosys_adr_immutable)
  end
end
