module "eu-west2-blog-keyring" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/kms"
  project_id = local.project_id

  iam_additive = {
    "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
      "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
    ]
  }
  keyring = { location = local.primary_region, name = "eu-west2-blog-keyring-final" }
  # keyring_create = false
  keys = {
    key-a = { rotation_period = null, labels = { env = "blog" } }
  }
  depends_on = [
    google_project_service_identity.gcp_sa_cloud_sql
  ]
}

module "eu-west1-blog-keyring-dr" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/kms"
  project_id = local.project_id

  iam_additive = {
    "roles/cloudkms.cryptoKeyEncrypterDecrypter" = [
      "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
    ]
  }
  keyring = { location = local.dr_region, name = "eu-west1-blog-keyring-final" }
  # keyring_create = false
  keys = {
    key-a = { rotation_period = null, labels = { env = "blog" } }
  }
  depends_on = [
    google_project_service_identity.gcp_sa_cloud_sql
  ]
}
