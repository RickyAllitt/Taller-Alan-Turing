# DevSecOps & Container DFIR: Supply Chain Attacks, Breakouts & Hardening

Welcome to the **DevSecOps & Container DFIR Hands-on Workshop** designed for the **Curso de Especialización en Ciberseguridad** at **CPIFP Alan Turing (Málaga)**.

---

## 🎯 Incident Briefing & Scenario Narrative

You are deployed as a **Principal DevSecOps & Incident Response Specialist** at *Alan Turing Cloud Systems*. 

At **03:42 UTC**, automated runtime telemetry detected anomalous execution within one of your organization's core continuous integration nodes: a Dockerized build agent named `cicd_runner_pipeline`. Threat intelligence suggests an adversary gained remote execution through a **Poisoned Pipeline Execution (PPE)** vector, attempting to:

1. **Harvest high-value production credentials** injected into the pipeline runner's memory space.
2. **Break out of the container environment** by exploiting an unsegmented Docker Unix socket (`/var/run/docker.sock`) to compromise the underlying Linux host.
3. **Establish persistence & exfiltrate intellectual property** using an automated curl-based implant.
4. Evade traditional detection by taking advantage of missing container boundaries and root privileges.

Your mission is divided into two operational phases:
- **Phase 1: Offensive Reconstruction & DFIR Triage (Challenges 1 - 3)**: Reconstruct the attacker's path, extract leaked secrets from `/proc/1/environ`, perform a host escape, and develop a YARA detection rule against the adversary's implant.
- **Phase 2: Defensive Engineering & Hardening (Challenge 4)**: Remediate the vulnerable deployment using DevSecOps best practices, adhering to the **CIS Docker Benchmark** and the principle of least privilege.

---

## 🏛️ Lab Architecture

```text
+-----------------------------------------------------------------------------------+
| Linux Host VM (Ubuntu 22.04 LTS / Host Environment)                               |
|                                                                                   |
|  [Filesystem]                                                                     |
|    ├── /root/host_flag.txt               <-- Host Target Flag (Ch. 2)             |
|    ├── /evidence/backdoor_implant.sh     <-- Malicious Implant Sample (Ch. 3)     |
|    └── /assets/docker-compose.yml        <-- Vulnerable Service Definition (Ch. 4)|
|                                                                                   |
|  [Docker Engine Daemon: dockerd]                                                  |
|    └── UNIX Socket: /var/run/docker.sock <═════════════════════════════════╗       |
|                                                                            ║       |
|  +----------------------------------------------------------------------+  ║ Mount |
|  | Container: cicd_runner_pipeline                                      |  ║       |
|  |                                                                      |  ║       |
|  |  [Mounted Socket] /var/run/docker.sock <═════════════════════════════╝       |
|  |                                                                                |
|  |  [Processes]                                                                   |
|  |    ├── PID 1: /app/pipeline_runner.sh                                         |
|  |    │     └── Process Memory: /proc/1/environ                                  |
|  |    │           └── Secret: DEPLOY_PRODUCTION_KEY=FLAG{...} (Ch. 1)            |
|  |    │                                                                           |
|  |    └── Subshell / Exec Sessions (Isolated from default env)                    |
|  |                                                                                |
|  |  [Filesystem Layers - OverlayFS]                                               |
|  |    ├── UpperDir / /var/log/pipeline_audit/backdoor_implant.sh                  |
|  |    └── LowerDir (Base Alpine Image + docker-cli)                               |
|  +----------------------------------------------------------------------+         |
+-----------------------------------------------------------------------------------+
```

---

## 📋 Mission Roadmap

| Challenge | Phase | MITRE ATT&CK / NIST | Objective |
| :--- | :--- | :--- | :--- |
| **Challenge 1** | Threat Simulation | [T1552.003](https://attack.mitre.org/techniques/T1552/003/) (Process Environment) | Inspect `/proc/1/environ` to extract leaked pipeline credentials. |
| **Challenge 2** | Container Breakout | [T1611](https://attack.mitre.org/techniques/T1611/) (Escape to Host) | Abuse `/var/run/docker.sock` to escape the container and capture host root. |
| **Challenge 3** | DFIR & Threat Hunting | [T1059.004](https://attack.mitre.org/techniques/T1059/004/) (Unix Shell) | Analyze the malicious implant and write a production-grade YARA rule. |
| **Challenge 4** | DevSecOps Hardening | CIS Docker Benchmark | Re-engineer `docker-compose.yml` to enforce immutability and drop capabilities. |

---

## ⚡ Pre-Flight Environment Checks

The background provisioning script automatically initializes Docker, builds the required images, and installs forensic tooling (`yara`, `jq`).

Before starting Challenge 1, verify that all prerequisites are ready on the host:

```bash
docker ps
```

You should see `cicd_runner_pipeline` in an `Up` status.

Check that YARA is available:

```bash
yara --version
```

Verify that the lab assets and evidence folders are present:

```bash
ls -ld /assets /evidence
```

Click **Next** in the bottom right corner to begin **Challenge 1**.
