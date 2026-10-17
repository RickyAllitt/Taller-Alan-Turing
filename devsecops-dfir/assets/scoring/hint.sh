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
    echo "Cyber Range Tactical Hint System - CPIFP Alan Turing"
    echo "======================================================================"
    echo "Usage: hint <step_number>"
    echo ""
    echo "Available Challenges:"
    echo "  hint 1  - Challenge 1: Process Memory & Secret Harvesting"
    echo "  hint 2  - Challenge 2: Docker Daemon Socket Breakout"
    echo "  hint 3  - Challenge 3: OverlayFS Triage & YARA Threat Hunting"
    echo "  hint 4  - Challenge 4: CIS Production Hardening"
    echo ""
    echo "Notice: Unlocking hints will deduct points from your final score."
    echo "======================================================================"
    exit 0
}

[ -z "${STEP}" ] && show_usage

if ! [[ "${STEP}" =~ ^[1-4]$ ]]; then
    echo "Error: Invalid step '${STEP}'. Must be 1, 2, 3, or 4."
    exit 1
fi

# Ensure score client exists
if [ ! -f "${SCORE_CLIENT}" ]; then
    echo "Error: Scoring telemetry client not found at ${SCORE_CLIENT}."
    exit 1
fi

prompt_unlock() {
    local step_num="$1"
    local tier_num="$2"
    local penalty="$3"
    local description="$4"

    # Check if previously unlocked
    if bash "${SCORE_CLIENT}" is_unlocked "${step_num}" "${tier_num}" 2>/dev/null; then
        echo -e "\033[0;32m[UNLOCKED] Hint ${tier_num} (Previously revealed - 0 pt deduction)\033[0m"
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
            echo -e "\033[0;32m[UNLOCKED] Hint ${tier_num} (Previously revealed - 0 pt deduction)\033[0m"
            echo -e "${description}"
            echo ""
            return 0
        fi
    fi

    echo -e "\033[1;33m[LOCKED] Hint ${tier_num} for Challenge ${step_num} is available.\033[0m"
    echo -e "\033[1;31mPenalty: -${penalty} points from Challenge ${step_num} base score.\033[0m"
    echo -n "Do you wish to unlock this hint? [y/N]: "
    read -r confirmation

    if [[ "${confirmation}" =~ ^[yY]([eE][sS])?$ ]]; then
        bash "${SCORE_CLIENT}" hint "${step_num}" "${tier_num}" "${penalty}"
        echo ""
        echo -e "\033[1;32m[UNLOCKED] Hint ${tier_num} for Challenge ${step_num}:\033[0m"
        echo -e "${description}"
        echo ""
    else
        echo -e "\033[0;33mAction cancelled. Points preserved.\033[0m"
        echo ""
    fi
}

echo "======================================================================"
echo "Tactical Guidance Engine - Challenge ${STEP}"
echo "======================================================================"

case "${STEP}" in
    1)
        echo "Challenge 1: Process Memory & Secret Harvesting (Base: 200 pts)"
        echo ""
        prompt_unlock 1 1 25 \
            "Architecture Clue: The Linux kernel populates /proc/[PID]/environ from process memory.\nWhile subshells and exec sessions run with separate, sanitized environments,\nPID 1 (the container supervisor) retains the original initialization block."
        prompt_unlock 1 2 50 \
            "Stream Translation Clue: Entries in /proc/[PID]/environ are separated by null bytes (\x00).\nStandard text utilities fail on null streams. Use 'tr' to translate null bytes to newlines:\n  tr '\0' '\n' < /proc/1/environ\nOr extract printable byte sequences with 'strings /proc/1/environ'."
        ;;
    2)
        echo "Challenge 2: Docker Daemon Socket Breakout (Base: 250 pts)"
        echo ""
        prompt_unlock 2 1 30 \
            "Privilege Model Clue: /var/run/docker.sock communicates directly with the host's dockerd daemon.\nThe host daemon executes all API actions as root (UID 0) on the host kernel,\nbypassing container namespaces and cgroup boundaries."
        prompt_unlock 2 2 60 \
            "Breakout Syntax Clue: From inside the container, execute the local docker CLI to spawn an auxiliary\ncontainer that mounts the host root directory into a guest path:\n  docker run -v /:/mnt/host --rm -it alpine chroot /mnt/host sh\nThis shifts your root execution context directly into the host filesystem."
        ;;
    3)
        echo "Challenge 3: OverlayFS Triage & YARA Threat Hunting (Base: 300 pts)"
        echo ""
        prompt_unlock 3 1 25 \
            "Storage Driver Clue: Writable container modifications reside in the host's UpperDir.\nExtract the path by running on the host:\n  docker inspect cicd_runner_pipeline | jq '.[0].GraphDriver.Data.UpperDir'\nSearch this host directory with 'find' or audit /var/log/pipeline_audit/ for recent implants."
        prompt_unlock 3 2 50 \
            "Static Analysis Clue: Review /evidence/backdoor_implant.sh.\nThe script contains two distinct IoC markers:\n  1. C2 Destination: 'http://evil-c2.attacker.internal'\n  2. Header Comment: '# Malicious Exfiltration Hook'\nAvoid generic terms like 'curl' or '#!/bin/sh' to prevent false positives."
        prompt_unlock 3 3 75 \
            "YARA Scaffold Clue: Save your rule at /evidence/detect_implant.yar:\n  rule Malicious_Exfiltration_Hook {\n      meta:\n          description = \"Detects CI/CD pipeline exfiltration hook\"\n      strings:\n          \$c2 = \"http://evil-c2.attacker.internal\"\n          \$hook = \"# Malicious Exfiltration Hook\"\n      condition:\n          \$c2 and \$hook\n  }"
        ;;
    4)
        echo "Challenge 4: CIS Production Hardening (Base: 250 pts)"
        echo ""
        prompt_unlock 4 1 30 \
            "Compose Remediations: In /assets/docker-compose.hardened.yml:\n  1. Remove the volume entry '- /var/run/docker.sock:/var/run/docker.sock'\n  2. Set non-root execution: user: \"10001:10001\"\n  3. Enable read-only root filesystem: read_only: true"
        prompt_unlock 4 2 60 \
            "Privilege and Storage Directives:\n  4. Strip ambient capabilities: cap_drop: [\"ALL\"]\n  5. Suppress privilege escalation: security_opt: [\"no-new-privileges:true\"]\n  6. Allocate in-memory volatile storage for /tmp:\n     tmpfs: [\"/tmp:rw,noexec,nosuid,size=64m\"]\nDeploy with: docker compose -f /assets/docker-compose.hardened.yml up -d --force-recreate"
        ;;
esac

echo "======================================================================"
echo "Tip: Run '/step${STEP}/verify.sh' to submit your solution and record your score."
echo "======================================================================"
