#!/bin/sh
set -u

# Prints DEPLOY_IMAGE=REFERENCE when the registry under PREFIX has the image of
# a cosmoSys_deploy checkout for COSMOSYS_VARIANT and COSMOSYS_TOOLS (from
# deploy-pins.sh), and DEPLOY_IMAGE= otherwise. docker-bake.hcl then starts
# the test image from that image instead of building the deployment. The name
# is the one the deployment's scripts/image-tag.sh gives the image, with the
# repository moved from cosmobots/ to PREFIX, so the image holds exactly what
# the deployment would build. Anything else (no such image, no access to it,
# a host that is not linux/amd64) only means building as before.
#
#   .github/ci/deploy-image.sh DEPLOY_DIR PREFIX

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 DEPLOY_DIR PREFIX" >&2
  exit 2
fi
deploy_dir=$1
prefix=$2
: "${COSMOSYS_VARIANT:?Set COSMOSYS_VARIANT, see deploy-pins.sh}"

reference=
if [ "$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}' 2>/dev/null)" != linux/amd64 ]; then
  echo "Only linux/amd64 images are published; building the deployment" >&2
elif ! name=$("$deploy_dir/scripts/image-tag.sh" "$COSMOSYS_VARIANT" "${COSMOSYS_TOOLS:-}"); then
  echo "The deployment does not name its image; building it" >&2
else
  case "$name" in
    cosmobots/*)
      candidate=$prefix/${name#cosmobots/}
      if docker buildx imagetools inspect "$candidate" >/dev/null 2>&1; then
        echo "Starting from $candidate" >&2
        reference=$candidate
      else
        echo "$candidate is not available; building the deployment" >&2
      fi
      ;;
    *)
      echo "Unexpected image name $name; building the deployment" >&2
      ;;
  esac
fi
printf 'DEPLOY_IMAGE=%s\n' "$reference"
