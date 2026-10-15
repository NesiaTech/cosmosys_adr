require File.expand_path('../test_helper', __dir__)

class CosmosysAdrPermissionsTest < ActiveSupport::TestCase
  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-private')
    @adr = create_adr(@project)
    @outsider = User.generate!
  end

  def test_a_non_member_cannot_see_adrs_of_a_private_project
    assert_not @adr.visible?(@outsider)
    assert_not CosmosysAdr.adrs_viewable?(@project, @outsider)
    assert CosmosysAdr.adrs_viewable?(@project, @reporter)
  end

  def test_the_tab_needs_the_module
    project = create_adr_project('adr-no-module', adrs: false)

    assert_not CosmosysAdr.adrs_viewable?(project, @manager)
  end

  def test_native_tracker_permissions_decide_who_sees_adrs
    @reporter_role.set_permission_trackers(:view_issues, [@bug_tracker.id.to_s])
    @reporter_role.save!

    assert_not CosmosysAdr.adrs_viewable?(@project, User.find(@reporter.id))
    assert_not fresh(@adr).visible?(User.find(@reporter.id))
  end

  def test_native_tracker_permissions_decide_who_creates_adrs
    assert CosmosysAdr.adr_creatable?(@project, @reporter)
    @reporter_role.set_permission_trackers(:add_issues, [@bug_tracker.id.to_s])
    @reporter_role.save!

    assert_not CosmosysAdr.adr_creatable?(@project, User.find(@reporter.id))
  end

  def test_only_administrators_delete
    [@manager, @developer, @reporter].each do |user|
      User.current = user

      assert_not fresh(@adr).destroy, "#{user.login} should not delete an ADR"
    end
    User.current = @admin
    assert fresh(@adr).destroy
  ensure
    User.current = nil
  end
end
