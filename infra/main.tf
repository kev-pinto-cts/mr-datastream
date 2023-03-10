locals {
  # Change these vars
  project_id           = "cloudsqlpoc-xxxx"
  primary_region       = "europe-west2"
  dr_region            = "europe-west1"
  primary_reserved_ips = "10.124.0.0/29"
  dr_reserved_ips      = "10.126.0.0/29"
  sql_users            = ["kev.pinto@xxx.co"]

  # Do not change these
  username = "postgres"
  db       = "demodb"
  port     = 5432
  schema   = "data_schema"
  google_services = [
    "iap.googleapis.com",
    "datastream.googleapis.com",
    "bigquery.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com"
  ]

  iam = {
    "roles/cloudsql.admin" = concat(
      formatlist("user:%s", local.sql_users),
      formatlist("serviceAccount:%s", google_service_account.datastream_sa.email)
    )
    "roles/cloudsql.client" = concat(
      formatlist("user:%s", local.sql_users),
      formatlist("serviceAccount:%s", google_service_account.datastream_sa.email)
    )
    "roles/cloudsql.instanceUser" = concat(
      formatlist("user:%s", local.sql_users),
      formatlist("serviceAccount:%s", google_service_account.datastream_sa.email)
    )
  }

  kms_key_members = [
    "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}"
  ]
}


data "google_project" "project" {
}


resource "google_project_service" "service" {
  for_each           = toset(local.google_services)
  project            = local.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  provider   = google-beta
  project    = local.project_id
  service    = "sqladmin.googleapis.com"
  depends_on = [google_project_service.service]
}

data "google_compute_network" "my-network" {
  name    = "default"
  project = local.project_id
}


data "google_compute_subnetwork" "my-subnetwork" {
  name    = data.google_compute_network.my-network.name
  project = data.google_compute_network.my-network.project
  region  = local.primary_region
}

resource "google_service_account" "datastream_sa" {
  account_id = "datastream-sa"
}

# IAM user config
resource "google_project_iam_binding" "authoritative" {
  for_each = local.iam
  project  = local.project_id
  role     = each.key
  members  = each.value
  depends_on = [
    google_service_account.datastream_sa,
    google_project_service.service
  ]
}

resource "google_compute_firewall" "sqlproxy" {
  name = "sqlproxy"
  allow {
    ports    = ["22", "5432"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = data.google_compute_network.my-network.id
  priority      = 1000
  source_ranges = ["35.235.240.0/20", local.primary_reserved_ips, local.dr_reserved_ips]
  target_tags   = ["sqlproxy"]
}

module "db" {
  source              = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/cloudsql-instance?ref=v19.0.0"
  project_id          = local.project_id
  network             = data.google_compute_network.my-network.self_link
  name                = "postgres14-${local.primary_region}"
  region              = local.primary_region
  database_version    = "POSTGRES_14"
  tier                = "db-g1-small"
  availability_type   = "REGIONAL"
  ipv4_enabled        = false
  databases           = [local.db]
  deletion_protection = false

  users = {
    postgres = local.username
  }

  flags = {
    "cloudsql.logical_decoding"   = "on"
    "max_connections"             = 1000
    "cloudsql.iam_authentication" = "on"
  }
  encryption_key_name = module.eu-west2-blog-keyring.keys["key-a"].id

  # replicas = {
  #   "postgres14-${local.dr_region}" = {
  #     region              = local.dr_region,
  #     encryption_key_name = module.eu-west1-blog-keyring-dr.keys["key-a"].id
  #   }
  # }
  depends_on = [
    module.eu-west2-blog-keyring,
    module.eu-west1-blog-keyring-dr
  ]
}

# Setup Cloud IAM users on the Instance
resource "google_sql_user" "users" {
  for_each = toset(concat(local.sql_users))
  project  = local.project_id
  name     = each.value
  instance = module.db.name
  type     = "CLOUD_IAM_USER"
  depends_on = [
    module.db
  ]
}

# Database username for Cloud IAM service account should be created without ".gserviceaccount.com" suffix.
# Hence the replace below
resource "google_sql_user" "service-account" {
  project  = local.project_id
  name     = replace(google_service_account.datastream_sa.email, ".gserviceaccount.com", "")
  instance = module.db.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"


}


module "cloudsqlproxy" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/compute-vm"
  project_id = local.project_id
  zone       = "${local.primary_region}-a"
  name       = "sqlproxy"

  network_interfaces = [{
    network    = data.google_compute_network.my-network.self_link
    subnetwork = data.google_compute_subnetwork.my-subnetwork.self_link
  }]

  instance_type = "e2-medium"
  boot_disk = {
    image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    type  = "pd-ssd"
    size  = 100
  }

  tags                   = ["sqlproxy"]
  service_account        = google_service_account.datastream_sa.email
  service_account_scopes = ["cloud-platform"]

  metadata = {
    startup-script = templatefile("${path.module}/startup_script.tpl",
      {
        postgresdb                = local.db
        docker_image              = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.1.1"
        cloud_instance_connection = module.db.connection_name,
        pgp                       = local.username
        sql_script = templatefile("${path.module}/sql_setup.tpl",
          {
            schema = local.schema
            user   = local.username
          }
        )
      }
    )
  }
  depends_on = [module.db]
}


module "bigquery-dataset-primary-region" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/bigquery-dataset"
  project_id = local.project_id
  id         = "stream_dataset_${replace(local.primary_region, "-", "_")}"
  location   = local.primary_region
}

