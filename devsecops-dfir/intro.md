# Operational Engagement Briefing: Cloud-Native DFIR and Workload Hardening

## Technical Incident Overview

At 03:42 AM (Spanish local time / CET), runtime telemetry from host infrastructure flagged anomalous process spawning and unauthorized IPC requests on continuous integration worker `cicd_runner_pipeline`. Initial telemetry indicates that an untrusted CI/CD workflow executed arbitrary logic within the containerized build worker, initiating lateral enumeration against the host kernel.

This operational engagement requires you to perform offensive reconstruction, digital forensic triage, and baseline security re-engineering within a strict 75-minute operational window.

```text
+-----------------------------------------------------------------------------------+
| Host System (Ubuntu 22.04 LTS / Host Environment)                                 |
|                                                                                   |
|  Filesystem Artifacts                                                             |
|    /root/host_flag.txt               Host root integrity target (Challenge 2)    |
|    /evidence/backdoor_implant.sh     Recovered malicious artifact (Challenge 3)   |
|    /assets/docker-compose.yml        Vulnerable workload manifest (Challenge 4)   |
|                                                                                   |
|  Docker Engine Daemon (dockerd)                                                   |
|    UNIX Domain Socket: /var/run/docker.sock <═════════════════════════════╗       |
|                                                                           ║ Mount |
|  Container Boundary: cicd_runner_pipeline                                 ║       |
|                                                                           ║       |
|    Mounted Socket: /var/run/docker.sock <═════════════════════════════════╝       |
|                                                                                   |
|    Process Hierarchy                                                              |
|      PID 1: /app/pipeline_runner.sh                                               |
|        └── Virtual Memory: /proc/1/environ (Challenge 1)                          |
|                                                                                   |
|    OverlayFS Storage Layout                                                       |
|      UpperDir: Dynamic copy-on-write mutable layer (Challenge 3)                  |
|      LowerDir: Base image immutable layers                                        |
+-----------------------------------------------------------------------------------+
```

---

## Operational Roadmap & Scoring Economy

The 75-minute engagement is partitioned into four sequential operational phases evaluated on a **1,000 Base Points** scale. Completion timestamps are recorded in Spanish local time (AM/PM) and synchronized in real time to the cohort scoreboard.

| Phase | Technical Focus | Time Budget | Base Score | Tactical Hints Penalty |
| :--- | :--- | :---: | :---: | :--- |
| **Challenge 1** | In-Memory Credential Harvesting | 12 - 15 min | 200 pts | Tier 1: -25 pts &bull; Tier 2: -50 pts |
| **Challenge 2** | UNIX Domain Socket Breakout | 15 - 18 min | 250 pts | Tier 1: -30 pts &bull; Tier 2: -60 pts |
| **Challenge 3** | OverlayFS Triage & YARA Authoring | 20 - 23 min | 300 pts | Tier 1: -25 pts &bull; Tier 2: -50 pts &bull; Tier 3: -75 pts |
| **Challenge 4** | CIS Hardening & Empirical Validation | 15 - 18 min | 250 pts | Tier 1: -30 pts &bull; Tier 2: -60 pts |

### Operative Call Sign & Scoreboard Registration
During scenario initialization in the right-hand terminal, an interactive registration prompt will appear once background provisioning completes:

```text
================================================================================
                   CYBER RANGE OPERATIVE REGISTRATION                           
================================================================================
Enter your Operative Call Sign / Student Alias to track your progress and score
on the live cohort leaderboard.

Operative Call Sign [default: operative-XXXXX]:
```

- **Identifier Selection:** Enter a distinctive handle or student call sign (2 to 20 characters, containing alphanumeric characters, hyphens, or underscores, e.g., `alberto-sec`, `ciber-09`).
- **Default Assignment:** Pressing `Enter` without input automatically provisions a randomized handle (`operative-$RANDOM`).
- **Telemetry Correlation:** Your call sign will identify your progress, completion timestamps (Spanish local time / CET), hint deductions, and First Blood recognitions on the public cohort scoreboard.
- **Session Locking:** To prevent session collisions or score spoofing, your call sign is immutable for the duration of the 75-minute lab run.

### Tactical Hint System
If you encounter an operational impasse during any challenge, tactical guidance can be requested via the terminal command:

```bash
hint <step_number>
```

Example: `hint 1` displays available tiers and point costs before confirming deduction. Unlocking hints deducts points from that challenge's base score upon successful verification.

### Live Cohort Leaderboard
Track your real-time ranking, completion times, and peer standings at:
**https://rickyallitt.github.io/Taller-Alan-Turing**

---

## Technical Constraints and Operational Boundaries

- Automated verification scripts are bound to each phase. Output values must strictly adhere to the expected format and target filesystem locations specified in each section.
- Modifying underlying system services or uninstalling monitoring components will cause verification failure.
- Ensure all intermediate analysis scripts are stored in `/tmp` or `/evidence`.

Confirm baseline node readiness before proceeding:

```bash
docker ps --filter "name=cicd_runner_pipeline" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
```

Advance to **Challenge 1** to begin credential reconstruction.
