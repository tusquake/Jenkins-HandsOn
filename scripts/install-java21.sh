#!/usr/bin/env bash
# Installs Java 21 (Eclipse Temurin) on Debian/Ubuntu.
# Current Jenkins releases require Java 21+, and Debian 12 only ships up to Java 17.
set -euo pipefail

sudo mkdir -p /etc/apt/keyrings

wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | sudo tee /etc/apt/keyrings/adoptium.asc > /dev/null

CODENAME="$(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release)"
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb ${CODENAME} main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list > /dev/null

sudo apt-get update
sudo apt-get install -y temurin-21-jdk fontconfig

java -version
