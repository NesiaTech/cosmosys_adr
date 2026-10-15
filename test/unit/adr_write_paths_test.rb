require File.expand_path('../test_helper', __dir__)

# cosmoSys writes issues outside the issue form too: the ODS import, snapshot
# materialisation and project copies. They all reach ADR fields through the
# item field registry and save through the model, so the same rules apply.
class CosmosysAdrWritePathsTest < ActiveSupport::TestCase
  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-paths', template: 'madr')
    @old = accepted_adr(@project, subject: 'Keep sessions in SQLite', adr_decision_makers: 'tech lead')
    @new = create_adr(@project, subject: 'Store sessions in PostgreSQL', adr_supersedes_id: @old.id)
    @new = transition!(@new, :accepted)
    @proposed = create_adr(@project, subject: 'Still open')
  end

  def test_the_item_field_registry_carries_adr_fields
    values = Cosmosys::OdsItemFieldRegistry.values_for(fresh(@new))

    assert_equal 2, values['adr_number']
    assert_equal 'madr', values['adr_format']
    assert_equal @old.csid, values['adr_supersedes']
    assert_nil Cosmosys::OdsItemFieldRegistry.values_for(create_bug(@project))['adr_number']
  end

  def test_an_import_cannot_change_a_decided_adr
    issue = fresh(@old)
    Cosmosys::OdsItemFieldRegistry.apply(issue, { 'adr_decision_makers' => 'someone else' })

    assert_not issue.save
    assert_includes issue.errors[:base], I18n.t(:error_cosmosys_adr_locked, label: 'ADR-0001')
  end

  def test_an_import_can_change_a_proposed_adr_but_not_its_number
    issue = fresh(@proposed)
    Cosmosys::OdsItemFieldRegistry.apply(issue, { 'adr_decision_makers' => 'new team' })
    assert issue.save

    issue = fresh(@proposed)
    Cosmosys::OdsItemFieldRegistry.apply(issue, { 'adr_number' => '9' })
    assert_not issue.save
  end

  def test_a_new_adr_from_a_member_import_gets_a_fresh_number_and_must_be_proposed
    issue = new_adr(@project)
    Cosmosys::OdsItemFieldRegistry.apply(issue, { 'adr_number' => '1', 'adr_format' => 'madr' })
    User.current = @manager
    issue.save!

    assert_equal 4, issue.adr_number
    accepted = new_adr(@project, status: adr_status(:accepted))
    Cosmosys::OdsItemFieldRegistry.apply(accepted, { 'adr_number' => '7' })
    assert_not accepted.save
  ensure
    User.current = nil
  end

  def test_a_snapshot_materialisation_keeps_numbers_statuses_and_supersession
    User.current = @admin
    snapshot = Cosmosys::ProjectSnapshotCapture.new(@project, user: @admin, projects: [@project.id])
    copy = Cosmosys::ProjectSnapshotMaterializer.new(
      snapshot, user: @admin,
      attributes: { 'name' => 'ADR copy', 'identifier' => 'adr-paths-copy', 'cscode' => 'ADRCOPY',
                    'copy_mode' => 'faithful', 'identity_mode' => 'new' }
    ).call
    adrs = copy.issues.where.not(adr_number: nil).order(:adr_number).to_a

    assert_equal [1, 2, 3], adrs.map(&:adr_number)
    assert_equal %i[superseded accepted proposed], adrs.map(&:cosmosys_adr_status_key)
    assert_equal adrs.first, adrs.second.adr_supersedes
    assert_equal adrs.second, adrs.first.cosmosys_adr_superseded_by
    assert_equal 'tech lead', adrs.first.adr_decision_makers
    assert_equal [@old.reload.adr_date, @new.reload.adr_date, nil], adrs.map(&:adr_date)
    assert_equal @old.adr_in_force_until, adrs.first.adr_in_force_until
    assert_equal 3, CosmosysAdr::ProjectSetting.for(copy).last_number

    copied = fresh(adrs.second)
    copied.subject = 'Edited after the copy'
    assert_not copied.save
  ensure
    User.current = nil
  end

  def test_a_clean_working_copy_starts_every_adr_over_without_decision_dates
    User.current = @admin
    snapshot = Cosmosys::ProjectSnapshotCapture.new(@project, user: @admin, projects: [@project.id])
    copy = Cosmosys::ProjectSnapshotMaterializer.new(
      snapshot, user: @admin,
      attributes: { 'name' => 'ADR clean copy', 'identifier' => 'adr-paths-clean', 'cscode' => 'ADRCLEAN',
                    'copy_mode' => 'clean', 'identity_mode' => 'new' }
    ).call
    adrs = copy.issues.where.not(adr_number: nil).order(:adr_number).to_a

    assert_equal [1, 2, 3], adrs.map(&:adr_number)
    assert_equal %i[proposed proposed proposed], adrs.map(&:cosmosys_adr_status_key)
    assert_equal [nil, nil, nil], adrs.map(&:adr_date)
    assert_equal [nil, nil, nil], adrs.map(&:adr_in_force_until)
  ensure
    User.current = nil
  end

  def test_a_copied_project_keeps_the_adr_settings
    setting = CosmosysAdr::ProjectSetting.for!(@project)
    setting.update!(decider_role_ids: [@manager_role.id])
    copy = Project.new(name: 'Settings copy', identifier: 'adr-paths-settings', cscode: 'ADRSET')
    copy.csys_modules_explicit = '1'
    copy.enabled_module_names = %w[issue_tracking adrs]

    assert copy.copy(@project, only: %w[members])
    copied = CosmosysAdr::ProjectSetting.find_by(project_id: copy.id)
    assert_equal 'madr', copied.template
    assert_equal [@manager_role.id], copied.decider_role_ids
    assert_equal setting.reload.last_number, copied.last_number
  end
end
