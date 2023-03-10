#! /bin/bash
sudo apt update
sudo apt install apt-transport-https curl gnupg-agent ca-certificates software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt install docker-ce docker-ce-cli containerd.io -y

sudo docker pull ${docker_image}
sudo usermod -a -G docker \$USER
newgrp

echo "sudo docker run -d -p 5432:5432 ${docker_image} --address 0.0.0.0 --port 5432 --auto-iam-authn --private-ip ${cloud_instance_connection}" > /tmp/docker_run.sh
chmod 510 /tmp/docker_run.sh

sudo docker run -d -p 5432:5432 ${docker_image} --address 0.0.0.0 --port 5432 --auto-iam-authn --private-ip ${cloud_instance_connection}

#  Install Psql
sudo apt -y install postgresql-client
echo "${sql_script}" >> /tmp/sql_setup.sql

PGPASSWORD=${pgp} psql --host=127.0.0.1 --username=postgres --dbname=${postgresdb} -f /tmp/sql_setup.sql

exit 0
