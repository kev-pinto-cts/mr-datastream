module "mr-spanner" {
  source         = "../"
  project_id     = "cloudsqlpoc-demo"
  env            = "dev"
  spanner_config = try(yamldecode(file("../spanner_config/spanner.yaml")), {})
  sql_admins     = ["kev.pinto@nwmworld.com", "simon.darlington@nwmworld.com"]
  sql_sa         = ["305379539480-compute@developer.gserviceaccount.com"]
}
