#!/bin/bash
# ==============================================================================
# Cyber Range Hint Engine CLI
# DevSecOps & Container DFIR Lab - CPIFP Alan Turing
# ==============================================================================

SCORE_CLIENT="/usr/local/bin/score_client.sh"
[ ! -f "${SCORE_CLIENT}" ] && SCORE_CLIENT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/score_client.sh"
[ ! -f "${SCORE_CLIENT}" ] && SCORE_CLIENT="/assets/scoring/score_client.sh"

STEP="${1:-}"

# Display usage
show_usage() {
    echo "======================================================================"
    echo "Sistema Táctico de Pistas - CPIFP Alan Turing"
    echo "======================================================================"
    echo "Uso: hint <numero_de_paso>"
    echo ""
    echo "Desafíos Disponibles:"
    echo "  hint 1  - Desafío 1: Memoria de Procesos y Extracción de Secretos"
    echo "  hint 2  - Desafío 2: Fuga de Contenedor vía Socket de Docker"
    echo "  hint 3  - Desafío 3: Triaje en OverlayFS y Caza de Amenazas con YARA"
    echo "  hint 4  - Desafío 4: Bastionado de Producción según CIS Benchmark"
    echo "  hint 5  - Desafío 5 (Bonus): Auditoría con Trivy y Firma con Cosign"
    echo "  hint 6  - Desafío 6 (Bonus): Puerta de Admisión Zero Trust"
    echo ""
    echo "Aviso: Desbloquear pistas restará puntos de tu puntuación final."
    echo "======================================================================"
    exit 0
}

[ -z "${STEP}" ] && show_usage

if ! [[ "${STEP}" =~ ^[1-6]$ ]]; then
    echo "Error: Paso '${STEP}' no válido. Debe ser entre 1 y 6."
    exit 1
fi

# Ensure score client exists
if [ ! -f "${SCORE_CLIENT}" ]; then
    echo "Error: Cliente de telemetría de puntuación no encontrado en ${SCORE_CLIENT}."
    exit 1
fi

prompt_unlock() {
    local step_num="$1"
    local tier_num="$2"
    local penalty="$3"
    local description="$4"

    # Check if previously unlocked
    if bash "${SCORE_CLIENT}" is_unlocked "${step_num}" "${tier_num}" >/dev/null 2>&1; then
        echo -e "\033[0;32m[DESBLOQUEADA] Pista ${tier_num} (Previamente revelada - 0 pts de deducción)\033[0m"
        echo -e "${description}"
        echo ""
        return 0
    fi

    # Check session state file directly
    local state_file="/tmp/session_state.json"
    if [ -f "${state_file}" ]; then
        local taken
        taken=$(jq -r ".challenges.step${step_num}.hintsTaken[]? | select(. == ${tier_num})" "${state_file}" 2>/dev/null)
        if [ -n "${taken}" ]; then
            echo -e "\033[0;32m[DESBLOQUEADA] Pista ${tier_num} (Previamente revelada - 0 pts de deducción)\033[0m"
            echo -e "${description}"
            echo ""
            return 0
        fi
    fi

    echo -e "\033[1;33m[BLOQUEADA] Pista ${tier_num} para el Desafío ${step_num} disponible.\033[0m"
    echo -e "\033[1;31mPenalización: -${penalty} puntos de la puntuación base del Desafío ${step_num}.\033[0m"
    echo -n "¿Deseas desbloquear esta pista? [s/N]: "
    read -r confirmation

    if [[ "${confirmation}" =~ ^[sSyY]([iIeE][sS]?)?$ ]]; then
        bash "${SCORE_CLIENT}" hint "${step_num}" "${tier_num}" "${penalty}"
        echo ""
        echo -e "\033[1;32m[DESBLOQUEADA] Pista ${tier_num} para el Desafío ${step_num}:\033[0m"
        echo -e "${description}"
        echo ""
    else
        echo -e "\033[0;33mAcción cancelada. Puntos preservados.\033[0m"
        echo ""
    fi
}

echo "======================================================================"
echo "Motor de Orientación Táctica - Desafío ${STEP}"
echo "======================================================================"

