module CosmosysAdr
  # Headings a new ADR starts with. The title, status and date are fields of
  # the ADR, not sections of its text, and the headings stay in English, as in
  # the published Nygard and MADR 4.0.0 templates.
  module Templates
    NYGARD = <<~MARKDOWN.freeze
      ## Context



      ## Decision



      ## Consequences

    MARKDOWN

    MADR = <<~MARKDOWN.freeze
      ## Context and Problem Statement



      ## Decision Drivers

      *

      ## Considered Options

      *

      ## Decision Outcome

      Chosen option: "", because

      ### Consequences

      * Good, because
      * Bad, because

      ### Confirmation



      ## Pros and Cons of the Options

      ###

      * Good, because
      * Neutral, because
      * Bad, because

      ## More Information

    MARKDOWN

    module_function

    def for(format)
      format.to_s == 'madr' ? MADR : NYGARD
    end
  end
end
