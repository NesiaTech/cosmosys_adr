# cosmosys_adr

Architecture Decision Records for [cosmoSys](https://github.com/cosmoBots/cosmoSys), the engineering information plugin for Redmine.

cosmosys_adr lets a project keep its Architecture Decision Records (ADRs) next to the issues that implement them. Each ADR is a Redmine issue of the `csAdr` tracker, written in the Nygard or the MADR format, numbered `ADR-0001`, `ADR-0002`… within its project, and locked once it is decided: an accepted decision is never edited, it is superseded by a new ADR.

## Status

Version 0.1.0, the first release. While the version is 0.x, a new minor version may change behaviour or data; [`CHANGELOG.md`](CHANGELOG.md) lists every change. This version manages ADRs inside cosmoSys. Keeping ADRs in a git repository (import, sync or export) is planned for a later version.

## Requirements

- Redmine 7.0.1 (Rails 8.1, Ruby 4.0) on PostgreSQL.
- The cosmoSys plugin, version 0.1.7 or later. The plugin declares `requires_redmine_plugin :cosmosys, version_or_higher: '0.1.7'`.

cosmosys_adr adds no gems. It works next to cosmoSys Requirements, cosmoSys PORIS and the Kroki plugins.

## Installation

1. Stop Redmine.
2. Put the plugin in `plugins/cosmosys_adr` of the Redmine root. The directory must be called `cosmosys_adr`.
3. Run the migrations of cosmoSys first, then this plugin's: `RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=cosmosys_adr`.
4. Start Redmine and check that "cosmoSys ADR" appears in Administration › Plugins.

The migration adds the ADR columns to `issues`, two tables (`cosmosys_adr_project_settings` and `cosmosys_adr_mentions`), the `csAdr` tracker and the statuses Proposed, Accepted, Rejected, Deprecated and Superseded. A status that already exists with one of those names is reused. Every non-builtin role gets the workflow Proposed → Accepted, Proposed → Rejected and Accepted → Deprecated; Superseded is set only by the plugin. A role created after the installation has no workflow for `csAdr` until an administrator gives it one in Administration › Workflow.

To roll back, run `rake redmine:plugins:migrate NAME=cosmosys_adr VERSION=0`. It refuses to run while `csAdr` issues exist, so no ADR loses its number by accident. The statuses stay, because other trackers may use them.

## Usage

### Turning ADRs on in a project

Enable the **ADRs** module in the project settings. The project gets the `csAdr` tracker and an **ADRs** tab in its menu. Turning the module off hides the tab and removes the tracker from the project; existing ADRs are kept.

The **ADRs** tab of the project settings chooses:

- the template of new ADRs, Nygard or MADR. Each ADR keeps the format it was created with;
- the roles that may accept, reject and deprecate ADRs. Manager and Developer by default. Roles are stored by id, so renaming or translating a role does not change the setting.

A copy of the project keeps these settings.

Who can see, create and edit ADRs is decided by Redmine's own issue permissions, per tracker.

### Writing and deciding

**New ADR** in the ADRs tab opens the issue form with the `csAdr` tracker. The description starts with the headings of the project template, and the form has the ADR fields: the ADR it supersedes and, for MADR, decision makers, consulted and informed. The number is assigned when the ADR is saved, consecutively within the project, and is never reused, not even after an administrator deletes an ADR.

Every ADR starts in **Proposed** and can be edited while it stays there. The ADR page offers **Accept** and **Reject** to the deciding roles of the project, and **Deprecate** once it is accepted. Accepting or rejecting an ADR sets its decision date, and deprecating or superseding it sets the date it stopped being in force (**In force until**). The plugin sets both dates and nobody can edit them; the date an ADR was proposed is the creation date of its issue. Once an ADR leaves Proposed its title, description, ADR fields, custom fields, attachments, project and tracker are locked; notes stay open. The lock is a model validation, so it applies to the issue form, bulk edit, the REST API (which answers 422), ODS import, snapshot materialisation and project copies.

To change an accepted decision, use **Supersede with a new ADR** on its page. When the new ADR is accepted, the old one becomes **Superseded** in the same transaction, and both histories record it.

Only an administrator can delete an ADR.

### References and links

In any text that cosmoSys renders (issue descriptions and notes, long text fields, wiki pages, the cosmoSys report and its exports):

- `ADR#0007` or `ADR#7` refers to ADR 7 of the current project;
- `ADR#meta#0003` refers to ADR 3 of the project whose Redmine identifier is `meta`;
- `!ADR#0007` is shown as the plain text `ADR#0007`.

A reference shows as a link with the ADR number, title and status. A reference to an ADR that does not exist shows as a broken reference, and one the reader cannot see as a restricted reference, without its title or status: the reader learns only that the ADR exists. References inside code are left alone, and `#123`, `#CSID` and `document:diN` keep working.

An issue can be linked to an ADR explicitly from its **Linked ADRs** panel. The link is a native "related to" relation, so it also shows in the related issues of both, and it may cross projects when Redmine allows relations between projects (Administration › Settings › Issue tracking). A reference in a description, a long text field or a note counts as a link too; it disappears when the text no longer contains it. The ADR page lists every issue that links to or mentions it, with its origin. A mention counts only for users who can see the text it comes from.

## Tests

The tests use Minitest and Redmine's test helper. With the test gems installed and a migrated test database:

```sh
bundle exec rake redmine:plugins:test NAME=cosmosys_adr
```

The test database needs Redmine's default data before the cosmoSys migrations (`rake redmine:load_default_data redmine:plugins:migrate`), as for any cosmoSys instance.

### Continuous integration

`.github/workflows/ci.yml` runs on every pull request and on every push to `main`:

- `sources`: every Ruby file compiles without warnings, and every locale has exactly the keys of `en.yml`, with the Ruby of the deployment's Redmine image.
- `tests`: in the image of a cosmoSys deployment, built from [cosmoSys_deploy](https://github.com/cosmoBots/cosmoSys_deploy) at the commit the workflow pins (`DEPLOY_REVISION`), the test database is migrated as an instance is, this plugin's migrations are rolled back and run again, and the tests run. It runs twice: with cosmoSys alone, and with cosmoSys Requirements and every optional plugin set of the deployment.

The scripts are in `.github/ci` and run on any Docker host with Buildx, from a directory that holds this plugin as `cosmosys_adr` and a cosmoSys_deploy checkout as `deploy`:

```sh
pins=$(cosmosys_adr/.github/ci/deploy-pins.sh deploy requirements all)
env $pins docker buildx bake -f cosmosys_adr/.github/ci/docker-bake.hcl test
env $pins cosmosys_adr/.github/ci/test.sh cosmosys-adr-ci:requirements
```

When the deployment moves its pins, move `DEPLOY_REVISION` in a commit of its own. To try another revision of the deployment first, run the workflow by hand with `deploy-ref`.

## Licence

GNU General Public License version 3; see [`LICENSE`](LICENSE).
