require 'date'
require_dependency File.expand_path('../../../cosmosys/lib/cosmosys/ods_item_field_registry', __dir__)

module CosmosysAdr
  # ADR fields in cosmoSys' item field registry, which ODS export and import,
  # snapshots and project copies read and write. A new ADR written through it
  # asks to keep its number; the issue decides whether it may (see
  # Issue#cosmosys_adr_restore!). Writes to an existing ADR go through the
  # usual validations, so they cannot change a decided one.
  module OdsFields
    SCALAR_FIELDS = %w[adr_decision_makers adr_consulted adr_informed].freeze

    module_function

    def register!
      register('adr_number', writer: lambda do |issue, value|
        next unless issue.cosmosys_adr?

        if issue.new_record?
          issue.cosmosys_adr_restore!(value)
        elsif value.present? && value.to_i != issue.adr_number
          issue.adr_number = value.to_i
        end
      end)

      %w[adr_format adr_source].each do |name|
        register(name, writer: lambda do |issue, value|
          issue.public_send("#{name}=", value.to_s.strip.presence) if issue.cosmosys_adr? && value.present?
        end)
      end

      %w[adr_date adr_in_force_until].each do |name|
        register(name, writer: lambda do |issue, value|
          issue.public_send("#{name}=", parse_date(value)) if issue.cosmosys_adr?
        end)
      end

      SCALAR_FIELDS.each do |name|
        register(name, writer: ->(issue, value) { issue.public_send("#{name}=", value.presence) if issue.cosmosys_adr? })
      end

      register(
        'adr_supersedes',
        reader: ->(issue) { issue.cosmosys_adr? ? issue.adr_supersedes&.csid : nil },
        deferred: true,
        remapper: ->(value, context) { context.fetch(:csid_map, {}).fetch(value.to_s, value) },
        writer: lambda do |issue, value|
          next unless issue.cosmosys_adr?

          issue.adr_supersedes = value.to_s.strip.empty? ? nil : issue.project.issues.find_by!(csid: value.to_s.strip)
        end
      )
    end

    def register(name, reader: nil, writer:, **options)
      return if Cosmosys::OdsItemFieldRegistry.names.include?(name)

      reader ||= ->(issue) { issue.cosmosys_adr? ? issue.public_send(name) : nil }
      Cosmosys::OdsItemFieldRegistry.register(name, reader: reader, writer: writer, **options)
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
  end
end

CosmosysAdr::OdsFields.register!
