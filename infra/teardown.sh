#!/usr/bin/env bash
# Deletes the Jenkins lab resources. Run ONLY when all exercises are finished.
# Usage: PROJECT_ID=my-project ./infra/teardown.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID, e.g. PROJECT_ID=my-project}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-jenkins-server}"
FW_RULE="${FW_RULE:-allow-jenkins-8080}"

echo "This will DELETE VM '$VM_NAME' and firewall rule '$FW_RULE' in project '$PROJECT_ID'."
read -r -p "Type 'yes' to continue: " CONFIRM
[ "$CONFIRM" = "yes" ] || { echo "Aborted."; exit 1; }

gcloud compute instances delete "$VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" --quiet
gcloud compute firewall-rules delete "$FW_RULE" --project="$PROJECT_ID" --quiet

echo
echo "Verifying nothing is left:"
gcloud compute instances list --project="$PROJECT_ID"
gcloud compute disks list --project="$PROJECT_ID"
gcloud compute firewall-rules list --project="$PROJECT_ID" --filter="name=$FW_RULE"
