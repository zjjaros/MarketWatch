
#!/usr/bin/env bash
set -Eeuo pipefail

REGION="us-west-2"
ACCOUNT_ID="997956187142"
ECR_REPOSITORY="marketwatch"
IMAGE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPOSITORY}:latest"
COMPOSE_FILE="/opt/marketwatch/compose.prod.yaml"
DB_NAME="marketwatch"

if [[ -z "${DB_SECRET_ARN:-}" ]]; then
  echo "ERROR: DB_SECRET_ARN is not set."
  exit 1
fi

# Ensure Docker and AWS CLI are available.
command -v docker >/dev/null
command -v aws >/dev/null
command -v python3 >/dev/null

# Retrieve credentials without printing the secret.
SECRET_JSON="$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "$DB_SECRET_ARN" \
  --query SecretString \
  --output text)"

# Construct a correctly URL-encoded PostgreSQL connection string.
export DATABASE_URL="$(
  printf '%s' "$SECRET_JSON" | python3 -c '
import json
import sys
from urllib.parse import quote

s = json.load(sys.stdin)
host = s["host"]
port = s.get("port", 5432)
user = quote(s["username"], safe="")
password = quote(s["password"], safe="")
database = "marketwatch"

print(f"postgresql+psycopg://{user}:{password}@{host}:{port}/{database}")
'
)"
unset SECRET_JSON

cd /opt/marketwatch

# Authenticate and download the image that GitHub Actions just pushed.
aws ecr get-login-password --region "$REGION" |
  docker login --username AWS --password-stdin \
    "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker compose -f "$COMPOSE_FILE" pull

# Apply schema changes before restarting application containers.
docker compose -f "$COMPOSE_FILE" run --rm api alembic upgrade head

# Start/recreate the API and collector using the new image.
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# Wait for the API to respond.
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