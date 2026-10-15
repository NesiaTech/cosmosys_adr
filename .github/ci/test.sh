#!/bin/sh
set -eu

# Runs the CI tests of this checkout in IMAGE, built from docker-bake.hcl,
# against a throwaway PostgreSQL server. POSTGRES_IMAGE and COSMOSYS_PLUGINS
# come from deploy-pins.sh. The checkout is mounted read-only where Redmine
# loads the plugin, and test-in-image.sh does the rest inside the container.
#
#   env $(cosmosys_adr/.github/ci/deploy-pins.sh deploy base none) \
#     cosmosys_adr/.github/ci/test.sh cosmosys-adr-ci:base

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 IMAGE" >&2
  exit 2
fi
image=$1
: "${POSTGRES_IMAGE:?Set POSTGRES_IMAGE, see deploy-pins.sh}"

plugin_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
name=cosmosys-adr-ci-$$
password=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')

cleanup() {
  docker rm -f "$name-db" >/dev/null 2>&1 || true
  docker network rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM

docker network create "$name" >/dev/null
docker run -d --name "$name-db" --network "$name" --network-alias db \
  --tmpfs /var/lib/postgresql/data \
  -e POSTGRES_USER=redmine -e POSTGRES_PASSWORD="$password" \
  "$POSTGRES_IMAGE" >/dev/null

# Through TCP: while the image initialises the database, its temporary
# server listens only on the Unix socket.
tries=0
until docker exec "$name-db" pg_isready -q -h 127.0.0.1 -U redmine; do
  tries=$((tries + 1))
  if [ "$tries" -ge 60 ]; then
    docker logs "$name-db" >&2
    exit 1
  fi
  sleep 1
done

docker run --rm --network "$name" \
  -e RAILS_ENV=test -e POSTGRES_PASSWORD="$password" \
  -e COSMOSYS_PLUGINS="${COSMOSYS_PLUGINS:-}" \
  -v "$plugin_dir:/usr/src/redmine/plugins/cosmosys_adr:ro" \
  "$image" sh plugins/cosmosys_adr/.github/ci/test-in-image.sh
