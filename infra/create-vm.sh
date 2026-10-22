#!/usr/bin/env bash
# Creates the Jenkins lab VM and firewall rule on GCP.
# Usage: PROJECT_ID=my-project MY_IP=1.2.3.4/32 ./infra/create-vm.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID, e.g. PROJECT_ID=my-project}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-jenkins-server}"
FW_RULE="${FW_RULE:-allow-jenkins-8080}"
# Restrict access to your own IP. Defaults to open only because it is a short-lived lab.
SOURCE_RANGES="${MY_IP:-0.0.0.0/0}"

if [ "$SOURCE_RANGES" = "0.0.0.0/0" ]; then
  echo "WARNING: port 8080 will be open to the whole internet. Set MY_IP=<your-ip>/32 to restrict it."
fi

gcloud compute instances create "$VM_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --machine-type=e2-medium \
  --tags=jenkins-server

gcloud compute firewall-rules create "$FW_RULE" \
  --project="$PROJECT_ID" \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:8080 \
  --source-ranges="$SOURCE_RANGES" \
  --target-tags=jenkins-server

echo
echo "Done. Wait 30-45 seconds, then SSH in:"
echo "  gcloud compute ssh $VM_NAME --zone $ZONE --project $PROJECT_ID"
