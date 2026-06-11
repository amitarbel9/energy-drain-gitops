#!/usr/bin/env bash
# Sets the staging MONGO_URL secret in AWS Secrets Manager with validation,
# so a hand-typed value can't silently break the backend again.
#
# The chart appends "&tlsCAFile=<docdbCa.mountPath>/global-bundle.pem" to this
# value at deploy time (see templates/backend-deployment.yaml), so the secret
# must contain the BASE connection string only.
#
# Usage:
#   ./set-staging-mongo-secret.sh 'mongodb://USER:PASS@HOST:27017/?tls=true&retryWrites=false'
#
# After changing the secret, pods must be restarted to pick it up (the CSI
# driver only re-reads Secrets Manager when a pod mounts the volume):
#   kubectl rollout restart deployment/energy-drain-staging-energy-drain-app-backend -n energy-drain-staging
set -euo pipefail

REGION="ap-south-1"
SECRET_ID="staging/energy-drain/mongo-url"

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "Usage: $0 '<mongodb connection string>'" >&2
  exit 1
fi

fail() { echo "ERROR: $1" >&2; exit 1; }

case "$URL" in
  mongodb://*|mongodb+srv://*) ;;
  *) fail "URL must start with mongodb:// or mongodb+srv://" ;;
esac

[[ "$URL" == *\?* ]] || fail "URL must contain a query string (e.g. ?tls=true&retryWrites=false); the chart appends '&tlsCAFile=...' and needs the '?' to already be there"
[[ "$URL" == *"tls=true"* ]] || fail "DocumentDB requires tls=true in the query string"
[[ "$URL" == *"retryWrites=false"* ]] || fail "DocumentDB requires retryWrites=false in the query string"
[[ "$URL" != *"tlsCAFile"* ]] || fail "Do NOT include tlsCAFile - the Helm chart appends it (backend.docdbCa.mountPath); a hardcoded copy here will conflict"

aws secretsmanager put-secret-value \
  --region "$REGION" \
  --secret-id "$SECRET_ID" \
  --secret-string "$URL" \
  --query VersionId --output text \
|| aws secretsmanager create-secret \
  --region "$REGION" \
  --name "$SECRET_ID" \
  --secret-string "$URL" \
  --query ARN --output text

echo "Secret '$SECRET_ID' updated. Now restart the backend so the CSI driver re-syncs it:"
echo "  kubectl rollout restart deployment/energy-drain-staging-energy-drain-app-backend -n energy-drain-staging"
