data "aws_regions" "regions" {
  all_regions = true

  filter {
    name   = "opt-in-status"
    values = [
      "opt-in-not-required",
      "opted-in"
    ]
  }
}

locals {
  regions = {
    for name, region in data.aws_regions.regions.names : (name) => name
  }
}

resource "aws_vpc_ipam" "ipam" {
  count = 0

  dynamic "operating_regions" {
    for_each = local.regions

    content {
      region_name = operating_regions.value
    }
  }

  tags = {
    Name = "IPAM"
  }
}
