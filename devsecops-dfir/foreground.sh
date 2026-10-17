#!/bin/bash
# ==============================================================================
# Killercoda Foreground Script with Cyber Range Registration
# DevSecOps & Container DFIR Workshop - CPIFP Alan Turing
# ==============================================================================

# Clear terminal screen
clear

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

cat << "EOF"
================================================================================
  ____             ____               ___              
 |  _ \  _____   _/ ___|  ___  ___   / _ \ _ __  ___   
 | | | |/ _ \ \ / /\___ \ / _ \/ __| | | | | '_ \/ __|  
 | |_| |  __/\ V /  ___) |  __/ (__  | |_| | |_) \__ \  
 |____/ \___| \_/  |____/ \___|\___|  \___/| .__/|___/  
                                           |_|          
   ____  _____ ___ ____    _     _ _                    
  |  _ \|  ___|_ _|  _ \  | |   (_) |__                 
  | | | | |_   | || |_) | | |   | | '_ \                
  | |_| |  _|  | ||  _ <  | |___| | |_) |               
  |____/|_|   |___|_| \_\ |_____|_|_.__/                
                                                        
 DevSecOps & DFIR Workshop - CPIFP Alan Turing (Málaga)
 Scenario: Supply Chain Poisoning, Container Breakouts & Production Hardening
================================================================================
EOF

echo -e "${CYAN}Initializing workshop environment...${NC}\n"

# Spinner animation while background.sh finishes provisioning
spin='-\|/'
i=0
TIMEOUT=180
ELAPSED=0

while [ ! -f /tmp/killercoda_ready ]; do
    if [ -f /tmp/killercoda_failed ]; then
        printf "\r${RED}[✘] Initialization failed!                                                       ${NC}\n\n"
        echo -e "${BOLD}${RED}Initialization failed. Run 'cat /var/log/killercoda_background.log' to inspect the error.${NC}\n"
        exit 1
    fi

    if [ ${ELAPSED} -ge ${TIMEOUT} ]; then
        printf "\r${RED}[✘] Initialization timed out after ${TIMEOUT} seconds!                           ${NC}\n\n"
        echo -e "${BOLD}${RED}Initialization failed. Run 'cat /var/log/killercoda_background.log' to inspect the error.${NC}\n"
        exit 1
    fi

    i=$(( (i+1) % 4 ))
    printf "\r${YELLOW}[%c] Setting up container environment, packages, and forensic artifacts...${NC}" "${spin:$i:1}"
    sleep 0.4
    ELAPSED=$((ELAPSED + 1))
done

printf "\r${GREEN}[✔] Provisioning complete! All systems operational.                                     ${NC}\n\n"

# Ensure score and hint command binaries exist in system PATH
mkdir -p /usr/local/bin
for candidate in \
    "/usr/local/bin/score_client.sh" \
    "/assets/scoring/score_client.sh" \
    "/scoring/score_client.sh" \
    "/root/assets/scoring/score_client.sh"; do
    if [ -f "${candidate}" ]; then
        cp -u "${candidate}" /usr/local/bin/score 2>/dev/null || cp "${candidate}" /usr/local/bin/score
        cp -u "${candidate}" /usr/local/bin/score_client.sh 2>/dev/null || cp "${candidate}" /usr/local/bin/score_client.sh
        chmod 755 /usr/local/bin/score /usr/local/bin/score_client.sh
        break
    fi
done

for candidate in \
    "/usr/local/bin/hint" \
    "/assets/scoring/hint.sh" \
    "/scoring/hint.sh" \
    "/root/assets/scoring/hint.sh"; do
    if [ -f "${candidate}" ]; then
        cp -u "${candidate}" /usr/local/bin/hint 2>/dev/null || cp "${candidate}" /usr/local/bin/hint
        chmod 755 /usr/local/bin/hint
        break
    fi
done

# Operative Registration for Live Leaderboard & Points System
if [ ! -f "/tmp/session_state.json" ]; then
    DEFAULT_ALIAS="operative-$RANDOM"
    if [ -x "/usr/local/bin/score" ]; then
        /usr/local/bin/score init "${DEFAULT_ALIAS}" >/dev/null 2>&1
    elif [ -x "/usr/local/bin/score_client.sh" ]; then
        /usr/local/bin/score_client.sh init "${DEFAULT_ALIAS}" >/dev/null 2>&1
    elif [ -f "/assets/scoring/score_client.sh" ]; then
        bash /assets/scoring/score_client.sh init "${DEFAULT_ALIAS}" >/dev/null 2>&1
    fi
fi

STUDENT_ALIAS=$(jq -r '.alias' /tmp/session_state.json 2>/dev/null || echo "operative")

echo ""
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo -e "${BOLD}${CYAN}                    CYBER RANGE SCOREBOARD REGISTRATION                         ${NC}"
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo -e "Initial handle assigned: ${BOLD}${GREEN}${STUDENT_ALIAS}${NC}"
echo ""
echo -e "To set your student name / call sign on the live cohort leaderboard, run:"
echo -e "  ${BOLD}${YELLOW}score register <your_name>${NC}"
echo ""
echo -e "Example:  ${CYAN}score register alberto-sec${NC}"
echo ""
echo -e "Leaderboard: ${CYAN}https://rickyallitt.github.io/Taller-Alan-Turing${NC}"
echo -e "Tactical Hints: Type '${YELLOW}hint <step>${NC}' (e.g. 'hint 1') for phased guidance."
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo ""
echo -e "${BOLD}${GREEN}Environment ready. Follow the engagement guide on the left!${NC}"
echo ""
