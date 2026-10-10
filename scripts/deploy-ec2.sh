
#!/usr/bin/env bash

set -Eeuo pipefail

REGION="us-west-2"
ACCOUNT_ID="997956187142"
ECR_REPOSITORY="marketwatch"
IMAGE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPOSITORY}:latest"
COMPOSE_FILE="/opt/marketwatch/compose.prod.yaml"
DB_INSTANCE_IDENTIFIER="marketwatch-db"
DB_NAME="marketwatch"

# Ensure required tools are installed.
command -v docker >/dev/null
command -v aws >/dev/null
command -v python3 >/dev/null
command -v curl >/dev/null

# Confirm that the current RDS secret ARN was supplied by the workflow.
if [[ -z "${DB_SECRET_ARN:-}" ]]; then
  echo "ERROR: DB_SECRET_ARN is not set."
  exit 1
fi

# Retrieve the RDS-managed database credentials.
# Never print this value to the deployment log.
SECRET_JSON="$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "$DB_SECRET_ARN" \
  --query SecretString \
  --output text)"

# Retrieve the current database endpoint from RDS.
# This avoids hard-coding an endpoint that may change after recreation.
DB_HOST="$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)"

if [[ -z "$DB_HOST" || "$DB_HOST" == "None" ]]; then
  echo "ERROR: Could not determine the RDS endpoint."
  exit 1
fi

# Build a URL-encoded PostgreSQL connection string.
export DATABASE_URL="$(
  printf '%s' "$SECRET_JSON" | python3 -c '
import json
import sys
from urllib.parse import quote

secret = json.load(sys.stdin)
host = sys.argv[1]
port = 5432
database = "marketwatch"

username = quote(secret["username"], safe="")
password = quote(secret["password"], safe="")

print(
    f"postgresql+psycopg://{username}:{password}"
    f"@{host}:{port}/{database}"
)
' "$DB_HOST"
)"

unset SECRET_JSON

# Confirm deployment files exist before changing the running app.
if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "ERROR: Compose file not found: $COMPOSE_FILE"
  exit 1
fi

cd /opt/marketwatch

# Authenticate to ECR and pull the latest image.
aws ecr get-login-password --region "$REGION" |
  docker login --username AWS --password-stdin \
    "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker compose -f "$COMPOSE_FILE" pull

# Apply database migrations once, before starting the new containers.
docker compose -f "$COMPOSE_FILE" run --rm api alembic upgrade head

# Start or recreate the API and collector containers.
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# Wait for the API to become responsive.
for attempt in $(seq 1 30); do
  if curl --fail --silent http://localhost:8000/prices >/dev/null; then
    echo "Deployment successful: API health check passed."
    docker compose -f "$COMPOSE_FILE" ps
    exit 0
  fi

  sleep 2
done

echo "ERROR: API did not become healthy. Recent container logs:"
docker compose -f "$COMPOSE_FILE" logs --tail=80 api collector
exit 1