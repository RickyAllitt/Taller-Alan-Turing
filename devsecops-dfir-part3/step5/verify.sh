#!/bin/bash
# ==============================================================================
# Challenge 5 Verification Hook: Shift-Left DevSecOps & Image Trust (Cosign + Trivy)
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
echo -e "${BOLD}${CYAN}[VALIDACIÓN] Desafío 5: Auditoría con Trivy y Firma con Cosign        ${NC}"
echo -e "${BOLD}${CYAN}======================================================================${NC}"

# 1. Comprobar que el registro local de Docker está operativo
echo -n "[1/6] Verificando conectividad con el registro local (localhost:5000)... "
if ! curl -sf http://localhost:5000/v2/ >/dev/null 2>&1; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}El registro local de Docker en localhost:5000 no responde.${NC}"
    echo -e "Asegúrate de que el contenedor 'registry' está iniciado ('docker start registry')."
    exit 1
fi
echo -e "${GREEN}[OK]${NC}"

# 2. Comprobar que la imagen 'localhost:5000/victim-service:hardened' ha sido creada y subida
IMAGE_REF="localhost:5000/victim-service:hardened"
echo -n "[2/6] Verificando imagen '${IMAGE_REF}' en el registro... "
TAGS_JSON=$(curl -sf http://localhost:5000/v2/victim-service/tags/list 2>/dev/null || echo "{}")
if ! echo "${TAGS_JSON}" | grep -q '"hardened"'; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}No se ha encontrado el tag 'hardened' en el registro local.${NC}"
    echo -e "Construye y sube la imagen al registro con:"
    echo -e "  docker build -t ${IMAGE_REF} -f Dockerfile.hardened ."
    echo -e "  docker push ${IMAGE_REF}"
    exit 1
fi
echo -e "${GREEN}[OK]${NC}"

# 3. Localizar clave pública de Cosign
echo -n "[3/6] Localizando clave pública de firma (cosign.pub)... "
COSIGN_PUB=""
for cand in "/root/shift-left/cosign.pub" "/root/cosign.pub" "$(pwd)/cosign.pub" "./cosign.pub"; do
    if [ -f "${cand}" ]; then
        COSIGN_PUB="${cand}"
        break
    fi
done

if [ -z "${COSIGN_PUB}" ]; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}No se encontró el archivo 'cosign.pub'.${NC}"
    echo -e "Genera tu par de claves con:"
    echo -e "  cd /root/shift-left && COSIGN_PASSWORD=\"\" cosign generate-key-pair"
    exit 1
fi
echo -e "${GREEN}[OK] (${COSIGN_PUB})${NC}"

# 4. Verificar la firma criptográfica con Cosign
echo -n "[4/6] Verificando firma criptográfica en el registro con Cosign... "
if ! cosign verify --key "${COSIGN_PUB}" "${IMAGE_REF}" >/tmp/cosign_verify.log 2>&1; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}La firma criptográfica no es válida o la imagen no ha sido firmada.${NC}"
    echo -e "Firma la imagen en el registro con:"
    echo -e "  COSIGN_PASSWORD=\"\" cosign sign --yes --key cosign.key ${IMAGE_REF}"
    cat /tmp/cosign_verify.log
    exit 1
fi
echo -e "${GREEN}[OK] (Firma válida confirmada)${NC}"

# 5. Escanear con Trivy: Cero vulnerabilidades críticas
echo -n "[5/6] Auditando vulnerabilidades con Trivy (filtro CRITICAL)... "
if ! trivy image --severity CRITICAL --exit-code 1 "${IMAGE_REF}" >/tmp/trivy_cve.log 2>&1; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}Trivy detectó vulnerabilidades CRÍTICAS en la imagen remediada.${NC}"
    echo -e "Revisa la imagen base en tu Dockerfile.hardened (ej. utiliza 'alpine:3.20' o 'alpine:latest')."
    grep -E "CRITICAL:" /tmp/trivy_cve.log | head -n 5 || cat /tmp/trivy_cve.log | head -n 15
    exit 1
fi
echo -e "${GREEN}[OK] (0 vulnerabilidades críticas)${NC}"

# 6. Escanear con Trivy: Cero secretos incrustados
echo -n "[6/6] Auditando filtración de secretos en capas con Trivy... "
if ! trivy image --scanners secret --exit-code 1 "${IMAGE_REF}" >/tmp/trivy_secrets.log 2>&1; then
    echo -e "${RED}[FALLO]${NC}"
    echo -e "${RED}Trivy detectó secretos o contraseñas incrustadas en las capas de la imagen.${NC}"
    echo -e "Elimina las variables de entorno de contraseñas (PROD_DB_PASSWORD, PAYMENT_API_KEY) de tu Dockerfile.hardened."
    cat /tmp/trivy_secrets.log | head -n 15
    exit 1
fi
echo -e "${GREEN}[OK] (0 secretos detectados)${NC}"

# Comprobar usuario no privilegiado
USER_CHECK=$(docker inspect "${IMAGE_REF}" --format '{{.Config.User}}' 2>/dev/null || true)
if [ -z "${USER_CHECK}" ] || [ "${USER_CHECK}" = "root" ] || [ "${USER_CHECK}" = "0" ]; then
    echo -e "${YELLOW}[AVISO] La imagen se ejecuta como root. Se recomienda definir un 'USER appuser' en producción.${NC}"
fi

echo ""
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}[✔] ¡VALIDACIÓN EXITOSA! Cadena de suministro securizada y firmada.    ${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}"

# Enviar telemetría al Leaderboard (+125 pts)
if [ -x "${SCORE_CLIENT}" ]; then
    bash "${SCORE_CLIENT}" complete 5 125
elif [ -x "/usr/local/bin/score" ]; then
    /usr/local/bin/score complete 5 125
fi
