require File.expand_path('../test_helper', __dir__)

class CosmosysAdrApiTest < Redmine::ApiTest::Base
  def setup
    super
    setup_cosmosys_adr
    @password = CosmosysAdr::TestHelper::PASSWORD
    Setting.rest_api_enabled = '1'
    @project = create_adr_project('adr-api')
    @adr = accepted_adr(@project, subject: 'Use PostgreSQL')
    @proposed = create_adr(@project, subject: 'Use Redis')
  end

  def test_editing_an_accepted_adr_answers_422
    put "/issues/#{@adr.id}.json", params: { issue: { subject: 'Use SQLite after all' } },
                                   headers: credentials(@manager.login, @password)

    assert_response 422
    assert_includes response.parsed_body['errors'], I18n.t(:error_cosmosys_adr_locked, label: 'ADR-0001')
    assert_equal 'Use PostgreSQL', fresh(@adr).subject
  end

  def test_notes_on_an_accepted_adr_are_accepted
    put "/issues/#{@adr.id}.json", params: { issue: { notes: 'Still valid.' } }, headers: credentials(@manager.login, @password)

    assert_response :no_content
  end

  def test_the_api_does_not_take_the_dates
    put "/issues/#{@proposed.id}.json", params: { issue: { adr_date: '2020-01-01', adr_in_force_until: '2020-02-02' } },
                                        headers: credentials(@developer.login, @password)

    assert_response :no_content
    assert_nil fresh(@proposed).adr_date
    assert_nil fresh(@proposed).adr_in_force_until
  end

  def test_a_proposed_adr_can_be_edited
    put "/issues/#{@proposed.id}.json", params: { issue: { subject: 'Use Redis 8' } }, headers: credentials(@developer.login, @password)

    assert_response :no_content
    assert_equal 'Use Redis 8', fresh(@proposed).subject
  end

  def test_a_reporter_cannot_accept_through_the_api
    put "/issues/#{@proposed.id}.json", params: { issue: { status_id: adr_status(:accepted).id } },
                                        headers: credentials(@reporter.login, @password)

    assert_response 422
    assert_equal :proposed, fresh(@proposed).cosmosys_adr_status_key
  end

  def test_a_developer_accepts_through_the_api
    put "/issues/#{@proposed.id}.json", params: { issue: { status_id: adr_status(:accepted).id } },
                                        headers: credentials(@developer.login, @password)

    assert_response :no_content
    assert_equal :accepted, fresh(@proposed).cosmosys_adr_status_key
  end

  def test_the_api_shows_adr_numbers_through_creation
    post '/issues.json', params: { issue: { project_id: @project.id, tracker_id: @adr_tracker.id, subject: 'Via API' } },
                         headers: credentials(@developer.login, @password)

    assert_response :created
    assert_equal 3, Issue.find(response.parsed_body['issue']['id']).adr_number
  end
end
