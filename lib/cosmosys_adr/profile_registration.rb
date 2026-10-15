require_dependency File.expand_path('../../../cosmosys/lib/cosmosys/item_kind_registry', __dir__)

module CosmosysAdr
  module ProfileRegistration
    module_function

    # ADRs live outside the cosmoSys tree, report, chapters and diagrams in
    # v1. Only an administrator may delete one, like a requirement.
    def register!
      if Cosmosys::ItemKindRegistry.registered?(CosmosysAdr::ITEM_KIND)
        profile = Cosmosys::ItemKindRegistry.fetch(CosmosysAdr::ITEM_KIND)
        raise 'item profile adr belongs to another provider' unless profile.provider == :cosmosys_adr

        return profile
      end

      Cosmosys::ItemKindRegistry.register(
        CosmosysAdr::ITEM_KIND,
        label: :label_cosmosys_adr_item_profile,
        description: :text_cosmosys_adr_item_profile,
        provider: :cosmosys_adr,
        diagram_shape: 'note',
        reference_mode: 'csid',
        dependency_rankdir: 'TB',
        diagram_visible: false,
        report_diagrams: false,
        report_metadata: false,
        can_have_children: false,
        can_split: false,
        aggregate_children: false,
        dsm_mode: 'none',
        tree_visible: false,
        report_visible: false,
        chapter_numbered: false,
        physical_delete_policy: 'admin_only'
      )
    end
  end
end

CosmosysAdr::ProfileRegistration.register!
