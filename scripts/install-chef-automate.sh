#!/bin/bash
# Usage:
# $SCRIPT ec2-53-42-54 mike
apt-get update
apt-get -y install curl

chef_server_fqdn=$1
user=$2
org=chefautomate

# create downloads directory
if [ ! -d /downloads ]; then
  mkdir /downloads
fi

# download the Chef Automate package
if [ ! -f /downloads/automate_1.7.114-1_amd64.deb ]; then
  echo "Downloading the Chef Automate package..."
  wget -nv -P /downloads https://packages.chef.io/files/stable/automate/1.7.114/ubuntu/16.04/automate_1.7.114-1_amd64.deb
fi

# install Chef Automate
if [ ! $(which automate-ctl) ]; then
  echo "Installing Chef Automate..."
  dpkg -i /downloads/automate_1.7.144-1_amd64.deb

  # run preflight check
  automate-ctl preflight-check

  # run setup
  automate-ctl setup --license /home/ubuntu/automate.license --key /home/ubuntu/delivery.pem --server-url https://$chef_server_fqdn/organizations/$org --fqdn $(hostname) --enterprise default --configure --no-build-node
  automate-ctl reconfigure

  # wait for all services to come online
  echo "Waiting for services..."
  until (curl --insecure -D - https://localhost/api/_status) | grep "200 OK"; do sleep 1m && automate-ctl restart; done
  while (curl --insecure https://localhost/api/_status) | grep "fail"; do sleep 15s; done

  # create an initial user
  echo "Creating delivery user..."
  automate-ctl create-user default $user --password admin --roles "admin"
fi

echo "Your Chef Automate server is ready!"
