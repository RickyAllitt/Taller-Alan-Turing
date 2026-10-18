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

# Check if forensic sample has been extracted from OverlayFS UpperDir
if [ ! -f "${TARGET_SAMPLE}" ]; then
    echo -e "${RED}[FALLO] Muestra forense no encontrada en: ${TARGET_SAMPLE}${NC}"
    echo -e "${YELLOW}[PISTA] Debes localizar el implante dentro de la capa mutable (UpperDir) del contenedor cicd_runner_pipeline mediante 'docker inspect' y copiarlo a /evidence/backdoor_implant.sh antes de formular tu regla YARA.${NC}"
    exit 1
fi

# Ensure yara tool is installed
if ! command -v yara >/dev/null 2>&1; then
    echo -e "${YELLOW}[INFO] YARA no encontrado en PATH, intentando instalar...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y && apt-get install -y --no-install-recommends yara || true
    if ! command -v yara >/dev/null 2>&1; then
        echo -e "${RED}[FALLO] El comando yara no está disponible. Instálalo con 'apt-get install -y yara'.${NC}"
        exit 1
    fi
fi

# 1. Check if YARA rule file exists
if [ ! -f "${YARA_RULE}" ]; then
    echo -e "${RED}[FALLO] Archivo de regla YARA no encontrado: ${YARA_RULE}${NC}"
    echo -e "${YELLOW}[PISTA] Crea tu regla YARA en /evidence/detect_implant.yar identificando la URL del C2 y el comentario de exfiltración.${NC}"
    exit 1
fi

# 2. Syntax validation and test scan
echo -e "${CYAN}[ESCÁNER] Ejecutando YARA contra la muestra forense objetivo...${NC}"
YARA_OUTPUT=$(yara "${YARA_RULE}" "${TARGET_SAMPLE}" 2>&1)
YARA_EXIT_CODE=$?

if [ ${YARA_EXIT_CODE} -ne 0 ]; then
    echo -e "${RED}[FALLO] La ejecución de YARA falló con código de salida ${YARA_EXIT_CODE}.${NC}"
    echo -e "${RED}Salida de error de YARA:${NC}\n${YARA_OUTPUT}"
    echo -e "${YELLOW}[PISTA] Revisa la sintaxis de tu regla (nombre de la regla, strings, condition).${NC}"
    exit 1
fi

# 3. Check for matching output
if [ -z "${YARA_OUTPUT}" ]; then
    echo -e "${RED}[FALLO] La regla YARA compiló correctamente, pero NO se detectaron coincidencias en ${TARGET_SAMPLE}.${NC}"
    echo -e "${YELLOW}[PISTA] Asegúrate de que los patrones de strings coincidan con los indicadores del implante:"
    echo -e "       - 'http://evil-c2.attacker.internal'"
    echo -e "       - '# Malicious Exfiltration Hook'${NC}"
    exit 1
fi

# 4. Check that target indicators are referenced in the rule file
if ! grep -qi "evil-c2.attacker.internal" "${YARA_RULE}" && ! grep -qi "Malicious Exfiltration Hook" "${YARA_RULE}"; then
    echo -e "${RED}[FALLO] La regla YARA no parece inspeccionar el dominio de C2 específico ni la cabecera del hook.${NC}"
    echo -e "${YELLOW}[PISTA] Incluye cadenas en la regla para 'http://evil-c2.attacker.internal' o '# Malicious Exfiltration Hook'.${NC}"
    exit 1
fi

echo -e "${GREEN}[ÉXITO] ¡Desafío 3 Completado!${NC}"
echo -e "${GREEN}[✔] ¡La regla YARA detectó con éxito el artefacto malicioso!${NC}"
echo -e "${CYAN}${YARA_OUTPUT}${NC}"
if [ -x "/usr/local/bin/score_client.sh" ]; then
    /usr/local/bin/score_client.sh complete 3 300
elif [ -f "/assets/scoring/score_client.sh" ]; then
    bash /assets/scoring/score_client.sh complete 3 300
fi
exit 0
