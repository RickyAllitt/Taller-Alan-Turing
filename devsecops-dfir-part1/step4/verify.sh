#!/bin/bash
# ==============================================================================
# Challenge 4 Verification Script: Production Container Hardening (DevSecOps)
# CPIFP Alan Turing - DevSecOps & Container DFIR Lab
# ==============================================================================

CONTAINER_NAME="cicd_runner_pipeline"
HARDENED_COMPOSE="/assets/docker-compose.hardened.yml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 && apt-get install -y --no-install-recommends jq >/dev/null 2>&1 || true
fi

echo -e "${BOLD}${CYAN}=== Auditoría DevSecOps de Bastionado de Contenedores ===${NC}\n"

# 1. Check if the container is currently running
RUNNING=$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || echo "false")
if [ "${RUNNING}" != "true" ]; then
    echo -e "${RED}[FALLO] El contenedor '${CONTAINER_NAME}' no está en ejecución.${NC}"
    echo -e "${YELLOW}[PISTA] Despliega tu archivo compose bastionado con:${NC}"
    echo -e "       docker compose -f /assets/docker-compose.hardened.yml up -d --force-recreate"
    exit 1
fi

INSPECT_JSON=$(docker inspect "${CONTAINER_NAME}")

FAILED_CHECKS=0

# Check 1: Privileged flag must be false
PRIVILEGED=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.Privileged')
if [ "${PRIVILEGED}" = "false" ]; then
    echo -e "${GREEN}[ÉXITO] Control 1: Modo privilegiado deshabilitado (.HostConfig.Privileged == false)${NC}"
else
    echo -e "${RED}[FALLO] Control 1: ¡El contenedor se está ejecutando en modo privilegiado! (.HostConfig.Privileged == ${PRIVILEGED})${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 2: Docker socket mount must NOT be present
SOCKET_MOUNT=$(echo "${INSPECT_JSON}" | jq -r '.[0].Mounts[]? | select(.Source == "/var/run/docker.sock" or .Destination == "/var/run/docker.sock") | .Destination')
if [ -z "${SOCKET_MOUNT}" ]; then
    echo -e "${GREEN}[ÉXITO] Control 2: Montaje del socket del demonio Docker eliminado${NC}"
else
    echo -e "${RED}[FALLO] Control 2: ¡/var/run/docker.sock todavía está montado dentro del contenedor!${NC}"
    echo -e "${YELLOW}       Elimina '- /var/run/docker.sock:/var/run/docker.sock' de tus volúmenes.${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 3: Read-only Root Filesystem must be enabled
READONLY_ROOTFS=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.ReadonlyRootfs')
if [ "${READONLY_ROOTFS}" = "true" ]; then
    echo -e "${GREEN}[ÉXITO] Control 3: Sistema de ficheros raíz en sólo lectura activo (.HostConfig.ReadonlyRootfs == true)${NC}"
else
    echo -e "${RED}[FALLO] Control 3: ¡El sistema de ficheros raíz es modificable! (.HostConfig.ReadonlyRootfs == ${READONLY_ROOTFS})${NC}"
    echo -e "${YELLOW}       Añade 'read_only: true' a la configuración de tu servicio.${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 4: Linux Capabilities dropped (ALL)
CAP_DROP=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.CapDrop // [] | any(. == "ALL" or . == "all")')
if [ "${CAP_DROP}" = "true" ]; then
    echo -e "${GREEN}[ÉXITO] Control 4: Capacidades de Linux eliminadas (.HostConfig.CapDrop contiene 'ALL')${NC}"
else
    echo -e "${RED}[FALLO] Control 4: ¡Las capacidades de Linux no han sido eliminadas!${NC}"
    echo -e "${YELLOW}       Añade 'cap_drop: [\"ALL\"]' a la configuración de tu servicio.${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 5: Security option no-new-privileges must be true
SEC_OPT=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.SecurityOpt // [] | any(. == "no-new-privileges:true" or . == "no-new-privileges")')
if [ "${SEC_OPT}" = "true" ]; then
    echo -e "${GREEN}[ÉXITO] Control 5: Flag No-New-Privileges aplicada${NC}"
else
    echo -e "${RED}[FALLO] Control 5: ¡Falta la opción No-New-Privileges!${NC}"
    echo -e "${YELLOW}       Añade 'security_opt: [\"no-new-privileges:true\"]' a tu servicio.${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check 6: Non-root user configured
USER_ID=$(echo "${INSPECT_JSON}" | jq -r '.[0].Config.User')
if [ -n "${USER_ID}" ] && [ "${USER_ID}" != "root" ] && [ "${USER_ID}" != "0" ]; then
    echo -e "${GREEN}[ÉXITO] Control 6: Ejecutando como usuario no root (Config.User: ${USER_ID})${NC}"
else
    echo -e "${YELLOW}[AVISO] Control 6: El usuario del contenedor es '${USER_ID}'. Recomendado: user: \"10001:10001\"${NC}"
fi

# Check 7: Tmpfs configured for volatile storage
TMPFS_EXISTS=$(echo "${INSPECT_JSON}" | jq -r '.[0].HostConfig.Tmpfs // {} | keys | any(. == "/tmp")')
if [ "${TMPFS_EXISTS}" = "true" ]; then
    echo -e "${GREEN}[ÉXITO] Control 7: Montaje tmpfs configurado para /tmp${NC}"
else
    echo -e "${YELLOW}[AVISO] Control 7: No se detectó montaje tmpfs en /tmp. Recomendado al utilizar read_only: true.${NC}"
fi

echo ""
if [ ${FAILED_CHECKS} -eq 0 ]; then
    echo -e "${GREEN}${BOLD}[✔] ¡Todos los controles obligatorios de bastionado DevSecOps han sido SUPERADOS con éxito!${NC}"
    if [ -x "/usr/local/bin/score_client.sh" ]; then
        /usr/local/bin/score_client.sh complete 4 250
    elif [ -f "/assets/scoring/score_client.sh" ]; then
        bash /assets/scoring/score_client.sh complete 4 250
    fi
    exit 0
else
    echo -e "${RED}${BOLD}[FALLO] ${FAILED_CHECKS} control(es) de seguridad fallaron la validación. Revisa las recomendaciones anteriores.${NC}"
    exit 1
fi
