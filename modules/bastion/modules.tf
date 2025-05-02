################################################################################
# Module(s)
################################################################################

module "parameter" {
    source = "github.com/iac-factory/terraform-local-parameter"

    namespace   = var.namespace
    environment = var.environment
    application = var.application
    service     = var.service
}
