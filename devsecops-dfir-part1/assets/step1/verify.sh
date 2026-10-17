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
    echo -e "${RED}[FALLO] Archivo de flag no encontrado: ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[PISTA] Accede al contenedor con 'docker exec -it cicd_runner_pipeline sh', inspecciona '/proc/1/environ' buscando DEPLOY_PRODUCTION_KEY y guarda la flag en /tmp/flag1.txt en el host.${NC}"
    exit 1
fi

# Dynamically query PID 1 process memory inside the running victim container
EXPECTED_FLAG=$(docker exec cicd_runner_pipeline sh -c "tr '\0' '\n' < /proc/1/environ 2>/dev/null | grep '^DEPLOY_PRODUCTION_KEY=' | cut -d= -f2-" 2>/dev/null)

if [ -z "${EXPECTED_FLAG}" ]; then
    echo -e "${RED}[ERROR] No se pudo extraer el secreto dinámico del entorno de PID 1 en cicd_runner_pipeline.${NC}"
    echo -e "${YELLOW}[INFO] Asegúrate de que el contenedor esté activo: docker compose -f /assets/docker-compose.yml up -d${NC}"
    exit 1
fi

SUBMITTED_FLAG=$(grep -o "FLAG{[^}]*}" "${FLAG_FILE}" 2>/dev/null || cat "${FLAG_FILE}" | tr -d '[:space:]')

if [ "${SUBMITTED_FLAG}" = "${EXPECTED_FLAG}" ]; then
    echo -e "${GREEN}[ÉXITO] ¡Desafío 1 Completado!${NC}"
    echo -e "${GREEN}[✔] Secreto del pipeline extraído con éxito de /proc/1/environ: ${EXPECTED_FLAG}${NC}"
    if [ -x "/usr/local/bin/score_client.sh" ]; then
        /usr/local/bin/score_client.sh complete 1 200
    elif [ -f "/assets/scoring/score_client.sh" ]; then
        bash /assets/scoring/score_client.sh complete 1 200
    fi
    exit 0
else
    echo -e "${RED}[FALLO] Flag incorrecta en ${FLAG_FILE}${NC}"
    echo -e "${YELLOW}[PISTA] Encontrado: '${SUBMITTED_FLAG}'. Formato esperado: FLAG{proc_harvest_...}. Revisa las cadenas de memoria de PID 1 en cicd_runner_pipeline.${NC}"
    exit 1
fi
