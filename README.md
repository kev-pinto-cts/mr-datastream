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
* sql_users            = ["GCP login email"] for example, kev.pinto@xxx.com
* In your cloud sql instance ensure that the password for your `postgres` user is `postgres` as that is what the automated setup script expects

<br>
<b>Please Note:</b> primary and dr reserved ips are not the subnet IPs. These are a reserved IPs ranges that are not in use by any subnets, these will be used by datasream to set up private VPC peering between datastream and the users project.
<br><br>

Also Please edit `provider.tf` in /infra and change the project ID


## Deploy Steps
* cd infra
* `terraform init`
* `terraform plan` -- make sure there are no errors
* `terraform apply --auto-approve`

### Known issues #1
* There is a bug in the existing cloud sql module that does not allow the creation of a CMEK Based Replica using a  Key being created as part of the current TF Plan.
* As a work around, create the replica in the second pass. this means comment the `replicas block in `module.db` (lines 127-132 in main.tf)


```hcl
replicas = {
    "postgres14-${local.dr_region}" = {
     region              = local.dr_region,
       encryption_key_name = module.eu-west1-blog-keyring-dr.keys["key-a"].id
     }
   }
```
<br>
* Run the `terraform apply`, uncomment the block and then run `terraform apply` again.

<br>

### Known issues #2

<p>At times, the setup scripts that are supposed to create the replication slots do not execute. This is because the docker instance has not instantiated yet. This is an infrequent occurence, however, in the event of this happening, run the script manually. the script can be found in `/tmp/sql_setup.sql` on your newly created SQL Proxy VM.</p>

Prior to running the script ensure the proxy is up and running, check this by running `docker ps ` on the VM terminal.
if the container is not running or has died, restart the same with the following command:
<br>
`sudo /tmp/docker_run.sh`
<br>
Test Connection to the db
<br>
`psql -h 127.0.0.1 -p 5432 -d demodb -U postgres`
<br>
Specify the password as postgres, exit and run the script to create the replication slots
<br>
```psql -h 127.0.0.1 -p 5432 -d demodb -U postgres -f /tmp/sql_setup.sql ```
<p>
Note: Failure to detect the replication and publication slots will not allow terraform to create the stream. So terraform apply will have to be run again after creating the slots for the rest of the deployment to complete.
</p>



## Post Install Checks
* <b>Verify Publication</b>
```sql
demodb=> select * from pg_publication;
  oid  | pubname | pubowner | puballtables | pubinsert | pubupdate | pubdelete | pubtruncate | pubviaroot
-------+---------+----------+--------------+-----------+-----------+-----------+-------------+------------
 16470 | pub1    |    16388 | t            | t         | t         | t         | f           | f
 16471 | pub2    |    16388 | t            | t         | t         | t         | f           | f
(2 rows)
```

* <b> Verify Replication Slots </b>
```
 slot_name |  plugin  | slot_type | datoid | database | temporary | active | active_pid | xmin | catalog_xmin | restart_lsn | confirmed_flush_lsn | wal_status | safe_wal_size | two_phase
-----------+----------+-----------+--------+----------+-----------+--------+------------+------+--------------+-------------+---------------------+------------+---------------+-----------
 rs1       | pgoutput | logical   |  16466 | demodb   | f         | f      |            |      |         1165 | 0/1A9F3A0   | 0/1A9F3D8           | reserved   |               | f
 rs2       | pgoutput | logical   |  16466 | demodb   | f         | f      |            |      |         1165 | 0/1A9F3D8   | 0/1A9F410           | reserved   |               | f
(2 rows)

```


### Create Some tables in the data_schema
* Create some tables

```
create table data_schema.test_datastream(
    myid SERIAL PRIMARY KEY,
    somecol varchar(100),
    log_date  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP);


create table data_schema.test_datastream_part(
    myid SERIAL,
    somecol varchar(100),
    log_date  timestamp(0) without time zone NULL)
    PARTITION BY RANGE(log_date);

ALTER TABLE data_schema.test_datastream_part ADD CONSTRAINT pk_test_datastream_part primary key(myid,log_date);

CREATE TABLE data_schema.test_datastream_part_2021 PARTITION OF data_schema.test_datastream_part FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE data_schema.test_datastream_part_2022 PARTITION OF data_schema.test_datastream_part FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE data_schema.test_datastream_part_2023 PARTITION OF data_schema.test_datastream_part FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
```

## Populate some data
Start a tunnel to your proxy, the proxy VM was created as part of the terraform.
On a terminal on your mac/linux machine type the following and keep this window running

```
gcloud compute start-iap-tunnel sqlproxy 5432 --local-host-port=localhost:5432 --zone=europe-west2-a
```
In your repo:
* cd to `datastream_tester` folder
* Install the dependencies in a virtual env or a dev container
`pip3 install -r requirements.txt`
* Run the code - Make sure to set `db_pass` on line 28 to postgres
`python3 tester.py`


## Start the Stream
The streams are deployed in the <b>NOT_STARTED</b>. Manually turn these on from the cloud consoles
