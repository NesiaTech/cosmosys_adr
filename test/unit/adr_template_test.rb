require File.expand_path('../test_helper', __dir__)

class CosmosysAdrTemplateTest < ActiveSupport::TestCase
  def setup
    setup_cosmosys_adr
    @nygard = create_adr_project('adr-nygard', template: 'nygard')
    @madr = create_adr_project('adr-madr', template: 'madr')
  end

  def form_issue(project, attributes = {})
    issue = Issue.new(project: project, author: @developer)
    issue.send(:safe_attributes=, { 'tracker_id' => @adr_tracker.id.to_s, 'subject' => 'Decide' }.merge(attributes), @developer)
    issue
  end

  def test_the_description_starts_with_the_project_template
    nygard = form_issue(@nygard)
    madr = form_issue(@madr)

    # Redmine stores descriptions with CRLF line endings.
    assert_equal CosmosysAdr::Templates::NYGARD.gsub("\n", "\r\n"), nygard.description
    assert_includes nygard.description, '## Consequences'
    assert_equal CosmosysAdr::Templates::MADR.gsub("\n", "\r\n"), madr.description
    assert_includes madr.description, '## Decision Drivers'
  end

  def test_a_written_description_is_kept
    assert_equal 'My own text', form_issue(@nygard, 'description' => 'My own text').description
  end

  def test_the_format_is_stored_in_each_adr
    assert_equal 'nygard', create_adr(@nygard).adr_format
    assert_equal 'madr', create_adr(@madr).adr_format
  end

  def test_changing_the_template_does_not_change_existing_adrs
    existing = create_adr(@nygard)
    CosmosysAdr::ProjectSetting.for(@nygard).update!(template: 'madr')

    assert_equal 'nygard', existing.reload.adr_format
    assert_equal 'madr', create_adr(@nygard).adr_format
  end

  def test_madr_people_fields_are_only_for_madr
    nygard = form_issue(@nygard, 'adr_decision_makers' => 'team')
    madr = form_issue(@madr, 'adr_decision_makers' => 'team', 'adr_consulted' => 'ops', 'adr_informed' => 'all')

    assert_nil nygard.adr_decision_makers
    assert_equal %w[team ops all], [madr.adr_decision_makers, madr.adr_consulted, madr.adr_informed]
  end

  def test_projects_without_settings_use_nygard
    project = create_adr_project('adr-default')
    CosmosysAdr::ProjectSetting.where(project_id: project.id).delete_all

    assert_equal 'nygard', create_adr(project).adr_format
  end
end
