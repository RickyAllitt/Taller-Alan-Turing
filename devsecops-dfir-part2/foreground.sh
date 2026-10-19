#!/bin/bash
# ==============================================================================
# Killercoda Foreground Script with Cyber Range Registration
# DevSecOps & Container DFIR Workshop - CPIFP Alan Turing
# ==============================================================================

# Suppress terminal input echoing during setup
stty -echo 2>/dev/null || true

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}Inicializando entorno de laboratorio en segundo plano...${NC}"

# Spinner animation while background.sh finishes provisioning
spin='-\|/'
i=0
TIMEOUT=180
ELAPSED=0

while [ ! -f /tmp/killercoda_ready ]; do
    if [ -f /tmp/killercoda_failed ]; then
        printf "\r${RED}[✘] ¡Falló la inicialización del entorno!                                       ${NC}\n\n"
        echo -e "${BOLD}${RED}Revisa '/var/log/killercoda_background.log' para diagnosticar el fallo.${NC}\n"
        exit 1
    fi

    if [ ${ELAPSED} -ge ${TIMEOUT} ]; then
        printf "\r${RED}[✘] ¡Tiempo de espera agotado tras ${TIMEOUT} segundos!                       ${NC}\n\n"
        echo -e "${BOLD}${RED}Revisa '/var/log/killercoda_background.log' para diagnosticar el fallo.${NC}\n"
        exit 1
    fi

    i=$(( (i+1) % 4 ))
    printf "\r${YELLOW}[%c] Configurando contenedores, paquetes y artefactos forenses...${NC}" "${spin:$i:1}"
    sleep 0.4
    ELAPSED=$((ELAPSED + 1))
done

# Configure system timezone to Europe/Madrid (Spain local time)
timedatectl set-timezone Europe/Madrid 2>/dev/null || ln -fs /usr/share/zoneinfo/Europe/Madrid /etc/localtime 2>/dev/null || true
export TZ="Europe/Madrid"
echo 'export TZ="Europe/Madrid"' >> /etc/profile.d/timezone.sh 2>/dev/null || true
echo 'export TZ="Europe/Madrid"' >> /root/.bashrc 2>/dev/null || true

# Ensure score and hint command binaries exist in system PATH
mkdir -p /usr/local/bin /assets/scoring /usr/local/lib/docker/cli-plugins /usr/libexec/docker/cli-plugins

# Ensure both 'docker compose' and 'docker-compose' work seamlessly
if command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
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

# Fix Docker 26+ compatibility bug in legacy docker-compose v1 (KeyError: 'ContainerConfig')
for py_service in \
    "/usr/lib/python3/dist-packages/compose/service.py" \
    "/usr/local/lib/python3.*/dist-packages/compose/service.py"; do
    if [ -f "${py_service}" ]; then
        sed -i "s/container.image_config\['ContainerConfig'\]/(container.image_config.get('ContainerConfig') or container.image_config.get('Config') or {})/g" "${py_service}" 2>/dev/null || true
    fi
done
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

if [ ! -x "/usr/local/bin/score" ]; then
    curl -sSf https://raw.githubusercontent.com/RickyAllitt/Taller-Alan-Turing/master/devsecops-dfir-part2/assets/scoring/config.env -o /assets/scoring/config.env 2>/dev/null || true
    curl -sSf https://raw.githubusercontent.com/RickyAllitt/Taller-Alan-Turing/master/devsecops-dfir-part2/assets/scoring/score_client.sh -o /usr/local/bin/score 2>/dev/null || true
    chmod 755 /usr/local/bin/score 2>/dev/null || true
    cp /usr/local/bin/score /usr/local/bin/score_client.sh 2>/dev/null || true
    cp /usr/local/bin/score /assets/scoring/score_client.sh 2>/dev/null || true
fi

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

if [ ! -x "/usr/local/bin/hint" ]; then
    curl -sSf https://raw.githubusercontent.com/RickyAllitt/Taller-Alan-Turing/master/devsecops-dfir-part2/assets/scoring/hint.sh -o /usr/local/bin/hint 2>/dev/null || true
    chmod 755 /usr/local/bin/hint 2>/dev/null || true
    cp /usr/local/bin/hint /assets/scoring/hint.sh 2>/dev/null || true
fi

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

STUDENT_ALIAS=$(jq -r '.alias // "operative"' /tmp/session_state.json 2>/dev/null || echo "operative")
STUDENT_PIN=$(jq -r '.pin // "----"' /tmp/session_state.json 2>/dev/null || echo "----")

# ==============================================================================
# LIMPIEZA COMPLETA DE PANTALLA Y MUESTRA LIMPIA DEL BANNER Y BRIEFING
# ==============================================================================
clear

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

echo ""
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo -e "${BOLD}${CYAN}        CYBER RANGE: PARTE 2 (TRIAJE FORENSE Y BASTIONADO DEVSECOPS)            ${NC}"
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo -e "Indicativo de sesión: ${BOLD}${GREEN}${STUDENT_ALIAS}${NC} (PIN: ${BOLD}${YELLOW}${STUDENT_PIN}${NC})"
echo ""
echo -e "Para continuar con tu puntuación de la Parte 1, reanuda tu sesión con:"
echo -e "  ${BOLD}${YELLOW}score resume <tu_nombre_de_la_parte_1> <tu_pin>${NC}"
echo -e "  Ejemplo: ${CYAN}score resume alberto-sec 1234${NC}"
echo ""
echo -e "Marcador en Vivo: ${CYAN}https://rickyallitt.github.io/Taller-Alan-Turing${NC}"
echo -e "Pistas Tácticas:  Escribe '${YELLOW}hint 3${NC}' o '${YELLOW}hint 4${NC}' si necesitas orientación."
echo -e "${BOLD}${CYAN}================================================================================${NC}"
echo ""
echo -e "${BOLD}${GREEN}Entorno listo. ¡Sigue la guía del escenario a la izquierda!${NC}"
echo ""

# Restore terminal input echoing for the interactive user session
stty echo 2>/dev/null || true
