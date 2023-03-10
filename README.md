# mr-spanner

Exemplar code to simultaneously write to 2 Bigquery Datasets in 2 separate regions at the same time using datastream.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.50.0 |


## Instructions
Edit  `Main.tf` in `/infra` and change the Values for the following vars in the locals section:
* project_id           = "xxxxx"
* primary_region       = "REGION1" for example "europe-west2"
* dr_region            = "REGION2" for example, "europe-west1"
* primary_reserved_ips = "Reserved IPV4 Range for europe-west2" for example, "10.124.0.0/29"
* dr_reserved_ips      = "Reserved IPV4 Range for europe-west2" for example, "10.126.0.0/29"
* sql_users            = ["GCP login email"] for example, kev.pinto@google.com
* In your cloud sql instance ensure that the password for your `postgres` user is `postgres` as that is what the automated setup script expects
<br>
Please note: primary and dr reserved ips are not the subnet IPs. These are a reserved IPs ranges that are not in use by any subnets, these will be used by datasream to set up private VPC peering between datastream and the users project.


* Edit provider.tf in /infra and change the project ID

### Known issues #1
* There is a bug in the existing cloud sql module that does not allow the creation of a CMEK Based Replica using a  Key being created as part of the current TF Plan.
* As a work around, create the replica in the second pass. this means comment the `replicas block in `module.db`,


`
replicas = {
    "postgres14-${local.dr_region}" = {
     region              = local.dr_region,
       encryption_key_name = module.eu-west1-blog-keyring-dr.keys["key-a"].id
     }
   }
`
<br>
* Run the `terraform apply`, uncomment the block and then run `terraform apply` again.

### Known issues #2
* At times, due to network lags the setup scripts that are supposed to create the replication slots do not execute. This is a very rare occurence. in the event of this happening, run the script manually. the script can be found in `/tmp/sql_setup.sql` on your newly created SQL Proxy VM.

Note: Failure to detect the replication and publication slots will not allow terraform to create the stream. So terraform apply will have to be run again after creating the slots for the rest of the deployment to complete.


###Deploy Steps
* cd infra
* `terraform init`
* `terraform plan` -- make sure there are no errors
* `terraform apply --auto-approve`
