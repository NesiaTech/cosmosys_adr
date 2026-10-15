require File.expand_path('../test_helper', __dir__)

# References go through Redmine's own textilizable, with cosmoSys' patch of
# parse_redmine_links in front, exactly as issue pages, wiki pages, reports
# and exports render them.
class CosmosysAdrReferenceTest < Redmine::HelperTest
  include ApplicationHelper
  include CosmosysAdr::TestHelper

  def setup
    super
    setup_cosmosys_adr
    @project = create_adr_project('shop')
    @meta = create_adr_project('meta')
    @first = accepted_adr(@project, subject: 'Record architecture decisions')
    @second = create_adr(@project, subject: 'Store sessions in PostgreSQL')
    @cross = accepted_adr(@meta, subject: 'Shared database for every service')
    @bug = create_bug(@project, subject: 'Write the migration')
    User.current = @developer
  end

  def teardown
    User.current = nil
  end

  def render(text, project: @project)
    textilizable(text, project: project)
  end

  def test_a_reference_in_the_current_project_shows_number_title_and_status
    html = render('See ADR#0001.')

    assert_select_in html, "a.cosmosys-adr-ref[href='/issues/#{@first.id}']", text: 'ADR-0001 Record architecture decisions'
    assert_select_in html, 'span.cosmosys-adr-pill-accepted', text: 'Accepted'
    assert_select_in html, "a.cosmosys-adr-ref[title*='Record architecture decisions']"
  end

  def test_numbers_are_normalised
    html = render('ADR#1 and ADR#002')

    assert_select_in html, "a.cosmosys-adr-ref[href='/issues/#{@first.id}']"
    assert_select_in html, "a.cosmosys-adr-ref[href='/issues/#{@second.id}']", text: 'ADR-0002 Store sessions in PostgreSQL'
    assert_select_in html, 'span.cosmosys-adr-pill-proposed', text: 'Proposed'
  end

  def test_a_reference_to_another_project_uses_its_identifier
    html = render('Follows ADR#meta#0001.')

    assert_select_in html, "a.cosmosys-adr-ref[href='/issues/#{@cross.id}']", text: 'ADR-0001 Shared database for every service'
    assert_select_in html, 'span.cosmosys-adr-ref-project', text: /Meta/
  end

  # assert_select_in unescapes the HTML before parsing it, so labels such as
  # "<broken reference>" are checked on the raw HTML instead.
  def test_a_missing_adr_is_a_broken_reference
    %w[ADR#0099 ADR#nowhere#0001 ADR#meta#0042].each do |reference|
      html = render("See #{reference}.")

      assert_select_in html, "span.cosmosys-broken-reference[title='#{reference}']"
      assert_includes html, ERB::Util.html_escape(I18n.t(:label_cosmosys_broken_reference))
      assert_select_in html, 'a.cosmosys-adr-ref', count: 0
    end
  end

  def test_an_adr_the_user_cannot_see_is_restricted_without_its_title
    secret = create_adr_project('secret')
    hidden = create_adr(secret, subject: 'Confidential vendor choice')
    User.current = User.generate!

    html = render('ADR#secret#0001')

    assert_select_in html, 'span.cosmosys-adr-restricted'
    assert_includes html, ERB::Util.html_escape(I18n.t(:label_cosmosys_adr_restricted_reference, label: 'ADR-0001'))
    assert_not_includes html, hidden.subject
  end

  def test_code_is_left_alone
    html = render("Inline `ADR#0001` and a block:\n\n```\nADR#0001\n```\n\n    ADR#0001\n")

    assert_select_in html, 'a.cosmosys-adr-ref', count: 0
    assert_select_in html, 'code', text: 'ADR#0001'
  end

  def test_escaped_and_embedded_forms_are_plain_text
    html = render('!ADR#0001 XADR#0001 http://example.org/ADR#0001 [label ADR#0001](http://example.org)')

    assert_select_in html, 'a.cosmosys-adr-ref', count: 0
    assert_includes html, 'ADR#0001'
  end

  def test_native_and_cosmosys_references_still_work
    html = render("ADR#0001 next to ##{@bug.id}, ##{@bug.csid} and document:di999999")

    assert_select_in html, "a.cosmosys-adr-ref[href='/issues/#{@first.id}']"
    assert_select_in html, "a.issue[href='/issues/#{@bug.id}']", text: "##{@bug.id}"
    assert_select_in html, "a[href='/issues/#{@bug.id}']", text: "##{@bug.csid}"
    assert_select_in html, 'span.cosmosys-broken-reference'
  end

  def test_an_adr_number_is_not_a_redmine_issue_or_csid_reference
    html = render('ADR#0001')

    assert_select_in html, 'a', count: 1
    assert_select_in html, 'a.cosmosys-adr-ref', count: 1
  end

  def test_titles_with_references_are_not_linked_twice
    tricky = create_adr(@project, subject: "Depends on ##{@bug.id} and ##{@bug.csid}")
    html = render("ADR##{tricky.adr_number}")

    assert_select_in html, 'a', count: 1
    assert_select_in html, "a.cosmosys-adr-ref[href='/issues/#{tricky.id}']"
  end

  def test_retired_adrs_are_struck_through
    transition!(@first, :deprecated)
    User.current = @developer
    html = render('ADR#0001')

    assert_select_in html, 'a.cosmosys-adr-ref.cosmosys-adr-ref-retired'
    assert_select_in html, 'span.cosmosys-adr-pill-deprecated'
  end

  def test_references_resolve_in_wiki_pages_and_long_text_fields
    wiki = Wiki.create!(project: @project, start_page: 'Wiki')
    page = WikiPage.new(wiki: wiki, title: 'Decisions')
    page.content = WikiContent.new(text: 'We follow ADR#0001.', author: @developer)
    page.save!
    field = IssueCustomField.create!(name: 'Notes', field_format: 'text', text_formatting: 'full', is_for_all: true,
                                     trackers: [@bug_tracker])
    @bug = fresh(@bug)
    @bug.custom_field_values = { field.id.to_s => 'Also ADR#meta#0001' }
    @bug.save!

    assert_select_in textilizable(page.content, :text, project: @project), 'a.cosmosys-adr-ref'
    value = @bug.reload.custom_field_value(field)
    assert_select_in textilizable(value, project: @project, object: @bug), "a[href='/issues/#{@cross.id}']"
  end
end
