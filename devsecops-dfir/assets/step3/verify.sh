#!/bin/bash
# ==============================================================================
# Challenge 3 Verification Script: DFIR Triage & YARA Threat Hunting
# CPIFP Alan Turing - DevSecOps & Container DFIR Lab
# ==============================================================================

YARA_RULE="/evidence/detect_implant.yar"
TARGET_SAMPLE="/evidence/backdoor_implant.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ensure sample exists
if [ ! -f "${TARGET_SAMPLE}" ]; then
    if [ -f "/assets/evidence/backdoor_implant.sh" ]; then
        mkdir -p /evidence
        cp /assets/evidence/backdoor_implant.sh "${TARGET_SAMPLE}"
        chmod 755 "${TARGET_SAMPLE}"
    else
        echo -e "${RED}[ERROR] Target forensic sample missing: ${TARGET_SAMPLE}${NC}"
        exit 1
    fi
fi

# Ensure yara tool is installed
if ! command -v yara >/dev/null 2>&1; then
    echo -e "${YELLOW}[INFO] YARA not found in PATH, attempting to install...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y && apt-get install -y --no-install-recommends yara || true
    if ! command -v yara >/dev/null 2>&1; then
        echo -e "${RED}[FAIL] yara command is not available. Please install with 'apt-get install -y yara'.${NC}"
        exit 1
    fi
fi

# 1. Check if YARA rule file exists
if [ ! -f "${YARA_RULE}" ]; then
    echo -e "${RED}[FAIL] YARA rule file not found: ${YARA_RULE}${NC}"
    echo -e "${YELLOW}[HINT] Create your YARA rule in /evidence/detect_implant.yar targeting the C2 URL and exfiltration comment.${NC}"
    exit 1
fi

# 2. Syntax validation and test scan
echo -e "${CYAN}[SCAN] Executing YARA against target forensic sample...${NC}"
YARA_OUTPUT=$(yara "${YARA_RULE}" "${TARGET_SAMPLE}" 2>&1)
YARA_EXIT_CODE=$?

if [ ${YARA_EXIT_CODE} -ne 0 ]; then
    echo -e "${RED}[FAIL] YARA execution failed with exit code ${YARA_EXIT_CODE}.${NC}"
    echo -e "${RED}YARA Error Output:${NC}\n${YARA_OUTPUT}"
    echo -e "${YELLOW}[HINT] Check your rule syntax (rule name, strings, condition).${NC}"
    exit 1
fi

# 3. Check for matching output
if [ -z "${YARA_OUTPUT}" ]; then
    echo -e "${RED}[FAIL] YARA rule compiled successfully, but NO matches were detected on ${TARGET_SAMPLE}.${NC}"
    echo -e "${YELLOW}[HINT] Ensure your string patterns match the indicators in the implant:"
    echo -e "       - 'http://evil-c2.attacker.internal'"
    echo -e "       - '# Malicious Exfiltration Hook'${NC}"
    exit 1
fi

# 4. Check that target indicators are referenced in the rule file
if ! grep -qi "evil-c2.attacker.internal" "${YARA_RULE}" && ! grep -qi "Malicious Exfiltration Hook" "${YARA_RULE}"; then
    echo -e "${RED}[FAIL] The YARA rule does not appear to inspect the specific C2 domain or exfiltration hook strings.${NC}"
    echo -e "${YELLOW}[HINT] Include strings targeting 'http://evil-c2.attacker.internal' or '# Malicious Exfiltration Hook' in your rule.${NC}"
    exit 1
fi

echo -e "${GREEN}[PASS] Challenge 3 Complete!${NC}"
echo -e "${GREEN}[✔] YARA Rule successfully matched malicious artifact:${NC}"
echo -e "${CYAN}${YARA_OUTPUT}${NC}"
exit 0
