locals {
  spanner_config = yamldecode(file("../spanner_config/spanner.yaml"))
}

module "mr-spanner" {
  source         = "../"
  env            = "dev"
  spanner_config = try(local.spanner_config, {})
  sql_admins     = ["kev.pinto@nwmworld.com", "simon.darlington@nwmworld.com"]
  sql_sa         = ["305379539480-compute@developer.gserviceaccount.com"]
}
