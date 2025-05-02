provider "aws" {
    default_tags {
        tags = module.parameter.tags
    }
}
