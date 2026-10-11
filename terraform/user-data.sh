
#!/bin/bash
set -euxo pipefail

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  docker.io \
  docker-compose-v2 \
  unzip \
  curl

systemctl enable --now docker

curl -fsSL \
  "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o /tmp/awscliv2.zip

unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

rm -rf /tmp/aws /tmp/awscliv2.zip

# Ubuntu 24.04 normally uses snap/systemd-managed SSM Agent if present.
# Do not perform ECR login or pull here; deployment handles those steps.