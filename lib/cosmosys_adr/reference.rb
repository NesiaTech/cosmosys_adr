module CosmosysAdr
  # The inline reference syntax:
  #
  #   ADR#0007          ADR 7 of the project the text belongs to
  #   ADR#7             the same ADR; numbers are normalised to four digits
  #   ADR#meta#0003     ADR 3 of the project whose Redmine identifier is meta
  #   !ADR#0007         escaped, shown as typed
  #
  # A reference never starts in the middle of a word, a URL or an entity, so
  # `XADR#1`, `/ADR#1` and `&ADR#1` are plain text.
  module Reference
    PATTERN = /(?<![A-Za-z0-9_\-#&!\/])(?<escape>!?)ADR#(?:(?<project>[A-Za-z0-9_\-]+)#)?(?<number>[0-9]{1,9})(?![A-Za-z0-9_])/

    Match = Struct.new(:project_identifier, :number, :raw, keyword_init: true) do
      def cross_project?
        project_identifier.present?
      end
    end

    module_function

    def parse(match_data)
      Match.new(
        project_identifier: match_data[:project]&.downcase,
        number: match_data[:number].to_i,
        raw: match_data[0].delete_prefix('!')
      )
    end

    def escaped?(match_data)
      match_data[:escape] == '!'
    end

    # Every reference of a plain text, escaped ones left out.
    def scan(text)
      matches = []
      text.to_s.scan(PATTERN) do
        match_data = Regexp.last_match
        matches << parse(match_data) unless escaped?(match_data)
      end
      matches
    end

    # The project a reference points to, seen from the project of the text.
    def target_project(match, current_project)
      return current_project unless match.cross_project?

      Project.find_by(identifier: match.project_identifier)
    end
  end
end
