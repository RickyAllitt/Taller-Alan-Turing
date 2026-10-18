#!/bin/bash
# ==============================================================================
# Challenge 6 Verification Hook: Admission Gate & Zero Trust Policy as Code
# Cyber Range CPIFP Alan Turing
# ==============================================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SCORE_CLIENT="/usr/local/bin/score_client.sh"
[ ! -f "${SCORE_CLIENT}" ] && SCORE_CLIENT="/assets/scoring/score_client.sh"
[ ! -f "${SCORE_CLIENT}" ] && SCORE_CLIENT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../assets/scoring" && pwd)/score_client.sh"

echo -e "${BOLD}${CYAN}======================================================================${NC}"
echo -e "${BOLD}${CYAN}[VALIDACIÓN] Desafío 6: Puerta de Admisión y Despliegue Zero Trust     ${NC}"
echo -e "${BOLD}${CYAN}======================================================================${NC}"

GATE_SCRIPT="/root/shift-left/admission_gate.sh"
VULN_IMAGE="localhost:5000/victim-service:v1.0"
CLEAN_IMAGE="localhost:5000/victim-service:hardened"
CONTAINER_NAME="secure_production_service"

# 1. Verificar existencia y permisos de ejecucion del script de admision
echo -n "[1/5] Verificando script de puerta de admisión (/root/shift-left/admission_gate.sh)... "
if [ ! -f "${GATE_SCRIPT}" ]; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}No se encontró el script '${GATE_SCRIPT}'.${NC}"
    echo -e "Crea tu script de admisión automatizada en esa ruta y dale permisos de ejecución ('chmod +x')."
    exit 1
fi

if [ ! -x "${GATE_SCRIPT}" ]; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}El archivo '${GATE_SCRIPT}' no tiene permisos de ejecución.${NC}"
    echo -e "Ejecuta: chmod +x ${GATE_SCRIPT}"
    exit 1
fi
echo -e "${GREEN}[OK]${NC}"

# 2. Prueba de rechazo: Intentar desplegar imagen no firmada y vulnerable
echo -n "[2/5] Evaluando política de denegación con imagen no confiable (${VULN_IMAGE})... "
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

set +e
"${GATE_SCRIPT}" "${VULN_IMAGE}" >/tmp/gate_rejection_test.log 2>&1
REJECT_EXIT=$?
set -e

if [ ${REJECT_EXIT} -eq 0 ]; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}La puerta de admisión PERMITIÓ el despliegue de una imagen no firmada y con vulnerabilidades críticas.${NC}"
    echo -e "Tu script debe verificar 'cosign verify' y 'trivy image', retornando un código de error distinto de 0 ante cualquier fallo."
    cat /tmp/gate_rejection_test.log | tail -n 10
    exit 1
fi

# Verificar que la imagen rechazada no arranco en produccion
RUNNING_IMAGE=$(docker inspect "${CONTAINER_NAME}" --format '{{.Config.Image}}' 2>/dev/null || true)
if [ "${RUNNING_IMAGE}" = "${VULN_IMAGE}" ]; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}El contenedor '${CONTAINER_NAME}' fue arrancado a pesar del rechazo.${NC}"
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    exit 1
fi
echo -e "${GREEN}[OK] (Rechazado correctamente con código ${REJECT_EXIT})${NC}"

# 3. Prueba de aprobación: Desplegar imagen firmada y remediada
echo -n "[3/5] Evaluando política de aprobación con artefacto verificado (${CLEAN_IMAGE})... "
set +e
"${GATE_SCRIPT}" "${CLEAN_IMAGE}" >/tmp/gate_approval_test.log 2>&1
APPROVE_EXIT=$?
set -e

if [ ${APPROVE_EXIT} -ne 0 ]; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}La puerta de admisión DENEGÓ el despliegue de la imagen legítima y firmada.${NC}"
    echo -e "Revisa los logs de validación:"
    cat /tmp/gate_approval_test.log | tail -n 15
    exit 1
fi
echo -e "${GREEN}[OK] (Aprobado y ejecutado con éxito)${NC}"

# 4. Verificar estado activo del contenedor productivo
echo -n "[4/5] Verificando ejecución activa del contenedor '${CONTAINER_NAME}'... "
if ! docker ps --format '{{.Names}}' | grep -qw "${CONTAINER_NAME}"; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}El contenedor '${CONTAINER_NAME}' no está en ejecución.${NC}"
    echo -e "Asegúrate de que 'admission_gate.sh' arranca el contenedor con 'docker run -d --name ${CONTAINER_NAME} ...'."
    exit 1
fi
echo -e "${GREEN}[OK]${NC}"

# 5. Comprobar controles CIS de hardening en tiempo de ejecución
echo -n "[5/5] Auditando directivas de bastionado en tiempo de ejecución... "
READONLY_FS=$(docker inspect "${CONTAINER_NAME}" --format '{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null || true)
SEC_OPTS=$(docker inspect "${CONTAINER_NAME}" --format '{{json .HostConfig.SecurityOpt}}' 2>/dev/null || true)
CAP_DROP=$(docker inspect "${CONTAINER_NAME}" --format '{{json .HostConfig.CapDrop}}' 2>/dev/null || true)
CONTAINER_USER=$(docker inspect "${CONTAINER_NAME}" --format '{{.Config.User}}' 2>/dev/null || true)

ERRORS=0

if [ "${READONLY_FS}" != "true" ]; then
    echo ""
    echo -e "${RED}  - Control 1: Falta '--read-only'. El sistema de ficheros raíz no es de solo lectura.${NC}"
    ERRORS=$((ERRORS + 1))
fi

if ! echo "${SEC_OPTS}" | grep -qi "no-new-privileges"; then
    echo ""
    echo -e "${RED}  - Control 2: Falta '--security-opt no-new-privileges:true'. Escalada SUID/SGID permitida.${NC}"
    ERRORS=$((ERRORS + 1))
fi

if ! echo "${CAP_DROP}" | grep -qi "all"; then
    echo ""
    echo -e "${RED}  - Control 3: Falta '--cap-drop ALL'. Capacidades del kernel no restringidas.${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -z "${CONTAINER_USER}" ] || [ "${CONTAINER_USER}" = "root" ] || [ "${CONTAINER_USER}" = "0" ]; then
    echo ""
    echo -e "${RED}  - Control 4: Falta usuario no privilegiado (ej. '--user 10001:10001' o directiva USER en Dockerfile).${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ ${ERRORS} -gt 0 ]; then
    echo -e "${RED}[FALLO] Se detectaron ${ERRORS} desviaciones de seguridad en el contenedor en producción.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] (Zero Trust runtime enforce confirmado)${NC}"

echo ""
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}[✔] ¡VALIDACIÓN EXITOSA! Puerta de admisión y política Zero Trust 100%.${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}"

# Enviar telemetría al Leaderboard (+125 pts)
if [ -x "${SCORE_CLIENT}" ]; then
    bash "${SCORE_CLIENT}" complete 6 125
elif [ -x "/usr/local/bin/score" ]; then
    /usr/local/bin/score complete 6 125
fi
