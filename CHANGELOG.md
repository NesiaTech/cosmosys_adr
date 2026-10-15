# Changelog

All notable changes to cosmosys_adr are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-15

### Added

- Architecture Decision Records as issues of the `csAdr` tracker, numbered `ADR-0001`, `ADR-0002`… within each project. A number is never reused.
- The Nygard and MADR 4.0.0 templates, chosen per project. Each ADR keeps the format it was created with.
- The lifecycle Proposed, Accepted, Rejected, Deprecated and Superseded. The roles that decide are set per project, Manager and Developer by default, and the administrator decides too.
- The decision date, set when an ADR is accepted or rejected, and the In force until date, set when it is deprecated or superseded.
- The content lock of decided ADRs. It is a model validation, so it holds for the issue form, bulk edit, the REST API (which answers 422), ODS import, snapshots and project copies.
- Superseding an accepted ADR with a new one. When the new ADR is accepted, the old one becomes Superseded and both histories record it.
- The ADRs tab of a project, with filters and the rendered content, and the ADRs tab of the project settings. A copy of a project keeps its ADR settings.
- `ADR#N`, `ADR#project#N` and `!ADR#N` references in every text cosmoSys renders, with broken and restricted references marked as such.
- Linked ADRs: explicit links as native related-to relations, and mentions in descriptions, long text fields and notes.
- English and Spanish translations.
- Continuous integration: Ruby syntax and locale keys, the migrations rolled back and forward, and the tests with cosmoSys alone and with cosmoSys Requirements and every optional plugin set of cosmoSys_deploy.

[Unreleased]: https://github.com/NesiaTech/cosmosys_adr/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/NesiaTech/cosmosys_adr/releases/tag/v0.1.0
