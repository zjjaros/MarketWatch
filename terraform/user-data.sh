
#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[user-data] Updating package lists"
apt-get update

echo "[user-data] Installing Docker and required tools"
apt-get install -y \
  docker.io \
  docker-compose-v2 \
  unzip \
  curl \
  python3

echo "[user-data] Enabling and starting Docker"
systemctl enable --now docker

echo "[user-data] Verifying Docker installation"
docker --version
docker compose version
systemctl is-active --quiet docker

echo "[user-data] Base installation completed successfully"

echo "[user-data] Getting awscli zip"
curl -fsSL \
  "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
  -o /tmp/awscliv2.zip

echo "[user-data] Unzipping awscli"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

echo "[user-data] Removing temp awscli zip"
rm -rf /tmp/aws /tmp/awscliv2.zip

# Ubuntu 24.04 normally uses snap/systemd-managed SSM Agent if present.
# Do not perform ECR login or pull here; deployment handles those steps.
echo "[user-data] Finished user-data.sh"