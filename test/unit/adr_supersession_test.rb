require File.expand_path('../test_helper', __dir__)

class CosmosysAdrSupersessionTest < ActiveSupport::TestCase
  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-supersede')
    @old = accepted_adr(@project, subject: 'Keep sessions in SQLite')
  end

  def test_accepting_the_new_adr_supersedes_the_old_one
    new_adr = create_adr(@project, subject: 'Store sessions in PostgreSQL', adr_supersedes_id: @old.id)

    assert_equal :accepted, @old.reload.cosmosys_adr_status_key
    transition!(new_adr, :accepted, user: @developer)

    assert_equal :superseded, @old.reload.cosmosys_adr_status_key
    assert_equal new_adr, @old.cosmosys_adr_superseded_by
    assert_equal @old, new_adr.reload.adr_supersedes
  end

  def test_the_superseded_adr_stops_being_in_force_the_day_the_new_one_is_accepted
    new_adr = create_adr(@project, adr_supersedes_id: @old.id)
    transition!(new_adr, :accepted, user: @developer)

    assert_equal @developer.today, @old.reload.adr_in_force_until
    assert_equal @developer.today, new_adr.reload.adr_date
    assert_nil new_adr.adr_in_force_until
  end

  def test_both_histories_record_the_supersession
    new_adr = create_adr(@project, adr_supersedes_id: @old.id)
    transition!(new_adr, :accepted, user: @developer)

    old_journal = @old.reload.journals.order(:id).last
    assert_equal @developer, old_journal.user
    assert old_journal.details.any? { |d| d.prop_key == 'status_id' && d.value == adr_status(:superseded).id.to_s }
    assert old_journal.details.any? { |d| d.prop_key == 'adr_superseded_by' && d.value == 'ADR-0002' }
    new_journal = new_adr.reload.journals.order(:id).last
    assert new_journal.details.any? { |d| d.prop_key == 'adr_superseded' && d.value == 'ADR-0001' }
  end

  def test_only_an_accepted_adr_of_the_same_project_can_be_superseded
    proposed = create_adr(@project)
    other_project = create_adr_project('adr-supersede-2')
    foreign = accepted_adr(other_project)

    [proposed, foreign, create_bug(@project)].each do |target|
      issue = new_adr(@project, adr_supersedes_id: target.id)

      assert_not issue.save, "#{target.subject} should not be supersedable"
    end
  end

  def test_an_adr_that_is_no_longer_accepted_cannot_be_superseded_on_acceptance
    first = create_adr(@project, adr_supersedes_id: @old.id)
    second = create_adr(@project, adr_supersedes_id: @old.id)
    transition!(first, :accepted)

    error = assert_raises(ActiveRecord::RecordInvalid) { transition!(second, :accepted) }
    assert error.record.errors.added?(:adr_supersedes_id, :cosmosys_adr_supersedes_not_accepted)
    assert_equal first, @old.reload.cosmosys_adr_superseded_by
  end

  def test_supersession_is_atomic
    new_adr = create_adr(@project, adr_supersedes_id: @old.id)
    CosmosysAdr::Supersession.any_instance.stubs(:call).raises(ActiveRecord::RecordInvalid.new(new_adr))

    assert_raises(ActiveRecord::RecordInvalid) { transition!(new_adr, :accepted) }
    assert_equal :proposed, new_adr.reload.cosmosys_adr_status_key
    assert_equal :accepted, @old.reload.cosmosys_adr_status_key
  end

  def test_rejecting_the_new_adr_leaves_the_old_one_accepted
    new_adr = create_adr(@project, adr_supersedes_id: @old.id)
    transition!(new_adr, :rejected)

    assert_equal :accepted, @old.reload.cosmosys_adr_status_key
    assert_nil @old.cosmosys_adr_superseded_by
  end

  def test_deleting_the_old_adr_clears_the_pointer
    new_adr = create_adr(@project, adr_supersedes_id: @old.id)
    transition!(new_adr, :accepted)
    User.current = @admin
    fresh(@old).destroy

    assert_nil new_adr.reload.adr_supersedes_id
  ensure
    User.current = nil
  end
end
