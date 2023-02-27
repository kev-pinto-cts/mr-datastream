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
* Open Main.tf in /infra and change the Values for the following vars in the locals section
* project_id           = "xxxxx"
* primary_region       = "REGION1" for example "europe-west2"
* dr_region            = "REGION2" for example, "europe-west1"
* primary_reserved_ips = "Reserved IPV4 Range for europe-west2" for example, "10.124.0.0/29"
* dr_reserved_ips      = "Reserved IPV4 Range for europe-west2" for example, "10.126.0.0/29"
* sql_users            = ["GCP login email"] for example, kev.pinto@google.com
<br>
Please note: primary and dr reserved ips are not the subnet IPs. These are a reserved IPs ranges that are not in use by any subnets, these will be used by datasream to set up private VPC peering between datastream and the users project.
