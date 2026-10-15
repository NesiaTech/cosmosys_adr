require_dependency 'issue'

module CosmosysAdr
  # Overrides of Issue methods for ADRs. Prepended, so they wrap Redmine's and
  # cosmoSys' versions of the same methods.
  module IssueWorkflowPatch
    # The statuses offered in the form, the context menu and bulk edit: a
    # new ADR starts in Proposed, decisions are offered only to the roles the
    # project allows, and Superseded is never offered.
    def new_statuses_allowed_to(user = User.current, include_default = false)
      statuses = super
      return statuses unless cosmosys_adr?

      proposed = CosmosysAdr.status(:proposed)
      return [proposed].compact if new_record?

      current = CosmosysAdr.status_key(status_id_was)
      decider = CosmosysAdr.decider?(user, project)
      targets = CosmosysAdr::DECISION_TRANSITIONS.fetch(current, [])
      statuses.select do |candidate|
        key = CosmosysAdr.status_key(candidate)
        candidate.id == status_id_was || (decider && targets.include?(key))
      end
    end

    def safe_attributes=(attrs, user = User.current)
      requested_status_id = cosmosys_adr_requested_status_id(attrs)
      super
      return unless cosmosys_adr?

      if new_record?
        cosmosys_adr_apply_new_record_defaults(apply_template: true)
      elsif requested_status_id && requested_status_id != status_id_in_database && requested_status_id != status_id
        @cosmosys_adr_requested_status_key = CosmosysAdr.status_key(requested_status_id) || :unknown
      end
    end

    def copy_from(arg, options = {})
      super.tap do
        next unless cosmosys_adr?

        # A copy of an ADR is a new proposal: new number, no supersession and
        # no decision yet.
        self.adr_number = nil
        self.adr_supersedes_id = nil
        self.adr_source = nil
        self.adr_date = nil
        self.adr_in_force_until = nil
        @cosmosys_adr_restore = false
      end
    end

    # Attachments are part of what a decided ADR says.
    def attachments_addable?(user = User.current)
      return false if cosmosys_adr_locked?

      super
    end

    def attachments_editable?(user = User.current)
      return false if cosmosys_adr_locked?

      super
    end

    def attachments_deletable?(user = User.current)
      return false if cosmosys_adr_locked?

      super
    end

    private

    def cosmosys_adr_requested_status_id(attrs)
      return nil if new_record? || !attrs.respond_to?(:[])

      value = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h['status_id'] : (attrs['status_id'] || attrs[:status_id])
      value.present? ? value.to_i : nil
    end
  end
end
