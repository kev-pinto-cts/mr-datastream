locals {
  spanner_config = yamldecode(file("../spanner_config/spanner.yaml"))
}

module "mr-spanner" {
  source         = "../"
  env            = "dev"
  spanner_config = try(local.spanner_config, {})
  sql_admins     = ["kev.pinto@cts.co", "simon.darlington@cts.co"]
  sql_sa         = ["305379539480-compute@developer.gserviceaccount.com"]
}

output "spanner_db_id" {
  value = [
    for k, v in module.mr-spanner :
    {
      "id" : v
    }
  ]
}
