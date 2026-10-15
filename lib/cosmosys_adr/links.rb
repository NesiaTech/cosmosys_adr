require 'set'

module CosmosysAdr
  # What links issues and ADRs, seen from either side: explicit links (native
  # "relates to" relations) and mentions (cosmosys_adr_mentions). Everything
  # returned is filtered by what the user can see.
  module Links
    Entry = Struct.new(:issue, :origin, :relation, keyword_init: true) do
      def explicit?
        origin == :link
      end
    end

    module_function

    # Issues linked to or mentioning an ADR.
    def for_adr(adr, user)
      entries = {}
      relations_of([adr.id]).each do |relation|
        other = relation.other_issue(adr)
        next unless other&.visible?(user)

        entries[other.id] = Entry.new(issue: other, origin: :link, relation: relation)
      end
      CosmosysAdr::Mention.for_adr(adr).includes(issue: %i[project status tracker], journal: []).each do |mention|
        next if mention.issue_id == adr.id || entries.key?(mention.issue_id) || !mention.visible?(user)

        entries[mention.issue_id] = Entry.new(issue: mention.issue, origin: :mention)
      end
      entries.values.sort_by { |entry| [entry.issue.project.name.to_s, entry.issue.id] }
    end

    # ADRs linked to or mentioned by an issue.
    def for_issue(issue, user)
      entries = {}
      relations_of([issue.id]).each do |relation|
        other = relation.other_issue(issue)
        next unless other&.cosmosys_adr? && other.visible?(user)

        entries[other.id] = Entry.new(issue: other, origin: :link, relation: relation)
      end
      issue_mentions(issue).each do |mention|
        next unless mention.visible?(user)

        adr = mention.adr
        next if adr.nil? || adr.id == issue.id || entries.key?(adr.id) || !adr.cosmosys_adr? || !adr.visible?(user)

        entries[adr.id] = Entry.new(issue: adr, origin: :mention)
      end
      entries.values.sort_by { |entry| [entry.issue.project.name.to_s, entry.issue.adr_number.to_i] }
    end

    # Number of visible issues linked to or mentioning each ADR of a list.
    def counts(adrs, user)
      return {} if adrs.empty?

      linked = Hash.new { |hash, key| hash[key] = Set.new }
      ids = adrs.map(&:id)
      relations_of(ids).each do |relation|
        if ids.include?(relation.issue_from_id)
          linked[relation.issue_from_id] << relation.issue_to_id
        end
        linked[relation.issue_to_id] << relation.issue_from_id if ids.include?(relation.issue_to_id)
      end
      # Only mentions the user may see count, as in the lists of for_adr.
      by_target = adrs.index_by { |adr| [adr.project_id, adr.adr_number] }
      CosmosysAdr::Mention.where(target_project_id: adrs.map(&:project_id).uniq, target_number: adrs.map(&:adr_number))
                          .includes(:journal, issue: :project).each do |mention|
        adr = by_target[[mention.target_project_id, mention.target_number]]
        linked[adr.id] << mention.issue_id if adr && adr.id != mention.issue_id && mention.visible?(user)
      end
      visible = Issue.visible(user).where(id: linked.values.flat_map(&:to_a).uniq).pluck(:id).to_set
      adrs.to_h { |adr| [adr.id, (linked[adr.id] & visible).size] }
    end

    def relations_of(issue_ids)
      IssueRelation.where(relation_type: IssueRelation::TYPE_RELATES)
                   .where('issue_from_id IN (:ids) OR issue_to_id IN (:ids)', ids: issue_ids)
                   .includes(issue_from: %i[project status tracker], issue_to: %i[project status tracker])
    end

    def issue_mentions(issue)
      CosmosysAdr::Mention.where(issue_id: issue.id).includes(:journal).to_a
    end

    # ADRs the user may link from an issue of project, grouped by project:
    # only those of the same project when Redmine does not allow relations
    # between projects.
    def linkable_adrs(user, project, limit: 500)
      tracker = CosmosysAdr.tracker
      return {} unless tracker

      scope = Issue.visible(user).where(tracker_id: tracker.id).where.not(adr_number: nil)
      scope = scope.where(project_id: project.id) unless Setting.cross_project_issue_relations?
      scope.includes(:project, :status).order(:project_id, :adr_number).limit(limit).to_a.group_by(&:project)
    end
  end
end
