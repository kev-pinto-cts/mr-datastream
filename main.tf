locals {
  force_destroy_default            = false
  deletion_protection_default      = false
  database_dialect_default         = "POSTGRESQL"
  spanner_config                   = var.spanner_config
  labels_default                   = {}
  version_retention_period_default = "1h"

  sql_admins = [
    for k in var.sql_admins :
    "user:${k}"
  ]

  sql_sa = [
    for k in var.sql_sa :
    "serviceAccount:${k}"
  ]


  instances = [
    for instance in local.spanner_config.spanner.instances : {
      name          = "${instance.name}-${var.env}"
      display_name  = try(instance.display_name, "${instance.name}-${var.env}")
      project       = try(local.spanner_config.spanner.project, data.google_project.project.project_id)
      num_nodes     = instance.num_nodes
      config        = instance.config
      force_destroy = try(instance.force_destroy, local.force_destroy_default)
      labels        = try(instance.labels, local.labels_default)
      databases     = try(instance.databases, [])
    }
  ]

  databases = flatten([
    for instance in local.instances : [
      for database in instance.databases : {
        instance                 = instance.name
        name                     = database.name
        database_dialect         = try(database.database_dialect, local.database_dialect_default)
        deletion_protection      = try(database.deletion_protection, local.deletion_protection_default)
        version_retention_period = try(database.version_retention_period, local.version_retention_period_default)
      }
    ]
  ])
}

data "google_project" "project" {}

# Create Spanner Instance
resource "google_spanner_instance" "spanner_instance" {
  for_each = { for instance in local.instances : instance.name => instance }

  project       = each.value.project
  name          = each.value.name
  config        = each.value.config
  display_name  = each.value.display_name
  num_nodes     = each.value.num_nodes
  labels        = each.value.labels
  force_destroy = each.value.force_destroy
}

# Create Spanner Database(s) - (if Configured)
resource "google_spanner_database" "database" {
  for_each                 = { for database in local.databases : database.name => database }
  instance                 = each.value.instance
  name                     = each.value.name
  database_dialect         = each.value.database_dialect
  deletion_protection      = each.value.deletion_protection
  version_retention_period = each.value.version_retention_period
  depends_on               = [google_spanner_instance.spanner_instance]
}

# Set Admin Policy for Instance
data "google_iam_policy" "spanner_instance_admin" {
  binding {
    role    = "roles/spanner.admin"
    members = local.sql_admins
  }
}

resource "google_spanner_instance_iam_policy" "instance" {
  for_each    = { for instance in local.instances : instance.name => instance }
  instance    = each.value.name
  policy_data = data.google_iam_policy.spanner_instance_admin.policy_data
  depends_on = [resource.google_spanner_instance.spanner_instance,
  resource.google_spanner_database.database]
}

# Set SA Policy for Dbs
data "google_iam_policy" "spanner_database_policy" {
  binding {
    role    = "roles/spanner.databaseUser"
    members = local.sql_sa
  }
}

resource "google_spanner_database_iam_policy" "database_policy" {
  for_each    = { for database in local.databases : database.name => database }
  instance    = each.value.instance
  database    = each.value.name
  policy_data = data.google_iam_policy.spanner_database_policy.policy_data
  depends_on = [resource.google_spanner_instance.spanner_instance,
  resource.google_spanner_database.database]
}
