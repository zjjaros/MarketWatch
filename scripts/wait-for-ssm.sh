
#!/usr/bin/env bash
set -euo pipefail

COMMAND_ID="$1"
INSTANCE_ID="$2"
REGION="$3"

for attempt in $(seq 1 60); do
  STATUS="$(aws ssm get-command-invocation \
    --region "$REGION" \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "Status" \
    --output text 2>/dev/null || true)"

  case "$STATUS" in
    Success)
      echo "SSM command succeeded on $INSTANCE_ID."
      aws ssm get-command-invocation \
        --region "$REGION" \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query "StandardOutputContent" \
        --output text
      exit 0
      ;;
    Failed|TimedOut|Cancelled|Cancelling)
      echo "ERROR: SSM command on $INSTANCE_ID ended with status: $STATUS"
      aws ssm get-command-invocation \
        --region "$REGION" \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --query "[StandardOutputContent,StandardErrorContent]" \
        --output json
      exit 1
      ;;
  esac

  sleep 5
done

echo "ERROR: Timed out waiting for SSM command on $INSTANCE_ID."
exit 1