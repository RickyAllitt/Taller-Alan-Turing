#!/bin/bash
# ==============================================================================
# Challenge 1 Verification Script: Poisoned Pipeline Execution & Secret Harvesting
# CPIFP Alan Turing - DevSecOps & Container DFIR Lab
# ==============================================================================

FLAG_FILE="/tmp/flag1.txt"
EXPECTED_FLAG="FLAG{supply_chain_credential_leaked_proc_2026}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "${FLAG_FILE}" ]; then
    echo -e "${RED}[FAIL] Flag file not found: ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[HINT] Enter the container with 'docker exec -it cicd_runner_pipeline sh', inspect '/proc/1/environ' for DEPLOY_PRODUCTION_KEY, and save the flag into /tmp/flag1.txt on the host.${NC}"
    exit 1
fi

SUBMITTED_FLAG=$(grep -o "FLAG{[^}]*}" "${FLAG_FILE}" 2>/dev/null || cat "${FLAG_FILE}" | tr -d '[:space:]')

if [ "${SUBMITTED_FLAG}" = "${EXPECTED_FLAG}" ]; then
    echo -e "${GREEN}[PASS] Challenge 1 Complete!${NC}"
    echo -e "${GREEN}[✔] Successfully harvested pipeline secret from /proc/1/environ: ${EXPECTED_FLAG}${NC}"
    exit 0
else
    echo -e "${RED}[FAIL] Incorrect flag in ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[HINT] Found: '${SUBMITTED_FLAG}'. Expected format: FLAG{...}. Check PID 1 environment strings inside cicd_runner_pipeline.${NC}"
    exit 1
fi
