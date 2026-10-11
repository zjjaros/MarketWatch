
#!/usr/bin/env bash
set -Eeuo pipefail

REGION="us-west-2"
ACCOUNT_ID="997956187142"
ECR_REPOSITORY="marketwatch"
COMPOSE_FILE="/opt/marketwatch/compose.collector.yaml"
DB_INSTANCE_IDENTIFIER="marketwatch-db"

command -v docker >/dev/null
command -v aws >/dev/null
command -v python3 >/dev/null

if [[ -z "${DB_SECRET_ARN:-}" ]]; then
  echo "ERROR: DB_SECRET_ARN is not set."
  exit 1
fi

SECRET_JSON="$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "$DB_SECRET_ARN" \
  --query SecretString \
  --output text)"

DB_HOST="$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)"

if [[ -z "$DB_HOST" || "$DB_HOST" == "None" ]]; then
  echo "ERROR: Could not determine the RDS endpoint."
  exit 1
fi

export DATABASE_URL="$(
  printf '%s' "$SECRET_JSON" | python3 -c '
import json
import sys
from urllib.parse import quote

secret = json.load(sys.stdin)
host = sys.argv[1]
username = quote(secret["username"], safe="")
password = quote(secret["password"], safe="")

print(
    f"postgresql+psycopg://{username}:{password}"
    f"@{host}:5432/marketwatch"
)
' "$DB_HOST"
)"

unset SECRET_JSON

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "ERROR: Compose file not found: $COMPOSE_FILE"
  exit 1
fi

cd /opt/marketwatch

aws ecr get-login-password --region "$REGION" |
  docker login --username AWS --password-stdin \
    "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker compose -f "$COMPOSE_FILE" pull
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# Confirm that the collector container remains running.
sleep 3

if [[ "$(docker compose -f "$COMPOSE_FILE" ps --status running -q collector)" == "" ]]; then
  echo "ERROR: Collector container is not running. Recent logs:"
  docker compose -f "$COMPOSE_FILE" logs --tail=80 collector
  exit 1
fi

echo "Collector deployment successful."
docker compose -f "$COMPOSE_FILE" ps