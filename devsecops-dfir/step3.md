# Challenge 3: Container DFIR & YARA Threat Hunting

## Digital Forensics Context: Ephemeral Storage Triage

During incident response engagements involving containerized workloads, entering a compromised container to execute investigation tools is an operational anti-pattern. Untrusted binaries within the container may be trojanized, and process execution alters volatile memory and timestamp metadata.

Container digital forensics relies on host-level inspection of the underlying storage driver.

```text
OverlayFS Mount Structure
├── lowerdir (Read-Only)  : Immutable base image layers.
├── upperdir (Read-Write) : Ephemeral copy-on-write (CoW) delta layer containing all
│                           files created, modified, or staged for deletion during runtime.
└── merged                : Virtual union mount visible to container processes.
```

By extracting the `UpperDir` location from container engine metadata on the host, incident responders can perform static triage on all adversary modifications without interacting with the container runtime.

---

## Technical Objectives

1. Determine the storage driver architecture and locate the dynamic `UpperDir` for `cicd_runner_pipeline` using host Docker inspection utilities.
2. Identify an attacker-dropped persistence or exfiltration script introduced into the container's mutable filesystem layer.
3. Review the forensic staging copy located at `/evidence/backdoor_implant.sh`.
4. Engineer an enterprise-grade YARA rule at `/evidence/detect_implant.yar` targeting the unique characteristics and network indicators of the implant.
5. Validate that your rule compiles cleanly and accurately detects the sample using `yara(1)`.

---

## Investigation Vectors and Execution Guidelines

### OverlayFS Metadata Triage
Query Docker Engine metadata for `cicd_runner_pipeline` from the host. Specifically, inspect the `.GraphDriver.Data` object using `docker inspect` and `jq` or Docker Go template formatting. Locate the host filesystem path corresponding to `UpperDir`.

Examine this directory on the host. Because `UpperDir` stores file creations and modifications relative to the container root (`/`), search for newly created shell scripts, audit logs, or executable artifacts placed in non-standard locations (such as `/var/log` or administrative directories).

### Evidence Inspection
An identical copy of the suspicious artifact has been preserved in the forensic evidence directory: `/evidence/backdoor_implant.sh`.

Perform static analysis on this artifact:
- Determine the interpreter and execution context.
- Identify the exfiltration mechanism, data sources targeted, and external Command and Control (C2) network destinations.
- Identify specific ASCII string sequences that uniquely identify this malicious script and distinguish it from benign administrative shell scripts.

### YARA Rule Engineering
Construct a syntactically valid YARA rule file located at `/evidence/detect_implant.yar`.

A robust YARA rule must satisfy the following structural requirements:
- **`rule` identifier**: A distinct, descriptive rule name adhering to YARA identifier syntax.
- **`meta` section**: Administrative metadata including description, author, reference date, and threat classification.
- **`strings` section**: Distinct string declarations. You must define patterns that match the hardcoded C2 infrastructure (the attacker domain/endpoint) and the explicit exfiltration hook comments found in the script. Avoid overly generic terms (like `#!/bin/sh` or `curl`) that would cause false-positive matches across standard system utilities.
- **`condition` section**: Boolean logic ensuring all relevant indicators must be satisfied for a positive detection.

### Syntax and Detection Testing
Validate your rule against the evidence sample using the `yara` CLI utility:

```text
Command Reference: yara [options] rule_file target_file
Useful Flags:
  -s  Print matching string identifiers and offsets.
  -c  Print match counts only.
```

Ensure the execution returns exit code `0` and explicitly outputs the rule match against `/evidence/backdoor_implant.sh`.

---

## Verification Requirements

Confirm that your rule file is saved at `/evidence/detect_implant.yar` and correctly flags the target script:

```text
Rule Path:   /evidence/detect_implant.yar
Target File: /evidence/backdoor_implant.sh
```

Execute the automated verification check:

```bash
/step3/verify.sh
```