module "bigquery-dataset-dr-region" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/bigquery-dataset"
  project_id = local.project_id
  id         = "stream_dataset_${replace(local.dr_region, "-", "_")}"
  location   = local.dr_region
}

resource "google_datastream_private_connection" "priv-primary-region" {
  display_name          = "dstream-priv-${local.primary_region}"
  location              = local.primary_region
  private_connection_id = "dstream-priv-${local.primary_region}"

  labels = {
    region = "london"
  }

  vpc_peering_config {
    vpc    = data.google_compute_network.my-network.id
    subnet = local.primary_reserved_ips
  }

}

resource "google_datastream_private_connection" "priv-dr-region" {
  display_name          = "dstream-priv-${local.dr_region}"
  location              = local.dr_region
  private_connection_id = "dstream-priv-${local.dr_region}"

  labels = {
    region = local.dr_region
  }

  vpc_peering_config {
    vpc    = data.google_compute_network.my-network.id
    subnet = local.dr_reserved_ips
  }
}


resource "google_datastream_connection_profile" "postgres-primary-region" {
  display_name          = "postgres-${local.primary_region}"
  location              = local.primary_region
  connection_profile_id = "postgres-${local.primary_region}"

  postgresql_profile {
    hostname = module.cloudsqlproxy.internal_ip
    port     = local.port
    username = local.username
    password = local.username
    database = local.db
  }

  private_connectivity {
    private_connection = google_datastream_private_connection.priv-primary-region.name
  }

  depends_on = [
    module.db
  ]
}

resource "google_datastream_connection_profile" "postgres-dr-region" {
  display_name          = "postgres-${local.dr_region}"
  location              = local.dr_region
  connection_profile_id = "postgres-${local.dr_region}"

  postgresql_profile {
    hostname = module.cloudsqlproxy.internal_ip
    port     = local.port
    username = local.username
    password = local.username
    database = local.db
  }

  private_connectivity {
    private_connection = google_datastream_private_connection.priv-dr-region.name
  }
  depends_on = [
    module.db
  ]
}

resource "google_datastream_connection_profile" "bq-primary-region" {
  display_name          = "bq-profile-${local.primary_region}"
  location              = local.primary_region
  connection_profile_id = "bq-profile-${local.primary_region}"

  bigquery_profile {}

  private_connectivity {
    private_connection = google_datastream_private_connection.priv-primary-region.id
  }

  depends_on = [
    module.db, module.bigquery-dataset-primary-region, module.bigquery-dataset-dr-region
  ]
}

resource "google_datastream_connection_profile" "bq-dr-region" {
  display_name          = "bq-profile-${local.dr_region}"
  location              = local.dr_region
  connection_profile_id = "bq-profile-${local.dr_region}"

  bigquery_profile {}

  private_connectivity {
    private_connection = google_datastream_private_connection.priv-dr-region.id
  }
  depends_on = [
    module.db, module.bigquery-dataset-primary-region, module.bigquery-dataset-dr-region
  ]
}

resource "google_datastream_stream" "stream-primary-region" {
  display_name  = "Postgres to BigQuery - ${local.primary_region}"
  location      = local.primary_region
  stream_id     = "stream-pg-bq-${local.primary_region}"
  desired_state = "NOT_STARTED"

  source_config {
    source_connection_profile = google_datastream_connection_profile.postgres-primary-region.id
    postgresql_source_config {
      max_concurrent_backfill_tasks = 12
      publication                   = "pub1"
      replication_slot              = "rs1"
      include_objects {
        postgresql_schemas {
          schema = local.schema
        }
      }
      exclude_objects {
        postgresql_schemas {
          schema = "information_schema.*"
        }
      }
    }
  }

  destination_config {
    destination_connection_profile = google_datastream_connection_profile.bq-primary-region.id
    bigquery_destination_config {
      data_freshness = "0s"
      single_target_dataset {
        dataset_id = "${local.project_id}:${module.bigquery-dataset-primary-region.dataset_id}"
      }
    }
  }

  backfill_all {}
}

resource "google_datastream_stream" "stream-dr-region" {
  display_name  = "Postgres to BigQuery - ${local.dr_region}"
  location      = local.dr_region
  stream_id     = "stream-pg-bq-${local.dr_region}"
  desired_state = "NOT_STARTED"

  source_config {
    source_connection_profile = google_datastream_connection_profile.postgres-dr-region.id
    postgresql_source_config {
      max_concurrent_backfill_tasks = 12
      publication                   = "pub2"
      replication_slot              = "rs2"
      include_objects {
        postgresql_schemas {
          schema = local.schema
        }
      }
      exclude_objects {
        postgresql_schemas {
          schema = "information_schema.*"
        }
      }
    }
  }

  destination_config {
    destination_connection_profile = google_datastream_connection_profile.bq-dr-region.id
    bigquery_destination_config {
      data_freshness = "0s"
      single_target_dataset {
        dataset_id = "${local.project_id}:${module.bigquery-dataset-dr-region.dataset_id}"
      }
    }
  }

  backfill_all {}
}
