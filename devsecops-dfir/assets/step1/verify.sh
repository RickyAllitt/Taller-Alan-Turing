#!/bin/bash
# ==============================================================================
# Challenge 1 Verification Script: Poisoned Pipeline Execution & Secret Harvesting
# CPIFP Alan Turing - DevSecOps & Container DFIR Lab
# ==============================================================================

FLAG_FILE="/tmp/flag1.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "${FLAG_FILE}" ]; then
    echo -e "${RED}[FAIL] Flag file not found: ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[HINT] Enter the container with 'docker exec -it cicd_runner_pipeline sh', inspect '/proc/1/environ' for DEPLOY_PRODUCTION_KEY, and save the flag into /tmp/flag1.txt on the host.${NC}"
    exit 1
fi

# Dynamically query PID 1 process memory inside the running victim container
EXPECTED_FLAG=$(docker exec cicd_runner_pipeline sh -c "tr '\0' '\n' < /proc/1/environ 2>/dev/null | grep '^DEPLOY_PRODUCTION_KEY=' | cut -d= -f2-" 2>/dev/null)

if [ -z "${EXPECTED_FLAG}" ]; then
    echo -e "${RED}[ERROR] Unable to extract dynamic secret from cicd_runner_pipeline PID 1 environment.${NC}"
    echo -e "${YELLOW}[INFO] Ensure container is active: docker compose -f /assets/docker-compose.yml up -d${NC}"
    exit 1
fi

SUBMITTED_FLAG=$(grep -o "FLAG{[^}]*}" "${FLAG_FILE}" 2>/dev/null || cat "${FLAG_FILE}" | tr -d '[:space:]')

if [ "${SUBMITTED_FLAG}" = "${EXPECTED_FLAG}" ]; then
    echo -e "${GREEN}[PASS] Challenge 1 Complete!${NC}"
    echo -e "${GREEN}[✔] Successfully harvested pipeline secret from /proc/1/environ: ${EXPECTED_FLAG}${NC}"
    if [ -x "/usr/local/bin/score_client.sh" ]; then
        /usr/local/bin/score_client.sh complete 1 200
    elif [ -f "/assets/scoring/score_client.sh" ]; then
        bash /assets/scoring/score_client.sh complete 1 200
    fi
    exit 0
else
    echo -e "${RED}[FAIL] Incorrect flag in ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[HINT] Found: '${SUBMITTED_FLAG}'. Expected dynamic flag format: FLAG{proc_harvest_...}. Check PID 1 environment strings inside cicd_runner_pipeline.${NC}"
    exit 1
fi
