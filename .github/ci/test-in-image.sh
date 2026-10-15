#!/bin/sh
set -eu

# Runs inside the CI test image, from the Redmine directory, after the
# cosmoSys entrypoint has activated the optional plugins of COSMOSYS_PLUGINS.
# It migrates the test database the way a deployment migrates an instance,
# rolls this plugin's migrations back and forward again on that clean
# database, and runs this plugin's tests.

state() {
  bundle exec rails runner plugins/cosmosys_adr/.github/ci/migration_state.rb | sed -n 's/^STATE //p'
}

echo '== Test database'
bundle exec rake db:create db:migrate
bundle exec rake redmine:load_default_data redmine:plugins:migrate REDMINE_LANG=en
installed=$(state)

echo '== Migrations rolled back and forward'
bundle exec rake redmine:plugins:migrate NAME=cosmosys_adr VERSION=0
removed=$(state)
bundle exec rake redmine:plugins:migrate NAME=cosmosys_adr
reinstalled=$(state)

printf 'installed:   %s\nremoved:     %s\nreinstalled: %s\n' "$installed" "$removed" "$reinstalled"
nothing='tracker=0 columns=[] indexes=[] tables=[] workflows=0 settings=0 migrations=[]'
if [ -z "$installed" ] || [ "$removed" != "$nothing" ] || [ "$reinstalled" != "$installed" ]; then
  echo 'The rollback left something behind, or the migration did not restore the same state' >&2
  exit 1
fi

echo '== Tests'
bundle exec rake redmine:plugins:test NAME=cosmosys_adr
