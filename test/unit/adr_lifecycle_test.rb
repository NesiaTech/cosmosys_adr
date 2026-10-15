require File.expand_path('../test_helper', __dir__)

class CosmosysAdrLifecycleTest < ActiveSupport::TestCase
  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-lifecycle')
  end

  def test_an_adr_starts_proposed
    issue = create_adr(@project)

    assert_equal :proposed, issue.cosmosys_adr_status_key
    assert_equal 'cosmosys', issue.adr_source
  end

  def test_an_adr_cannot_be_created_in_another_status
    issue = new_adr(@project, status: adr_status(:accepted))

    assert_not issue.save
    assert issue.errors.added?(:status_id, :cosmosys_adr_must_start_proposed)
  end

  def test_the_form_offers_only_proposed_on_creation
    issue = Issue.new(project: @project, author: @manager)
    issue.send(:safe_attributes=, { 'tracker_id' => @adr_tracker.id.to_s, 'subject' => 'X',
                                    'status_id' => adr_status(:accepted).id.to_s }, @manager)

    assert_equal [adr_status(:proposed)], issue.new_statuses_allowed_to(@manager)
    assert_equal :proposed, issue.cosmosys_adr_status_key
  end

  def test_an_adr_cannot_be_created_where_the_module_is_off
    project = create_adr_project('adr-off', adrs: false)
    project.trackers << @adr_tracker
    issue = new_adr(project)

    assert_not issue.save
    assert_includes issue.errors[:base], I18n.t(:error_cosmosys_adr_module_disabled)
  end

  def test_managers_and_developers_decide_by_default
    assert_equal :accepted, transition!(create_adr(@project), :accepted, user: @manager).cosmosys_adr_status_key
    assert_equal :rejected, transition!(create_adr(@project), :rejected, user: @developer).cosmosys_adr_status_key
    accepted = transition!(create_adr(@project), :accepted, user: @developer)

    assert_equal :deprecated, transition!(accepted, :deprecated, user: @developer).cosmosys_adr_status_key
  end

  def test_a_reporter_cannot_decide
    issue = create_adr(@project)

    error = assert_raises(ActiveRecord::RecordInvalid) { transition!(issue, :accepted, user: @reporter) }
    assert_includes error.record.errors[:base],
                    I18n.t(:error_cosmosys_adr_role_not_allowed, label: issue.cosmosys_adr_label)
    assert_equal :proposed, issue.reload.cosmosys_adr_status_key
  end

  def test_the_form_does_not_offer_decisions_to_other_roles
    issue = create_adr(@project)

    assert_includes issue.new_statuses_allowed_to(@manager), adr_status(:accepted)
    assert_includes issue.new_statuses_allowed_to(@developer), adr_status(:rejected)
    assert_equal [adr_status(:proposed)], issue.new_statuses_allowed_to(@reporter)
  end

  def test_deciding_roles_are_set_per_project_by_role_id
    CosmosysAdr::ProjectSetting.for(@project).update!(decider_role_ids: [@manager_role.id])
    issue = create_adr(@project)

    assert_raises(ActiveRecord::RecordInvalid) { transition!(issue, :accepted, user: @developer) }
    assert_equal :accepted, transition!(issue, :accepted, user: @manager).cosmosys_adr_status_key

    @manager_role.update!(name: 'Project lead')
    other = create_adr(@project)
    assert_equal :accepted, transition!(other, :accepted, user: @manager).cosmosys_adr_status_key
  end

  def test_the_setting_of_one_project_does_not_affect_another
    other = create_adr_project('adr-lifecycle-2')
    CosmosysAdr::ProjectSetting.for(other).update!(decider_role_ids: [@manager_role.id])

    assert_equal :accepted, transition!(create_adr(@project), :accepted, user: @developer).cosmosys_adr_status_key
    assert_raises(ActiveRecord::RecordInvalid) { transition!(create_adr(other), :accepted, user: @developer) }
  end

  def test_an_administrator_can_decide
    assert_equal :accepted, transition!(create_adr(@project), :accepted, user: @admin).cosmosys_adr_status_key
  end

  def test_requesting_a_forbidden_status_is_an_error_not_a_silent_no_op
    issue = fresh(create_adr(@project))
    issue.init_journal(@reporter)
    issue.send(:safe_attributes=, { 'status_id' => adr_status(:accepted).id.to_s }, @reporter)

    assert_not issue.save
    assert_equal :proposed, issue.reload.cosmosys_adr_status_key
  end

  def test_decided_adrs_cannot_go_back
    accepted = accepted_adr(@project)

    assert_raises(ActiveRecord::RecordInvalid) { transition!(accepted, :proposed) }
    rejected = transition!(create_adr(@project), :rejected)
    assert_raises(ActiveRecord::RecordInvalid) { transition!(rejected, :accepted) }
    deprecated = transition!(accepted_adr(@project), :deprecated)
    assert_raises(ActiveRecord::RecordInvalid) { transition!(deprecated, :accepted) }
  end

  def test_a_status_outside_the_lifecycle_is_refused
    issue = fresh(create_adr(@project))
    issue.init_journal(@manager)
    issue.status = IssueStatus.find_by!(name: 'Closed')

    assert_not issue.save
    assert issue.errors.added?(:status_id, :cosmosys_adr_invalid_transition)
  end

  def test_an_issue_cannot_become_an_adr_or_stop_being_one
    bug = fresh(create_bug(@project))
    @project.trackers << @adr_tracker unless @project.trackers.include?(@adr_tracker)
    bug.tracker = @adr_tracker

    assert_not bug.save
    adr = fresh(create_adr(@project))
    adr.tracker = @bug_tracker
    assert_not adr.save
    assert adr.errors.added?(:tracker_id, :cosmosys_adr_tracker_change)
  end

  def test_turning_the_module_off_keeps_the_adrs_and_removes_the_tracker
    issue = create_adr(@project)
    @project.disable_module!(CosmosysAdr::MODULE_NAME)
    CosmosysAdr::ModuleSync.call(@project)

    assert_not_includes @project.reload.trackers, @adr_tracker
    assert Issue.exists?(issue.id)
    @project.enable_module!(CosmosysAdr::MODULE_NAME)
    CosmosysAdr::ModuleSync.call(@project)
    assert_includes @project.reload.trackers, @adr_tracker
  end
end
