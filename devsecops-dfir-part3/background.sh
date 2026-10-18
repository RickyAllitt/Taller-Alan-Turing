#!/bin/bash
# ==============================================================================
# Killercoda Background Setup Script - Parte 3 (Bonus Track)
# DevSecOps & Container DFIR Workshop - CPIFP Alan Turing
# ==============================================================================

exec > /var/log/killercoda_background.log 2>&1
set -x

# Remove any stale markers and residual flags
rm -f /tmp/killercoda_ready /tmp/killercoda_failed /root/host_flag.txt /root/flag*.txt /tmp/flag*.txt 2>/dev/null || true

# Error handling trap
cleanup_trap() {
    EXIT_CODE=$?
    if [ "${EXIT_CODE}" -ne 0 ]; then
        echo "[ERROR] background.sh failed with exit code ${EXIT_CODE} at line ${BASH_LINENO[0]}!"
        touch /tmp/killercoda_failed
    fi
}
trap cleanup_trap EXIT ERR

echo "[$(date '+%Y-%m-%d %I:%M:%S %p')] [INIT] Starting Killercoda background setup (Parte 3)..."

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

# 2. Install dependencies (jq, curl)
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends jq curl ca-certificates

# 3. Install Cosign (Sigstore)
echo "[TOOL] Installing Cosign..."
ARCH=$(uname -m)
if [ "${ARCH}" = "x86_64" ]; then
    COSIGN_ARCH="amd64"
else
    COSIGN_ARCH="arm64"
fi
curl -sSfL "https://github.com/sigstore/cosign/releases/download/v2.2.4/cosign-linux-${COSIGN_ARCH}" -o /usr/local/bin/cosign
chmod 755 /usr/local/bin/cosign

# 4. Install Trivy (Aqua Security)
echo "[TOOL] Installing Trivy..."
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
chmod 755 /usr/local/bin/trivy

# 5. Start local Docker Registry v2 on localhost:5000
echo "[REGISTRY] Starting local container registry..."
docker rm -f registry 2>/dev/null || true
docker run -d -p 5000:5000 --restart always --name registry registry:2

REG_RETRIES=20
until curl -sf http://localhost:5000/v2/ >/dev/null 2>&1 || [ ${REG_RETRIES} -le 0 ]; do
    sleep 1
    REG_RETRIES=$((REG_RETRIES - 1))
done

# 6. Prepare scenario assets & workspace
echo "[WORKSPACE] Setting up /root/shift-left workspace..."
mkdir -p /root/shift-left /assets/scoring /step5

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "${SCRIPT_DIR}/assets/shift-left" ]; then
    cp -ru "${SCRIPT_DIR}/assets/shift-left/"* /root/shift-left/ 2>/dev/null || true
fi

# Fallback: Create workspace files if missing
if [ ! -f "/root/shift-left/app.sh" ]; then
    cat << 'EOF' > /root/shift-left/app.sh
#!/bin/sh
echo "=========================================================="
echo "[Production Service] Starting payment gateway worker..."
echo "[Production Service] Environment: Production EU-West"
echo "=========================================================="
while true; do
    echo "[$(date)] Service healthy. Waiting for queue messages..."
    sleep 30
done
EOF
fi
chmod 755 /root/shift-left/app.sh

if [ ! -f "/root/shift-left/Dockerfile.vulnerable" ]; then
    cat << 'EOF' > /root/shift-left/Dockerfile.vulnerable
FROM alpine:3.15
# Vulnerable base image with known CVEs, hardcoded production secrets, runs as root

# Secretos incrustados en la imagen (Mala práctica crítica en Supply Chain)
ENV PROD_DB_PASSWORD="Turing_Prod_P@ssw0rd_9921!"
ENV PAYMENT_API_KEY="sk_live_51M0AlanTuringCyberKeySuperSecret_X99"

RUN apk update && apk add --no-cache curl wget bash

WORKDIR /app
COPY app.sh /app/app.sh
RUN chmod +x /app/app.sh

CMD ["/app/app.sh"]
EOF
fi

# Build and push the vulnerable service image to local registry
echo "[DOCKER] Building and publishing vulnerable image to local registry..."
docker build -t localhost:5000/victim-service:v1.0 -f /root/shift-left/Dockerfile.vulnerable /root/shift-left
docker push localhost:5000/victim-service:v1.0

# Pre-pull secure base image for instant student builds
docker pull alpine:3.20 >/dev/null 2>&1 || true

# 7. Setup scoring engine and verification scripts
if [ -f "${SCRIPT_DIR}/step5/verify.sh" ]; then
    cp "${SCRIPT_DIR}/step5/verify.sh" /step5/verify.sh
fi
chmod 755 /step5/verify.sh 2>/dev/null || true

if [ -d "${SCRIPT_DIR}/assets/scoring" ]; then
    cp -ru "${SCRIPT_DIR}/assets/scoring/"* /assets/scoring/ 2>/dev/null || true
fi

# Ensure scoring binaries in PATH
cp /assets/scoring/score_client.sh /usr/local/bin/score 2>/dev/null || true
cp /assets/scoring/score_client.sh /usr/local/bin/score_client.sh 2>/dev/null || true
cp /assets/scoring/hint.sh /usr/local/bin/hint 2>/dev/null || true
chmod 755 /usr/local/bin/score /usr/local/bin/score_client.sh /usr/local/bin/hint 2>/dev/null || true

# Recovery fallback from raw GitHub if files missing
if [ ! -f "/assets/scoring/score_client.sh" ]; then
    curl -sSf https://raw.githubusercontent.com/RickyAllitt/Taller-Alan-Turing/master/devsecops-dfir-part3/assets/scoring/config.env -o /assets/scoring/config.env 2>/dev/null || true
    curl -sSf https://raw.githubusercontent.com/RickyAllitt/Taller-Alan-Turing/master/devsecops-dfir-part3/assets/scoring/score_client.sh -o /assets/scoring/score_client.sh 2>/dev/null || true
    curl -sSf https://raw.githubusercontent.com/RickyAllitt/Taller-Alan-Turing/master/devsecops-dfir-part3/assets/scoring/hint.sh -o /assets/scoring/hint.sh 2>/dev/null || true
    chmod 755 /assets/scoring/score_client.sh /assets/scoring/hint.sh 2>/dev/null || true
    cp /assets/scoring/score_client.sh /usr/local/bin/score 2>/dev/null || true
    cp /assets/scoring/score_client.sh /usr/local/bin/score_client.sh 2>/dev/null || true
    cp /assets/scoring/hint.sh /usr/local/bin/hint 2>/dev/null || true
fi

# Success marker
touch /tmp/killercoda_ready
echo "[$(date '+%Y-%m-%d %I:%M:%S %p')] [INIT] Killercoda background setup (Parte 3) completed successfully."
