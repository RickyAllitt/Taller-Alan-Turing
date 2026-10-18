#!/bin/bash
# ==============================================================================
# Cyber Range Scoring & Telemetry Client
# DevSecOps & Container DFIR Lab - CPIFP Alan Turing
# ==============================================================================

STATE_FILE="/tmp/session_state.json"
CONFIG_FILE="/assets/scoring/config.env"
[ ! -f "${CONFIG_FILE}" ] && CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.env"

# Load configuration with defaults
if [ -f "${CONFIG_FILE}" ]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi

FIREBASE_DATABASE_URL="${FIREBASE_DATABASE_URL:-https://bootcamp-ac825-default-rtdb.europe-west1.firebasedatabase.app}"
WORKSHOP_ID="${WORKSHOP_ID:-alan-turing-2026}"
LEADERBOARD_URL="${LEADERBOARD_URL:-https://rickyallitt.github.io/Taller-Alan-Turing}"

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 && apt-get install -y --no-install-recommends jq >/dev/null 2>&1 || true
fi

# Generate timestamp in Spanish local time (CET, 12-hour AM/PM)
get_spanish_timestamp() {
    date '+%Y-%m-%d %I:%M:%S %p'
}

# Compute SHA-256 hash of a string
get_hash() {
    local val="$1"
    echo -n "${val}" | sha256sum | cut -d' ' -f1
}

# Initialize student session
init_session() {
    local alias="${1:-}"
    local pin="${2:-}"
    if [ -z "${alias}" ]; then
        alias="operative-$(head -c 3 /dev/urandom | xxd -p 2>/dev/null || echo "$RANDOM")"
    fi

    # Sanitize alias: alphanumeric, hyphens, underscores only
    alias=$(echo "${alias}" | tr -cd 'a-zA-Z0-9_-' | cut -c 1-20)
    [ -z "${alias}" ] && alias="operative-$RANDOM"

    if [ -z "${pin}" ]; then
        pin=$(shuf -i 1000-9999 -n 1 2>/dev/null || echo $((1000 + RANDOM % 9000)))
    fi
    local pin_hash
    pin_hash=$(get_hash "${pin}")

    local rand_suffix
    rand_suffix=$(head -c 3 /dev/urandom | xxd -p 2>/dev/null || echo "$RANDOM")
    local student_id="student_${alias}_${rand_suffix}"
    local now
    now=$(get_spanish_timestamp)

    cat << EOF > "${STATE_FILE}"
{
  "studentId": "${student_id}",
  "alias": "${alias}",
  "pin": "${pin}",
  "pinHash": "${pin_hash}",
  "registeredAt": "${now}",
  "totalScore": 0,
  "completedChallenges": 0,
  "status": "in_progress",
  "challenges": {
    "step1": { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] },
    "step2": { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] },
    "step3": { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] },
    "step4": { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] },
    "step5": { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] },
    "step6": { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] }
  }
}
EOF
    chmod 666 "${STATE_FILE}" 2>/dev/null || true

    # Push registration payload to Firebase
    sync_to_firebase
}

# Verify state file exists, initialize if absent
ensure_session() {
    if [ ! -f "${STATE_FILE}" ]; then
        init_session "operative-$RANDOM"
    fi
}

# Push entire state to Firebase Realtime Database via REST
sync_to_firebase() {
    [ ! -f "${STATE_FILE}" ] && return 0
    local student_id
    student_id=$(jq -r '.studentId' "${STATE_FILE}" 2>/dev/null)
    [ -z "${student_id}" ] || [ "${student_id}" = "null" ] && return 0

    local endpoint="${FIREBASE_DATABASE_URL%/}/workshops/${WORKSHOP_ID}/students/${student_id}.json"

    # Non-blocking curl with short timeout so network latency never stalls the user
    curl -s --connect-timeout 4 --max-time 6 -X PUT \
        -H "Content-Type: application/json" \
        -d @"${STATE_FILE}" \
        "${endpoint}" > /tmp/scoring_sync.log 2>&1 || true
}

