#!/usr/bin/env bash
# Installs the Jenkins LTS package on Debian/Ubuntu.
# The repository signing key is rotated periodically. If apt reports NO_PUBKEY,
# check https://www.jenkins.io/doc/book/installing/linux/ for the current key name
# and override it: JENKINS_KEY=jenkins.io-20XX.key ./install-jenkins.sh
set -euo pipefail

JENKINS_KEY="${JENKINS_KEY:-jenkins.io-2026.key}"

command -v java >/dev/null || { echo "Java not found. Run scripts/install-java21.sh first."; exit 1; }

sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  "https://pkg.jenkins.io/debian-stable/${JENKINS_KEY}"

# The whole 'deb [...] URL suite' entry must be inside ONE pair of quotes.
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update
sudo apt-get install -y jenkins git

sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins --no-pager

echo
echo "Initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo
echo "Open: http://$(curl -s ifconfig.me):8080"
