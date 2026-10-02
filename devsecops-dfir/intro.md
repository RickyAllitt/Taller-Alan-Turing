# Operational Engagement Briefing: Cloud-Native DFIR and Workload Hardening

## Technical Incident Overview

At 03:42 UTC, runtime telemetry from host infrastructure flagged anomalous process spawning and unauthorized IPC requests on continuous integration worker `cicd_runner_pipeline`. Initial telemetry indicates that an untrusted CI/CD workflow executed arbitrary logic within the containerized build worker, initiating lateral enumeration against the host kernel.

This operational engagement requires you to perform offensive reconstruction, digital forensic triage, and baseline security re-engineering.

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

## Scope of Work and Rules of Engagement

The assessment is partitioned into two functional disciplines:

### Phase 1: Attack Reconstruction and DFIR Triage (Challenges 1 to 3)
1. **In-Memory Credential Harvesting**: Interrogate kernel-exposed process telemetry to recover sensitive production credentials leaking through the process hierarchy.
2. **UNIX Socket Exploitation**: Exploit host daemon socket exposure to achieve a full container breakout and acquire host root access.
3. **Forensic Delta Analysis and Threat Hunting**: Identify filesystem modifications within the container storage driver layers and author an enterprise detection rule using YARA.

### Phase 2: Defensive Remediation and Hardening (Challenge 4)
1. **Container Security Architecture**: Re-engineer the service deployment manifest to enforce immutable root filesystems, Linux capability restriction, non-root user execution, and socket de-provisioning according to CIS Docker Benchmark standards.

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