# Record consumed hint
# Arguments: <step_number 1..5> <tier_number 1..3> <penalty_points>
record_hint() {
    local step_num="$1"
    local tier_num="$2"
    local penalty="$3"

    ensure_session

    local step_key="step${step_num}"
    local already_taken
    already_taken=$(jq -r ".challenges.${step_key}.hintsTaken[]? | select(. == ${tier_num})" "${STATE_FILE}" 2>/dev/null)

    if [ -n "${already_taken}" ]; then
        return 0 # Already taken, no duplicate penalty
    fi

    # Update state: add hint to hintsTaken array
    local tmp_json
    tmp_json=$(jq ".challenges.${step_key}.hintsTaken += [${tier_num}]" "${STATE_FILE}")
    echo "${tmp_json}" > "${STATE_FILE}"

    sync_to_firebase
}

# Check if hint was already unlocked
is_hint_unlocked() {
    local step_num="$1"
    local tier_num="$2"
    ensure_session
    local step_key="step${step_num}"
    local exists
    exists=$(jq -r ".challenges.${step_key}.hintsTaken[]? | select(. == ${tier_num})" "${STATE_FILE}" 2>/dev/null)
    [ -n "${exists}" ]
}

# Complete challenge and award points
# Arguments: <step_number 1..5> <base_points>
complete_challenge() {
    local step_num="$1"
    local base_points="$2"
    ensure_session

    local step_key="step${step_num}"
    local already_done
    already_done=$(jq -r ".challenges.${step_key}.completed" "${STATE_FILE}" 2>/dev/null)

    if [ "${already_done}" = "true" ]; then
        echo -e "\033[0;33m[INFO] El reto ${step_num} ya fue puntuado anteriormente.\033[0m"
        return 0
    fi

    local now
    now=$(get_spanish_timestamp)

    # Calculate hint penalties for this step
    # Step 1: Tier 1: 25, Tier 2: 50
    # Step 2: Tier 1: 30, Tier 2: 60
    # Step 3: Tier 1: 25, Tier 2: 50, Tier 3: 75
    # Step 4: Tier 1: 30, Tier 2: 60
    # Step 5: Tier 1: 25, Tier 2: 50
    local penalty=0
    local hints_taken
    hints_taken=$(jq -c ".challenges.${step_key}.hintsTaken // []" "${STATE_FILE}" 2>/dev/null)

    for h in $(echo "${hints_taken}" | jq -r '.[]'); do
        case "${step_num}_${h}" in
            "1_1") penalty=$((penalty + 25)) ;;
            "1_2") penalty=$((penalty + 50)) ;;
            "2_1") penalty=$((penalty + 30)) ;;
            "2_2") penalty=$((penalty + 60)) ;;
            "3_1") penalty=$((penalty + 25)) ;;
            "3_2") penalty=$((penalty + 50)) ;;
            "3_3") penalty=$((penalty + 75)) ;;
            "4_1") penalty=$((penalty + 30)) ;;
            "4_2") penalty=$((penalty + 60)) ;;
            "5_1") penalty=$((penalty + 25)) ;;
            "5_2") penalty=$((penalty + 50)) ;;
            "6_1") penalty=$((penalty + 25)) ;;
            "6_2") penalty=$((penalty + 50)) ;;
        esac
    done

    local net_score=$((base_points - penalty))
    [ ${net_score} -lt 0 ] && net_score=0

    # Atomically update local state with step completion and total score
    local tmp_json
    tmp_json=$(jq \
        --arg completedAt "${now}" \
        --argjson score "${net_score}" \
        ".challenges.${step_key}.completed = true |
         .challenges.${step_key}.completedAt = \$completedAt |
         .challenges.${step_key}.score = \$score |
         .completedChallenges = ([.challenges[] | select(.completed == true)] | length) |
         .totalScore = ([.challenges[].score] | add) |
         .status = (if ([.challenges[] | select(.completed == true)] | length) >= 4 then \"completed\" else \"in_progress\" end)" \
        "${STATE_FILE}")

    echo "${tmp_json}" > "${STATE_FILE}"
    chmod 666 "${STATE_FILE}" 2>/dev/null || true

    sync_to_firebase

    local total_score
    total_score=$(jq -r '.totalScore' "${STATE_FILE}" 2>/dev/null)
    local completed_count
    completed_count=$(jq -r '.completedChallenges' "${STATE_FILE}" 2>/dev/null)
    local alias
    alias=$(jq -r '.alias' "${STATE_FILE}" 2>/dev/null)

    echo ""
    echo -e "\033[1;32m======================================================================\033[0m"
    echo -e "\033[1;32m[TELEMETRY] Reto ${step_num} superado: +${net_score} pts (Base: ${base_points}, Penalizaciones: -${penalty})\033[0m"
    echo -e "\033[1;36m[OPERATIVO] ${alias} | Puntuacion total: ${total_score} pts | Retos: ${completed_count}/4 $([ ${completed_count} -ge 5 ] && echo '(ELITE)')\033[0m"
    echo -e "\033[1;36m[FECHA] ${now} (Hora local Espana)\033[0m"
    echo -e "\033[1;33m[LEADERBOARD] Marcador en vivo: ${LEADERBOARD_URL}\033[0m"
    echo -e "\033[1;32m======================================================================\033[0m"
    echo ""
}