case "${STEP}" in
    1)
        echo "Desafío 1: Memoria de Procesos y Extracción de Secretos (Base: 200 pts)"
        echo ""
        prompt_unlock 1 1 25 \
            "Pista de Arquitectura: El kernel de Linux genera /proc/[PID]/environ a partir de la memoria del proceso.\nAunque las subshells y sesiones exec se ejecutan con entornos separados y saneados,\nel PID 1 (supervisor del contenedor) conserva el bloque original de inicialización."
        prompt_unlock 1 2 50 \
            "Pista de Manipulación de Flujo: Las entradas en /proc/[PID]/environ están separadas por bytes nulos (\x00).\nLas utilidades de texto convencionales fallan con flujos nulos. Usa 'tr' para convertir bytes nulos a saltos de línea:\n  tr '\0' '\n' < /proc/1/environ\nO extrae secuencias imprimibles con 'strings /proc/1/environ'."
        ;;
    2)
        echo "Desafío 2: Fuga de Contenedor vía Socket de Docker (Base: 250 pts)"
        echo ""
        prompt_unlock 2 1 30 \
            "Pista del Modelo de Privilegios: /var/run/docker.sock comunica directamente con el demonio dockerd del host.\nEl demonio del host ejecuta todas las acciones de la API como root (UID 0) en el kernel anfitrión,\nbypaseando los espacios de nombres y límites de cgroups del contenedor."
        prompt_unlock 2 2 60 \
            "Pista de Sintaxis de Fuga: Desde el interior del contenedor, ejecuta la CLI local de docker para desplegar un contenedor\nauxiliar que monte el directorio raíz del host en una ruta secundaria:\n  docker run -v /:/mnt/host --rm -it alpine chroot /mnt/host sh\nEsto traslada tu contexto de ejecución raíz directamente al sistema de ficheros del host."
        ;;
    3)
        echo "Desafío 3: Triaje en OverlayFS y Caza de Amenazas con YARA (Base: 300 pts)"
        echo ""
        prompt_unlock 3 1 25 \
            "Pista del Controlador de Almacenamiento: Las modificaciones realizadas dentro del contenedor residen en el UpperDir del host.\nObtén la ruta ejecutando en el host:\n  docker inspect cicd_runner_pipeline | jq '.[0].GraphDriver.Data.UpperDir'\nExplora este directorio en el host con 'find' o audita /var/log/pipeline_audit/ en busca de implantes recientes."
        prompt_unlock 3 2 50 \
            "Pista de Análisis Estático: Analiza /evidence/backdoor_implant.sh.\nEl script contiene dos indicadores clave (IoCs):\n  1. Destino del C2: 'http://evil-c2.attacker.internal'\n  2. Cabecera identificativa: '# Malicious Exfiltration Hook'\nEvita términos genéricos como 'curl' o '#!/bin/sh' para no generar falsos positivos."
        prompt_unlock 3 3 75 \
            "Pista del Esqueleto YARA: Guarda tu regla en /evidence/detect_implant.yar:\n  rule Malicious_Exfiltration_Hook {\n      meta:\n          description = \"Detecta el hook malicioso de exfiltracion del pipeline\"\n      strings:\n          \$c2 = \"http://evil-c2.attacker.internal\"\n          \$hook = \"# Malicious Exfiltration Hook\"\n      condition:\n          \$c2 and \$hook\n  }"
        ;;
    4)
        echo "Desafío 4: Bastionado de Producción según CIS Benchmark (Base: 250 pts)"
        echo ""
        prompt_unlock 4 1 30 \
            "Remediaciones en Compose: En /assets/docker-compose.hardened.yml:\n  1. Elimina la entrada de volumen '- /var/run/docker.sock:/var/run/docker.sock'\n  2. Define usuario sin privilegios: user: \"10001:10001\"\n  3. Habilita el sistema de ficheros de sólo lectura: read_only: true"
        prompt_unlock 4 2 60 \
            "Directivas de Privilegios y Almacenamiento:\n  4. Elimina capacidades del kernel: cap_drop: [\"ALL\"]\n  5. Bloquea escaladas de privilegios: security_opt: [\"no-new-privileges:true\"]\n  6. Asigna almacenamiento volátil en memoria para /tmp:\n     tmpfs: [\"/tmp:rw,noexec,nosuid,size=64m\"]\nDespliega con: docker compose -f /assets/docker-compose.hardened.yml up -d --force-recreate"
        ;;
    5)
        echo "Desafío 5 (Bonus): Auditoría con Trivy y Firma con Cosign (Base: 125 pts)"
        echo ""
        prompt_unlock 5 1 25 \
            "Pista de Remediación: Revisa la base de la imagen en Dockerfile.hardened (usa 'alpine:3.20') y elimina las directivas ENV con contraseñas."
        prompt_unlock 5 2 50 \
            "Pista de Firma Cosign: Genera claves sin prompt interactivo con 'COSIGN_PASSWORD=\"\" cosign generate-key-pair'. Firma la imagen en localhost:5000/victim-service:hardened con 'cosign sign --yes --key cosign.key'."
        ;;
    6)
        echo "Desafío 6 (Bonus): Puerta de Admisión Zero Trust y Policy as Code (Base: 125 pts)"
        echo ""
        prompt_unlock 6 1 25 \
            "Pista de Verificación: Tu script /root/shift-left/admission_gate.sh debe comprobar 'cosign verify --key /root/shift-left/cosign.pub \"\$1\"'. Si falla, imprime rechazo y sal con código 1."
        prompt_unlock 6 2 50 \
            "Pista de Despliegue Bastionado: Si la firma y Trivy (trivy image --exit-code 1 --severity CRITICAL \"\$1\") pasan, arranca el contenedor con: 'docker run -d --name secure_production_service --read-only --user 10001:10001 --security-opt no-new-privileges:true --cap-drop ALL \"\$1\"'."
        ;;
esac

echo "======================================================================"
echo "Consejo: Ejecuta '/step${STEP}/verify.sh' para entregar tu solución y puntuar."
echo "======================================================================"
