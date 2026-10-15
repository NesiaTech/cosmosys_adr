require File.expand_path('../test_helper', __dir__)

class CosmosysAdrSetupTest < ActiveSupport::TestCase
  def setup
    setup_cosmosys_adr
  end

  def test_the_migration_creates_the_tracker
    assert_equal 'csAdr', @adr_tracker.name
    assert_equal 'adr', @adr_tracker.csys_item_kind
    assert_equal adr_status(:proposed), @adr_tracker.default_status
    assert_equal %w[assigned_to_id start_date due_date estimated_hours done_ratio].sort,
                 @adr_tracker.disabled_core_fields.sort
  end

  def test_the_migration_creates_the_statuses
    {
      proposed: [false, nil, 1],
      accepted: [true, 'successful', 4],
      rejected: [true, 'unsuccessful', 0],
      deprecated: [true, 'unsuccessful', 0],
      superseded: [true, 'unsuccessful', 0]
    }.each do |key, (closed, outcome, maturity)|
      status = adr_status(key)

      assert_equal CosmosysAdr::STATUS_NAMES.fetch(key), status.name
      assert_equal closed, status.is_closed, key
      outcome.nil? ? assert_nil(status.csys_closed_outcome, key) : assert_equal(outcome, status.csys_closed_outcome, key)
      assert_equal maturity, status.csys_maturity, key
    end
    assert_equal IssueStatus.find_by(name: 'Rejected'), adr_status(:rejected)
  end

  def test_status_ids_survive_a_rename
    adr_status(:accepted).update!(name: 'Aceptado')
    Setting.clear_cache

    assert_equal 'Aceptado', adr_status(:accepted).name
  end

  def test_the_workflow_has_the_decisions_of_every_role
    Role.givable.each do |role|
      transitions = WorkflowTransition.where(tracker_id: @adr_tracker.id, role_id: role.id).map do |workflow|
        [CosmosysAdr.status_key(workflow.old_status_id), CosmosysAdr.status_key(workflow.new_status_id)]
      end

      assert_equal [%i[accepted deprecated], %i[proposed accepted], %i[proposed rejected]], transitions.sort
    end
  end

  def test_the_item_profile_keeps_adrs_out_of_tree_report_and_diagrams
    profile = Cosmosys::ItemKindRegistry.fetch('adr')

    assert_equal :cosmosys_adr, profile.provider
    assert_equal [false, false, false, false, false, false, 'admin_only'],
                 profile.to_h.values_at(:tree_visible, :report_visible, :chapter_numbered, :diagram_visible,
                                        :can_have_children, :can_split, :physical_delete_policy)
  end

  def test_default_deciders_are_found_in_other_languages
    @manager_role.update!(name: 'Jefe de proyecto')
    @developer_role.update!(name: 'Desarrollador')

    assert_equal [@manager_role.id, @developer_role.id].sort, CosmosysAdr::ProjectSetting.default_decider_role_ids.sort
  end
end