register_alias() {
    local new_alias="${1:-}"
    local input_pin="${2:-}"
    local mode="${3:-register}" # register or resume

    if [ -z "${new_alias}" ]; then
        echo -e "\033[1;33mUso: score register <tu_nombre> [pin_opcional]\033[0m"
        echo -e "\033[1;33mReanudar: score resume <tu_nombre> <tu_pin>\033[0m"
        echo -e "Ejemplo: score register alberto 1234"
        return 1
    fi

    # Sanitize alias: alphanumeric, hyphens, underscores only (2-20 characters)
    new_alias=$(echo "${new_alias}" | tr -cd 'a-zA-Z0-9_-' | cut -c 1-20)
    if [ ${#new_alias} -lt 2 ]; then
        echo -e "\033[1;31m[ERROR] El nombre debe tener entre 2 y 20 caracteres alfanumericos.\033[0m"
        return 1
    fi

    local current_student_id=""
    local current_alias=""
    local current_score=0
    if [ -f "${STATE_FILE}" ]; then
        current_student_id=$(jq -r '.studentId // ""' "${STATE_FILE}" 2>/dev/null)
        current_alias=$(jq -r '.alias // ""' "${STATE_FILE}" 2>/dev/null)
        current_score=$(jq -r '.totalScore // 0' "${STATE_FILE}" 2>/dev/null)
    fi

    # Query Firebase for existing record with this alias (case-insensitive)
    local existing_match
    existing_match=$(curl -s --connect-timeout 4 --max-time 6 "${FIREBASE_DATABASE_URL%/}/workshops/${WORKSHOP_ID}/students.json" 2>/dev/null | \
        jq -c --arg a "${new_alias}" 'to_entries | map(select((.value.alias | ascii_downcase) == ($a | ascii_downcase))) | sort_by(.value.totalScore // 0) | reverse | .[0] // empty' 2>/dev/null)

    # -------------------------------------------------------------
    # CASE 1: The alias already exists in the online database
    # -------------------------------------------------------------
    if [ -n "${existing_match}" ] && [ "${existing_match}" != "null" ]; then
        local existing_id
        existing_id=$(echo "${existing_match}" | jq -r '.key')
        local existing_val
        existing_val=$(echo "${existing_match}" | jq -c '.value')
        local existing_pin_hash
        existing_pin_hash=$(echo "${existing_match}" | jq -r '.value.pinHash // empty')

        # Check if already authenticated on this local machine
        if [ "${current_student_id}" = "${existing_id}" ]; then
            echo -e "\033[1;32m[INFO] Ya estas identificado como '${new_alias}' en esta maquina.\033[0m"
            show_status
            return 0
        fi

        # Check authentication / PIN
        local authenticated=false
        local assigned_pin=""

        if [ -z "${existing_pin_hash}" ]; then
            # Legacy session without PIN: allow claiming and set new PIN
            if [ -n "${input_pin}" ]; then
                assigned_pin="${input_pin}"
            else
                assigned_pin=$(shuf -i 1000-9999 -n 1 2>/dev/null || echo $((1000 + RANDOM % 9000)))
            fi
            authenticated=true
        else
            # Existing session has a PIN hash
            if [ -n "${input_pin}" ]; then
                local input_hash
                input_hash=$(get_hash "${input_pin}")
                if [ "${input_hash}" = "${existing_pin_hash}" ]; then
                    authenticated=true
                    assigned_pin="${input_pin}"
                fi
            fi
        fi

        if [ "${authenticated}" = "true" ]; then
            # Clean up temporary auto-generated session in Firebase if different
            if [ -n "${current_student_id}" ] && [ "${current_student_id}" != "${existing_id}" ]; then
                curl -s --connect-timeout 4 --max-time 6 -X DELETE "${FIREBASE_DATABASE_URL%/}/workshops/${WORKSHOP_ID}/students/${current_student_id}.json" >/dev/null 2>&1 || true
            fi

            # Clean up duplicate entries in Firebase for this alias
            local other_dup_ids
            other_dup_ids=$(curl -s --connect-timeout 4 --max-time 6 "${FIREBASE_DATABASE_URL%/}/workshops/${WORKSHOP_ID}/students.json" 2>/dev/null | \
                jq -r --arg a "${new_alias}" --arg keep "${existing_id}" 'to_entries | map(select((.value.alias | ascii_downcase) == ($a | ascii_downcase))) | sort_by(.value.totalScore // 0) | reverse | map(select(.key != $keep)) | .[].key' 2>/dev/null)
            for dup_id in ${other_dup_ids}; do
                if [ -n "${dup_id}" ] && [ "${dup_id}" != "null" ]; then
                    curl -s --connect-timeout 4 --max-time 6 -X DELETE "${FIREBASE_DATABASE_URL%/}/workshops/${WORKSHOP_ID}/students/${dup_id}.json" >/dev/null 2>&1 || true
                fi
            done

            local new_hash
            new_hash=$(get_hash "${assigned_pin}")

            # Restore existing session locally, ensuring step5 and updated pin/pinHash
            echo "${existing_val}" | jq \
                --arg p "${assigned_pin}" \
                --arg ph "${new_hash}" \
                '.pin = $p | .pinHash = $ph | .challenges.step5 = (.challenges.step5 // { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] }) | .challenges.step6 = (.challenges.step6 // { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] })' \
                > "${STATE_FILE}"
            chmod 666 "${STATE_FILE}" 2>/dev/null || true

            sync_to_firebase

            local cur_score
            cur_score=$(jq -r '.totalScore // 0' "${STATE_FILE}")
            local cur_done
            cur_done=$(jq -r '.completedChallenges // 0' "${STATE_FILE}")

            echo ""
            echo -e "\033[1;32m======================================================================\033[0m"
            echo -e "\033[1;32m[OK] Sesion vinculada con exito para: ${new_alias}\033[0m"
            echo -e "\033[1;36m[OK] Progreso restaurado: ${cur_score}/1000 pts | Retos completados: ${cur_done}/4\033[0m"
            echo -e "\033[1;36m[PIN] Tu PIN de recuperacion es: ${assigned_pin}\033[0m"
            echo -e "\033[1;33m[LEADERBOARD] Marcador en vivo: ${LEADERBOARD_URL}\033[0m"
            echo -e "\033[1;32m======================================================================\033[0m"
            echo ""
            return 0
        else
            # PIN incorrect or not provided
            echo ""
            echo -e "\033[1;31m======================================================================\033[0m"
            echo -e "\033[1;31m[ERROR] El alias '${new_alias}' ya esta registrado por otro estudiante.\033[0m"
            if [ -n "${input_pin}" ]; then
                echo -e "\033[1;31m[ERROR] El PIN introducido no coincide.\033[0m"
            fi
            echo ""
            echo -e "\033[1;33mSi eres el propietario de este alias y quieres reanudar tu sesion:\033[0m"
            echo -e "    score resume ${new_alias} <tu_pin>"
            echo ""
            echo -e "\033[1;33mSi eres un nuevo estudiante, elige otro nombre:\033[0m"
            echo -e "    score register ${new_alias}-2"
            echo -e "\033[1;31m======================================================================\033[0m"
            echo ""
            return 1
        fi
    fi

    # -------------------------------------------------------------
    # CASE 2: The alias does NOT exist in the database
    # -------------------------------------------------------------
    if [ "${mode}" = "resume" ]; then
        echo -e "\033[1;31m[ERROR] El alias '${new_alias}' no se encuentra en el marcador.\033[0m"
        echo -e "\033[1;33mPara registrarte por primera vez ejecuta:\033[0m"
        echo -e "    score register ${new_alias}"
        return 1
    fi

    # Assign PIN (either provided or generated)
    local assigned_pin="${input_pin}"
    if [ -z "${assigned_pin}" ]; then
        # Check if local state already has a pin
        if [ -f "${STATE_FILE}" ]; then
            assigned_pin=$(jq -r '.pin // empty' "${STATE_FILE}" 2>/dev/null)
        fi
        if [ -z "${assigned_pin}" ]; then
            assigned_pin=$(shuf -i 1000-9999 -n 1 2>/dev/null || echo $((1000 + RANDOM % 9000)))
        fi
    fi
    local assigned_hash
    assigned_hash=$(get_hash "${assigned_pin}")

    local rand_suffix
    rand_suffix=$(head -c 3 /dev/urandom | xxd -p 2>/dev/null || echo "$RANDOM")
    local new_student_id="student_${new_alias}_${rand_suffix}"

    if [ -f "${STATE_FILE}" ]; then
        local tmp_json
        tmp_json=$(jq \
            --arg a "${new_alias}" \
            --arg id "${new_student_id}" \
            --arg p "${assigned_pin}" \
            --arg ph "${assigned_hash}" \
            '.alias = $a | .studentId = $id | .pin = $p | .pinHash = $ph | .challenges.step5 = (.challenges.step5 // { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] }) | .challenges.step6 = (.challenges.step6 // { "completed": false, "score": 0, "completedAt": null, "hintsTaken": [] })' \
            "${STATE_FILE}")
        echo "${tmp_json}" > "${STATE_FILE}"
    else
        init_session "${new_alias}" "${assigned_pin}"
    fi

    # Delete previous node from Firebase so operative does not appear duplicated on scoreboard
    if [ -n "${current_student_id}" ] && [ "${current_student_id}" != "${new_student_id}" ]; then
        local old_endpoint="${FIREBASE_DATABASE_URL%/}/workshops/${WORKSHOP_ID}/students/${current_student_id}.json"
        curl -s --connect-timeout 4 --max-time 6 -X DELETE "${old_endpoint}" >/dev/null 2>&1 || true
    fi

    sync_to_firebase

    echo ""
    echo -e "\033[1;32m======================================================================\033[0m"
    echo -e "\033[1;32m[OK] Operativo registrado en el marcador: ${new_alias}\033[0m"
    echo -e "\033[1;36m[PIN] Tu PIN de sesion: ${assigned_pin}\033[0m"
    echo -e "\033[0;37m(Guarda tu PIN si cambias de terminal o reinicias la sesion: score resume ${new_alias} ${assigned_pin})\033[0m"
    echo -e "\033[1;33m[LEADERBOARD] Marcador en vivo: ${LEADERBOARD_URL}\033[0m"
    echo -e "\033[1;32m======================================================================\033[0m"
    echo ""
}

show_status() {
    ensure_session
    local a s c p
    a=$(jq -r '.alias // "Desconocido"' "${STATE_FILE}")
    s=$(jq -r '.totalScore // 0' "${STATE_FILE}")
    c=$(jq -r '.completedChallenges // 0' "${STATE_FILE}")
    p=$(jq -r '.pin // "No definido"' "${STATE_FILE}")
    echo -e "\033[1;36m[OPERATIVO]   ${a} (PIN: ${p})\033[0m"
    echo -e "\033[1;36m[PUNTUACION]  ${s}/1000 pts (Bonus max: 1250) | Retos: ${c}/4 $([ ${c} -ge 5 ] && echo '(ELITE)')\033[0m"
    echo -e "\033[1;33m[LEADERBOARD] ${LEADERBOARD_URL}\033[0m"
}

# Command dispatch for CLI usage: score_client.sh <action> [args...]
ACTION="${1:-}"
case "${ACTION}" in
    init)
        init_session "$2" "$3"
        ;;
    register|alias)
        register_alias "$2" "$3" "register"
        ;;
    resume)
        register_alias "$2" "$3" "resume"
        ;;
    hint)
        record_hint "$2" "$3" "$4"
        ;;
    is_unlocked)
        is_hint_unlocked "$2" "$3"
        ;;
    complete|verify)
        complete_challenge "$2" "$3"
        ;;
    sync)
        sync_to_firebase
        ;;
    status)
        show_status
        ;;
    *)
        echo "Uso: score {register <nombre> [pin] | resume <nombre> <pin> | status | hint <paso> | verify <paso> <pts>}"
        ;;
esac
