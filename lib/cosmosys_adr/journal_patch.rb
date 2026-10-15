require_dependency 'journal'

module CosmosysAdr
  # Notes count as mentions: creating or editing a note reindexes its
  # references. Deleting the note deletes its rows through the foreign key.
  module JournalPatch
    def self.included(base)
      base.class_eval do
        after_save :cosmosys_adr_reindex_notes, if: :cosmosys_adr_notes_changed?
      end
    end

    private

    def cosmosys_adr_notes_changed?
      journalized_type == 'Issue' && saved_change_to_notes?
    end

    def cosmosys_adr_reindex_notes
      CosmosysAdr::MentionIndex.reindex_journal(self)
    end
  end
end
