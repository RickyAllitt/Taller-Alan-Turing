#!/bin/bash
# ==============================================================================
# Killercoda Foreground Script
# DevSecOps & Container DFIR Workshop - CPIFP Alan Turing
# ==============================================================================

# Clear terminal screen
clear

CYAN='\033[0;36m'
GREEN='\033[0;32m'
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
while [ ! -f /tmp/killercoda_ready ]; do
    i=$(( (i+1) % 4 ))
    printf "\r${YELLOW}[%c] Setting up container environment, packages, and forensic artifacts...${NC}" "${spin:$i:1}"
    sleep 0.4
done

printf "\r${GREEN}[✔] Provisioning complete! All systems operational.                                     ${NC}\n\n"
echo -e "${BOLD}${GREEN}Environment ready. Follow the guide on the left!${NC}\n"
