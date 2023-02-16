# nwm-digital-mr-spanner

This module Builds Single/Regional Spanner clusters and Databases (Optional)
within the newly built instances.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.50.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_service-account-gcs"></a> [service-account-gcs](#module\_service-account-gcs) | tfe.nwm-infra-tfe-server.nwmworld.com/nwm-digital/fabric/foundation//modules/iam-service-account | 19.0.7-internal |

## Resources

| Name | Type |
|------|------|
| [google_spanner_instance_iam_policy.authoritative](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/spanner_instance_iam#google_spanner_instance_iam_policy) | resource |
| [google_spanner_database_iam_policy.authoritative](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/spanner_database_iam#google_spanner_database_iam_policy) | resource |
| [google_sql_user.service-account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [google_sql_user.users](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id|GCP Project ID | `string`| `n/a` | yes|
| env| Target Env (dev/test/uat/prod) | `string`| `n/a` | yes|
| spanner.yaml | A YAML file Speciifying the Instances to be created and databases to be created under each instance | `yaml` | `n/a` | yes |
| sql_admins| A list of Admins - must have nwmworld.com domains | `list(string)` | `n/a` | yes |
| sql_sa | Application Service Accounts | `list(string)` | `n/a` | yes |

`Spanner.yaml example file`

The following file creates the following:

-   A Regional Instance (europe-west2) called test-inst1-{env}
-   2 dbs called tfxrs-rate-service & tfxrs-quote-service using POSTGRESQL dialect
-   1 db called tfxrs-sql-service using the GOOGLE_STANDARD_SQL dialect

**One can create Multiple Instances and Multiple Databases within these instances
with different SQL Dialects (POSTGRESQL/STANDARD) as long as the Heirachial structure
of the YAML is maintained**.

```yaml
spanner:
  instances:
  - name: test-inst1
    display_name: Regional Spanner Instance
    config: regional-europe-west2
    num_nodes: 1
    force_destroy: true
    labels:
      product: tfxrs
      env: dev
    databases:
    - name: tfxrs-rate-service
      database_dialect: POSTGRESQL
    - name: tfxrs-quote-service
      database_dialect: POSTGRESQL
      deletion_protection: false
      version_retention_period: 7d
    - name: tfxrs-sql-service
      database_dialect: GOOGLE_STANDARD_SQL
```

Example 2: Creating 2 Instances and 1 database within each Instance

```yaml
spanner:
  instances:
  - name: test-inst1
    display_name: Regional Spanner Instance
    config: regional-europe-west2
    num_nodes: 1
    force_destroy: true
    labels:
      product: tfxrs
      env: dev
    databases:
    - name: tfxrs-sql-service
      database_dialect: GOOGLE_STANDARD_SQL
      version_retention_period: 7d
  - name: test-inst2
    display_name: Regional Spanner Instance
    config: regional-europe-west2
    num_nodes: 1
    force_destroy: true
    labels:
      product: fxmp
      env: dev
    databases:
    - name: fxmp-rate-service
      database_dialect: POSTGRESQL
      version_retention_period: 7d

```

### Example Usage - Module
```bash
module "mr-spanner" {
  source         = "../"
  project_id     = "cloudsqlpoc-demo"
  env            = "dev"
  spanner_config = try(yamldecode(file("../spanner_config/spanner.yaml")), {})
  sql_admins     = ["kev.pinto@nwmworld.com", "simon.darlington@nwmworld.com"]
  sql_sa         = ["99999999-compute@developer.gserviceaccount.com"]
}
```

## Outputs

| Name | Description |
|------|-------------|
n/a
<!-- END_TF_DOCS -->
