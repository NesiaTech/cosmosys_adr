# Builds the image the CI tests run in: the image of a cosmoSys deployment,
# from a checkout of cosmoSys_deploy, plus Redmine's test gems (Dockerfile in
# this directory). The variables come from deploy-pins.sh through the
# environment. Run it from the directory that holds both checkouts:
#
#   env $(cosmosys_adr/.github/ci/deploy-pins.sh deploy base none) \
#     docker buildx bake -f cosmosys_adr/.github/ci/docker-bake.hcl test

variable "DEPLOY_DIR" {
  default = "deploy"
}

variable "CI_DIR" {
  default = "cosmosys_adr/.github/ci"
}

variable "CI_IMAGE" {
  default = "cosmosys-adr-ci"
}

variable "REDMINE_IMAGE" {}
variable "COSMOSYS_REVISION" {}
variable "COSMOSYS_REQ_REVISION" {}
variable "RSPREADSHEET_REVISION" {}

variable "COSMOSYS_VARIANT" {
  default = "base"
}

variable "COSMOSYS_TOOLS" {
  default = ""
}

# The deployment image, exactly as cosmoSys_deploy builds it for an instance.
# It is only a step towards the test image, so it is not exported.
target "cosmosys" {
  context = DEPLOY_DIR
  target  = "cosmosys"
  args = {
    REDMINE_IMAGE         = REDMINE_IMAGE
    COSMOSYS_REVISION     = COSMOSYS_REVISION
    COSMOSYS_REQ_REVISION = COSMOSYS_REQ_REVISION
    RSPREADSHEET_REVISION = RSPREADSHEET_REVISION
    COSMOSYS_VARIANT      = COSMOSYS_VARIANT
    COSMOSYS_TOOLS        = COSMOSYS_TOOLS
  }
}

target "test" {
  context  = CI_DIR
  contexts = {
    cosmosys = "target:cosmosys"
  }
  tags   = ["${CI_IMAGE}:${COSMOSYS_VARIANT}"]
  output = ["type=docker"]
}
