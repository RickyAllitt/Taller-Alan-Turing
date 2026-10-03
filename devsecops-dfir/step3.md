# Challenge 3: OverlayFS Triage & YARA Authoring

**Time Allocation: 20 - 23 minutes**

---

## Digital Forensics Context: Ephemeral Storage Triage

During incident response engagements involving containerized workloads, entering a compromised container to execute investigative commands introduces critical evidentiary risks:
- Local tools and shell utilities may have been replaced with trojanized versions.
- Executing binaries within the live container modifies volatile memory spaces and alters file access timestamps (`atime`).

In modern Linux container forensics, analysts perform offline triage directly from the host by inspecting the storage driver layout.

```text
OverlayFS Structural Hierarchy
┌──────────────────────────────────────────────────────────────┐
│ Merged Directory: Unified view visible to running container  │
├──────────────────────────────────────────────────────────────┤
│ Upper Directory (UpperDir): Writable copy-on-write layer     │
│   ├── Modified configuration files                           │
│   └── Attacker implants and dropped execution scripts        │
├──────────────────────────────────────────────────────────────┤
│ Lower Directory (LowerDir): Read-only immutable image layers │
└──────────────────────────────────────────────────────────────┘
```

The `UpperDir` path on the host contains all filesystem modifications, dropped scripts, and staging directories created during the container's lifecycle.

---

## Technical Objectives

1. Query host Docker daemon metadata to locate the `UpperDir` storage path for `cicd_runner_pipeline`.
2. Inspect the writable overlay layer on the host to isolate the malicious implant script placed by the adversary.
3. Review the forensic copy staged at `/evidence/backdoor_implant.sh`.
4. Author a valid, production-grade YARA rule saved at `/evidence/detect_implant.yar`.
5. Ensure the rule specifically detects the threat script without producing false positives on benign shell utilities.
6. Verify rule compilation and execution using `yara(1)`.

---

## Execution Guidelines

### 1. Storage Driver Interrogation
From the host terminal, extract the storage driver configuration using `docker inspect`:

```bash
docker inspect cicd_runner_pipeline | jq '.[0].GraphDriver.Data'
```

Identify the absolute filesystem path assigned to `UpperDir`. Inspect this directory path on the host system using `find` or `ls -lR`. Trace files written outside default base image directories, specifically auditing `/var/log` or administrative paths.

### 2. Static Artifact Triage
A forensic staging copy of the identified implant is preserved at `/evidence/backdoor_implant.sh`. 

Inspect the script contents using `cat` or `head`:
- Review the execution interpreter (`#!/bin/sh`).
- Identify the exfiltration channel (protocol, command syntax, parameters).
- Extract unique Indicators of Compromise (IoCs): target C2 domains, endpoint URIs, and explicit comment headers.

**False-Positive Avoidance**:
Do NOT anchor detection rules purely on generic tokens such as `#!/bin/sh`, `curl`, or `-X POST`. Rules matching only standard utility calls will generate false-positive alerts against legitimate maintenance scripts across production environments.

### 3. YARA Rule Authoring

Create your detection rule at `/evidence/detect_implant.yar`. To prevent syntax validation stalls, adhere to the standard YARA rule structural scaffold:

```yara
rule Threat_Implant_Detection
{
    meta:
        description = "Technical description of the threat implant"
        author      = "DFIR Analyst"
        reference   = "CPIFP Alan Turing Incident Response"

    strings:
        // Define string patterns: ASCII ($s = "..."), Hex ($h = { ... }), or Regex ($r = /.../)
        // Select unique identifiers (C2 endpoints, exfiltration parameters, unique comments)

    condition:
        // Define matching logic (e.g., all of them, any of them, or specific boolean combinations)
}
```

Populate the `strings` section with patterns matching the adversary's C2 endpoint (`http://evil-c2.attacker.internal`) and the specific script header (`# Malicious Exfiltration Hook`). Configure the `condition` block to ensure both indicators must be satisfied for a positive match.

### 4. Rule Compilation and Detection Testing
Execute YARA against the target evidence sample:

```bash
yara /evidence/detect_implant.yar /evidence/backdoor_implant.sh
```

To display matching string offsets and rule verification details:

```bash
yara -s /evidence/detect_implant.yar /evidence/backdoor_implant.sh
```

Ensure the tool exits with return code `0` and outputs the rule identifier followed by the target file path.

---

## Verification Requirements

Ensure your completed YARA rule is saved at `/evidence/detect_implant.yar`. Trigger the automated validation harness:

```bash
/step3/verify.sh
```
