#!/bin/sh
set -eu

# Prints, as KEY=VALUE lines, what the CI image is built and run with: the
# pins of a cosmoSys_deploy checkout (Redmine and PostgreSQL images, cosmoSys,
# cosmoSys Requirements and rspreadsheet revisions), its variant and its
# optional plugin sets. The tests thus run on what a real instance runs, and
# the deployment stays the only place where those pins are kept.
#
#   .github/ci/deploy-pins.sh DEPLOY_DIR base|requirements none|all
#
# "all" activates every optional plugin set of the deployment catalog, with
# every tool group they need. No value contains spaces, so the output can go
# to $GITHUB_ENV as it is or before a command through env.

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 DEPLOY_DIR base|requirements none|all" >&2
  exit 2
fi
deploy_dir=$1
variant=$2
plugin_sets=$3

value() {
  value=$(sed -n "s/^$2=//p" "$deploy_dir/$1")
  if [ -z "$value" ]; then
    echo "$deploy_dir/$1 sets no $2" >&2
    exit 1
  fi
  printf '%s\n' "$value"
}

for key in REDMINE_IMAGE POSTGRES_IMAGE COSMOSYS_REVISION COSMOSYS_REQ_REVISION RSPREADSHEET_REVISION; do
  printf '%s=%s\n' "$key" "$(value .env.example "$key")"
done

case "$variant" in
  base|requirements) printf 'COSMOSYS_VARIANT=%s\n' "$variant" ;;
  *)
    echo "Unknown variant $variant" >&2
    exit 2
    ;;
esac

case "$plugin_sets" in
  none)
    printf 'COSMOSYS_PLUGINS=\nCOSMOSYS_TOOLS=\n'
    ;;
  all)
    printf 'COSMOSYS_PLUGINS=%s\n' "$(value plugins.conf COSMOSYS_OPTIONS | tr ' ' ',')"
    printf 'COSMOSYS_TOOLS=%s\n' "$(value plugins.conf COSMOSYS_TOOL_GROUPS | tr ' ' ',')"
    ;;
  *)
    echo "Unknown plugin sets $plugin_sets" >&2
    exit 2
    ;;
esac
