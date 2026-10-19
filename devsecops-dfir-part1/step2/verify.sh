#!/bin/bash
# ==============================================================================
# Challenge 2 Verification Script: Container Breakout via Docker Unix Socket
# CPIFP Alan Turing - DevSecOps & Container DFIR Lab
# ==============================================================================

FLAG_FILE="/tmp/flag2.txt"
HOST_FLAG_FILE="/root/.host_flag.txt"
if [ ! -f "${HOST_FLAG_FILE}" ] && [ -f "/root/host_flag.txt" ]; then
    HOST_FLAG_FILE="/root/host_flag.txt"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "${FLAG_FILE}" ]; then
    echo -e "${RED}[FALLO] Archivo de flag no encontrado: ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[PISTA] Desde dentro de cicd_runner_pipeline, aprovecha /var/run/docker.sock para ejecutar un contenedor que monte el sistema de ficheros del host (ej. 'docker run -v /:/mnt/host --rm alpine ls -la /mnt/host/root') y guarda la flag recuperada en /tmp/flag2.txt.${NC}"
    exit 1
fi

if [ ! -f "${HOST_FLAG_FILE}" ]; then
    echo -e "${RED}[ERROR] Falta el archivo objetivo en el host: ${HOST_FLAG_FILE}.${NC}"
    exit 1
fi

# Dynamically read the runtime generated root flag from host filesystem
EXPECTED_FLAG=$(cat "${HOST_FLAG_FILE}" 2>/dev/null | tr -d '[:space:]')

SUBMITTED_FLAG=$(grep -o "FLAG{[^}]*}" "${FLAG_FILE}" 2>/dev/null || cat "${FLAG_FILE}" | tr -d '[:space:]')

if [ -n "${EXPECTED_FLAG}" ] && [ "${SUBMITTED_FLAG}" = "${EXPECTED_FLAG}" ]; then
    echo -e "${GREEN}[ÉXITO] ¡Desafío 2 Completado!${NC}"
    echo -e "${GREEN}[✔] ¡Toma de control de root del host verificada! Flag: ${EXPECTED_FLAG}${NC}"
    if [ -x "/usr/local/bin/score_client.sh" ]; then
        /usr/local/bin/score_client.sh complete 2 250
    elif [ -f "/assets/scoring/score_client.sh" ]; then
        bash /assets/scoring/score_client.sh complete 2 250
    fi
    exit 0
else
    echo -e "${RED}[FALLO] Flag incorrecta en ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[PISTA] Encontrado: '${SUBMITTED_FLAG}'. Formato esperado: FLAG{dckr_sock_breakout_...}. Verifica la extracción de la flag de root vía /var/run/docker.sock.${NC}"
    exit 1
fi
