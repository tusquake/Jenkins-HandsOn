#!/usr/bin/env bash
# Creates a local Git repo with two branches (main, feature-payment),
# each with its own Jenkinsfile, for the Multibranch Pipeline lab.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/tmp/sample-repo}"

command -v git >/dev/null || { echo "git is not installed."; exit 1; }

rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

git init -b main
git config user.email "devops@example.com"
git config user.name "DevOps Engineer"

cat > Jenkinsfile << 'EOF'
pipeline {
  agent any
  stages {
    stage('Main Branch Pipeline') {
      steps { echo "Executing pipeline on MAIN branch" }
    }
  }
}
EOF
git add .
git commit -m "Initial commit on main"

git checkout -b feature-payment
cat > Jenkinsfile << 'EOF'
pipeline {
  agent any
  stages {
    stage('Feature Branch Pipeline') {
      steps { echo "Executing pipeline on FEATURE-PAYMENT branch" }
    }
  }
}
EOF
git add .
git commit -m "Update Jenkinsfile for feature-payment branch"

# Jenkins runs as the 'jenkins' user and must be able to read the repo
if id jenkins >/dev/null 2>&1; then
  sudo chown -R jenkins:jenkins "$REPO_DIR"
  sudo chmod -R 755 "$REPO_DIR"
fi

echo "Created $REPO_DIR with branches: $(git branch --format='%(refname:short)' | tr '\n' ' ')"
