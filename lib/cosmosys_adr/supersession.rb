module CosmosysAdr
  # When an ADR that supersedes another one is accepted, the old ADR moves to
  # Superseded in the same transaction. This is the only way into Superseded:
  # the issue validation refuses it unless the move happens inside #call.
  class Supersession
    KEY = :cosmosys_adr_supersession

    def self.active_for?(issue)
      Array(ActiveSupport::IsolatedExecutionState[KEY]).include?(issue.id)
    end

    def self.allowing(issue)
      previous = ActiveSupport::IsolatedExecutionState[KEY]
      ActiveSupport::IsolatedExecutionState[KEY] = Array(previous) + [issue.id]
      yield
    ensure
      ActiveSupport::IsolatedExecutionState[KEY] = previous
    end

    def initialize(adr, user)
      @adr = adr
      @user = user
    end

    def call
      superseded = Issue.lock.find(adr.adr_supersedes_id)
      # Checked again under the row lock: another ADR may have superseded it
      # since this one was validated.
      unless superseded.cosmosys_adr_status_key == :accepted && superseded.project_id == adr.project_id
        adr.errors.add(:adr_supersedes_id, :cosmosys_adr_supersedes_not_accepted)
        raise ActiveRecord::RecordInvalid, adr
      end

      superseded.init_journal(user)
      superseded.current_journal.details << JournalDetail.new(
        property: 'attr', prop_key: 'adr_superseded_by', value: adr.cosmosys_adr_label
      )
      superseded.status = CosmosysAdr.status(:superseded)
      self.class.allowing(superseded) { superseded.save! }
      superseded
    end

    private

    attr_reader :adr, :user
  end
end
