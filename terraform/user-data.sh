#!/bin/bash

set -e

apt update
apt install -y docker.io docker-compose-v2

systemctl enable docker
systemctl start docker

apt install -y unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

unzip awscliv2.zip

./aws/install

echo 'export PATH="/usr/local/bin:$PATH"' >> /etc/profile
source /etc/profile

aws ecr get-login-password --region us-west-2 | \
docker login --username AWS --password-stdin \
997956187142.dkr.ecr.us-west-2.amazonaws.com

docker pull 997956187142.dkr.ecr.us-west-2.amazonaws.com/marketwatch:latest