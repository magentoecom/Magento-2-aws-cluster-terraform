


///////////////////////////////////////////////////////[ CLOUDMAP DISCOVERY ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudMap discovery service with private dns namespace
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "${var.brand}.internal"
  description = "Namespace for ${local.project}"
  vpc         = aws_vpc.this.id
  tags = {
    Name = "${local.project}-namespace"
  }
}

resource "aws_service_discovery_service" "this" {
  for_each = {
      for service in setproduct(keys(var.ec2), slice(keys(data.aws_availability_zone.all), 0, 2)) :
        "${service[0]}-${service[1]}" => service 
  }
  name = ${local.project}-${each.key}
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    dns_records {
      type = "A"
      ttl  = 10
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
  force_destroy = true
  tags = {
    Name = "${local.project}-${each.key}-service"
  }
}
