#!/bin/bash
# ==============================================================================
# Challenge 4 Verification Script: Production Container Hardening (DevSecOps)
# CPIFP Alan Turing - DevSecOps & Container DFIR Lab
# ==============================================================================

CONTAINER_NAME="cicd_runner_pipeline"
HARDENED_COMPOSE="/assets/docker-compose.hardened.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y jq >/dev/null 2>&1 || true
fi

echo -e "${BOLD}${CYAN}=== DevSecOps Container Hardening Audit ===${NC}\n"

# 1. Check if the container is currently running
RUNNING=$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || echo "false")
if [ "${RUNNING}" != "true" ]; then
    echo -e "${RED}[FAIL] Container '${CONTAINER_NAME}' is not running.${NC}"
    echo -e "${YELLOW}[HINT] Deploy your hardened compose file with:${NC}"
    echo -e "       docker compose -f /assets/docker-compose.hardened.yml up -d --force-recreate"
    exit 1
fi

INSPECT_JSON=$(docker inspect "${CONTAINER_NAME}")

FAILED_CHECKS=0

# Check 1: Privileged flag must be false
PRIVILEGED=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.Privileged')
if [ "${PRIVILEGED}" = "false" ]; then
    echo -e "${GREEN}[PASS] Control 1: Privileged mode disabled (.HostConfig.Privileged == false)${NC}"
else
    echo -e "${RED}[FAIL] Control 1: Container is running in privileged mode! (.HostConfig.Privileged == ${PRIVILEGED})${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 2: Docker socket mount must NOT be present
SOCKET_MOUNT=$(echo "${INSPECT_JSON}" | jq -r '.[0].Mounts[]? | select(.Source == "/var/run/docker.sock" or .Destination == "/var/run/docker.sock") | .Destination')
if [ -z "${SOCKET_MOUNT}" ]; then
    echo -e "${GREEN}[PASS] Control 2: Docker daemon socket mount eliminated${NC}"
else
    echo -e "${RED}[FAIL] Control 2: /var/run/docker.sock is still mounted inside the container!${NC}"
    echo -e "${YELLOW}       Remove '- /var/run/docker.sock:/var/run/docker.sock' from your volumes.${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 3: Read-only Root Filesystem must be enabled
READONLY_ROOTFS=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.ReadonlyRootfs')
if [ "${READONLY_ROOTFS}" = "true" ]; then
    echo -e "${GREEN}[PASS] Control 3: Read-only root filesystem active (.HostConfig.ReadonlyRootfs == true)${NC}"
else
    echo -e "${RED}[FAIL] Control 3: Root filesystem is writable! (.HostConfig.ReadonlyRootfs == ${READONLY_ROOTFS})${NC}"
    echo -e "${YELLOW}       Add 'read_only: true' to your service configuration.${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 4: Linux Capabilities dropped (ALL)
CAP_DROP=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.CapDrop // [] | any(. == "ALL" or . == "all")')
if [ "${CAP_DROP}" = "true" ]; then
    echo -e "${GREEN}[PASS] Control 4: Linux capabilities dropped (.HostConfig.CapDrop contains 'ALL')${NC}"
else
    echo -e "${RED}[FAIL] Control 4: Linux capabilities not dropped!${NC}"
    echo -e "${YELLOW}       Add 'cap_drop: [\"ALL\"]' to your service configuration.${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 5: Security option no-new-privileges must be true
SEC_OPT=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.SecurityOpt // [] | any(. == "no-new-privileges:true" or . == "no-new-privileges")')
if [ "${SEC_OPT}" = "true" ]; then
    echo -e "${GREEN}[PASS] Control 5: No-New-Privileges flag enforced${NC}"
else
    echo -e "${RED}[FAIL] Control 5: No-New-Privileges is missing!${NC}"
    echo -e "${YELLOW}       Add 'security_opt: [\"no-new-privileges:true\"]' to your service.${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 6: Non-root user configured
USER_ID=$(echo "${INSPECT_JSON}" | jq -r '.[0].Config.User')
if [ -n "${USER_ID}" ] && [ "${USER_ID}" != "root" ] && [ "${USER_ID}" != "0" ]; then
    echo -e "${GREEN}[PASS] Control 6: Running as non-root user (Config.User: ${USER_ID})${NC}"
else
    echo -e "${YELLOW}[WARN] Control 6: Container user is '${USER_ID}'. Recommended: user: \"10001:10001\"${NC}"
fi

# Check 7: Tmpfs configured for volatile storage
TMPFS_EXISTS=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.Tmpfs // {} | keys | any(. == "/tmp")')
if [ "${TMPFS_EXISTS}" = "true" ]; then
    echo -e "${GREEN}[PASS] Control 7: Tmpfs mount configured for /tmp${NC}"
else
    echo -e "${YELLOW}[WARN] Control 7: No tmpfs mount detected at /tmp. Recommended when using read_only: true.${NC}"
fi

echo ""
if [ ${FAILED_CHECKS} -eq 0 ]; then
    echo -e "${GREEN}${BOLD}[✔] All mandatory DevSecOps hardening controls PASSED successfully!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}[FAIL] ${FAILED_CHECKS} security control(s) failed validation. Review the recommendations above.${NC}"
    exit 1
fi
