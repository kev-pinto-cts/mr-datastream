# V1.3
docker run -d -p 5432:5432 \
gcr.io/cloudsql-docker/gce-proxy:1.33.1 /cloud_sql_proxy \
-instances=nnnn:europe-west2:postgres14-europe-west2=tcp:0.0.0.0:5432

#V2.1
docker run -d -p 5432:5432 \
gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.1.0 --private-ip \
nnnn:europe-west2:postgres14-europe-west2?address=0.0.0.0&port=5432
