#! /bin/bash
sudo apt update
sudo apt install apt-transport-https curl gnupg-agent ca-certificates software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt install docker-ce docker-ce-cli containerd.io -y

sudo docker pull gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.1.0
sudo docker pull gcr.io/cloudsql-docker/gce-proxy:1.33.1
sudo usermod -a -G docker $USER
newgrp
sudo docker run -d -p 5432:5432 \
gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.1.0 --auto-iam-authn --private-ip \
${cloud_instance_connection}?address=0.0.0.0&port=5432

#  Install Psql
sudo apt -y install postgresql-client
echo "${sql_script}" >> /tmp/sql_setup.sql

PGPASSWORD=${pgp} psql --host=127.0.0.1 --username=postgres --dbname=demodb -f /tmp/sql_setup.sql

exit 0
