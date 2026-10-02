#!/bin/bash
# ==============================================================================
# Killercoda Background Setup Script
# DevSecOps & Container DFIR Workshop - CPIFP Alan Turing
# ==============================================================================

set -euo pipefail

LOGFILE="/var/log/background_setup.log"
exec > >(tee -a "${LOGFILE}") 2>&1

echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [INIT] Starting Killercoda background setup..."

# 1. Ensure Docker daemon is active
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [DOCKER] Verifying Docker daemon status..."
if ! systemctl is-active --quiet docker; then
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [DOCKER] Starting Docker service..."
    systemctl start docker || service docker start
fi

# 2. Update package repositories and install required tools (yara, jq)
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [APT] Installing YARA and jq..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y yara jq

# 3. Create Host Root Flag for Challenge 2
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [FLAG] Provisioning Host Root Flag..."
echo "FLAG{host_takeover_via_docker_socket_alan_turing_2026}" > /root/host_flag.txt
chmod 600 /root/host_flag.txt

# 4. Synchronize assets and evidence directories
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [ASSETS] Preparing scenario paths..."
mkdir -p /assets/victim /evidence

# Check and copy from local scenario folder if not already in /assets
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${SCRIPT_DIR}/assets" ]; then
    cp -ru "${SCRIPT_DIR}/assets/"* /assets/
    if [ -f "${SCRIPT_DIR}/assets/evidence/backdoor_implant.sh" ]; then
        cp -u "${SCRIPT_DIR}/assets/evidence/backdoor_implant.sh" /evidence/backdoor_implant.sh
    fi
fi

# Ensure permissions on evidence
if [ -f /evidence/backdoor_implant.sh ]; then
    chmod 755 /evidence/backdoor_implant.sh
elif [ -f /assets/evidence/backdoor_implant.sh ]; then
    cp /assets/evidence/backdoor_implant.sh /evidence/backdoor_implant.sh
    chmod 755 /evidence/backdoor_implant.sh
fi

# Make scripts in assets executable
chmod +x /assets/victim/*.sh 2>/dev/null || true

# 5. Pre-pull alpine image to accelerate Challenge 2 breakout
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [DOCKER] Pre-pulling alpine image..."
docker pull alpine:3.19 || docker pull alpine:latest || true

# 6. Build victim container image
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [DOCKER] Building CI/CD runner victim image..."
docker build -t alan-turing/cicd-runner:vulnerable /assets/victim

# 7. Launch vulnerable container infrastructure
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [COMPOSE] Starting container stack..."
if docker compose version >/dev/null 2>&1; then
    docker compose -f /assets/docker-compose.yml up -d
else
    docker-compose -f /assets/docker-compose.yml up -d
fi

# 8. Wait for container to be ready
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [WAIT] Waiting for cicd_runner_pipeline container..."
MAX_RETRIES=30
COUNT=0
until [ "$(docker inspect -f '{{.State.Running}}' cicd_runner_pipeline 2>/dev/null)" = "true" ]; do
    sleep 1
    COUNT=$((COUNT + 1))
    if [ "${COUNT}" -ge "${MAX_RETRIES}" ]; then
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [ERROR] Timeout waiting for cicd_runner_pipeline to start."
        exit 1
    fi
done

# 9. Inject forensic artifact into container's writable overlay layer
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [DFIR] Injecting forensic implant into container..."
docker exec cicd_runner_pipeline mkdir -p /var/log/pipeline_audit/
docker cp /evidence/backdoor_implant.sh cicd_runner_pipeline:/var/log/pipeline_audit/backdoor_implant.sh
docker exec cicd_runner_pipeline chmod 755 /var/log/pipeline_audit/backdoor_implant.sh

# 10. Drop completion marker for foreground script
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [READY] Background provisioning completed successfully."
touch /tmp/killercoda_ready
