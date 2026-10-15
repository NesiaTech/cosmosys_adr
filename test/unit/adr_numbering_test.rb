require File.expand_path('../test_helper', __dir__)

class CosmosysAdrNumberingTest < ActiveSupport::TestCase
  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-numbers')
    @other = create_adr_project('adr-other')
  end

  def test_numbers_are_consecutive_per_project
    first = create_adr(@project)
    second = create_adr(@project)
    elsewhere = create_adr(@other)

    assert_equal 1, first.adr_number
    assert_equal 2, second.adr_number
    assert_equal 1, elsewhere.adr_number
    assert_equal 'ADR-0002', second.cosmosys_adr_label
    assert_equal 2, CosmosysAdr::ProjectSetting.for(@project).last_number
  end

  def test_a_number_cannot_be_given_by_the_user
    issue = Issue.new(project: @project, author: @developer)
    issue.send(:safe_attributes=, { 'tracker_id' => @adr_tracker.id.to_s, 'subject' => 'Mine', 'adr_number' => '42' },
               @developer)
    issue.save!

    assert_equal 1, issue.adr_number
  end

  def test_the_number_never_changes
    issue = fresh(create_adr(@project))
    issue.adr_number = 7

    assert_not issue.save
    assert issue.errors.added?(:adr_number, :cosmosys_adr_immutable)
  end

  def test_the_database_refuses_duplicate_numbers
    first = create_adr(@project)
    second = create_adr(@project)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Issue.where(id: second.id).update_all(adr_number: first.adr_number)
    end
  end

  def test_deleted_numbers_are_not_reused
    create_adr(@project)
    second = create_adr(@project)
    User.current = @admin
    fresh(second).destroy
    User.current = nil
    third = create_adr(@project)

    assert_equal 3, third.adr_number
  end

  def test_only_an_administrator_can_delete_an_adr
    issue = create_adr(@project)
    User.current = @manager

    assert_not fresh(issue).destroy
    assert Issue.exists?(issue.id)
    User.current = @admin

    assert fresh(issue).destroy
  ensure
    User.current = nil
  end

  def test_the_counter_never_goes_back_below_used_numbers
    create_adr(@project)
    create_adr(@project)
    CosmosysAdr::ProjectSetting.for(@project).update_column(:last_number, 0)

    assert_equal 3, create_adr(@project).adr_number
  end
end

# Real concurrency needs separate connections and committed rows, so this
# test runs outside the per-test transaction and cleans up after itself.
class CosmosysAdrConcurrentNumberingTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    setup_cosmosys_adr
    @project = create_adr_project('adr-concurrent')
  end

  def teardown
    User.current = @admin
    Issue.where(project_id: @project.id).destroy_all if @project
    @project&.reload&.destroy
    [@manager, @developer, @reporter].compact.each(&:destroy)
    User.current = nil
  end

  def test_simultaneous_creations_never_share_a_number
    threads = 4
    barrier = Concurrent::CyclicBarrier.new(threads)
    workers = Array.new(threads) do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.wait
          # Each request loads its own project, as the application does.
          create_adr(Project.find(@project.id), subject: "Concurrent #{index}").adr_number
        end
      end
    end
    numbers = ActiveSupport::Dependencies.interlock.permit_concurrent_loads { workers.map(&:value) }

    assert_equal (1..threads).to_a, numbers.sort
    assert_equal threads, CosmosysAdr::ProjectSetting.for(@project).last_number
  end
end
