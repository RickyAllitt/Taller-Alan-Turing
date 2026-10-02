# Operational Post-Mortem: Supply Chain Security & Container Defense

## Technical Assessment Summary

This lab engagement evaluated the complete lifecycle of a containerized supply chain intrusion: initial access via pipeline execution, in-memory credential harvesting, privilege escalation through UNIX domain socket exposure, post-exploitation artifact analysis, and baseline hardening implementation.

```text
Attack Chain vs. Defensive Controls Matrix
────────────────────────────────────────────────────────────────────────────────────────
Attacker Technique (MITRE ATT&CK)     Exploited Condition          Remediated Control
────────────────────────────────────────────────────────────────────────────────────────
T1195.002 (Supply Chain Compromise)   Shared PID namespace         PID isolation, ephemeral
                                      Secrets in process memory    OIDC credentials (Vault/AWS)
────────────────────────────────────────────────────────────────────────────────────────
T1611 (Escape to Host)                /var/run/docker.sock mount   Socket removal; daemonless
                                      Root UID container context   builders (Kaniko / Buildah)
────────────────────────────────────────────────────────────────────────────────────────
T1059.004 (Unix Shell Persistence)    Writable container layer     read_only: true (OverlayFS)
                                      Unrestricted execution       cap_drop: [ALL], non-root
────────────────────────────────────────────────────────────────────────────────────────
```

---

## Architectural Findings and Recommendations

### 1. In-Memory Secrets Isolation
- **Observed Deficiency**: Long-lived deployment credentials (`DEPLOY_PRODUCTION_KEY`) were passed directly into the entrypoint process block, rendering them accessible via `/proc/1/environ` to all processes in the shared namespace.
- **Enterprise Standard**: Modern continuous integration agents should never maintain static, persistent cloud credentials. Workload identities should be negotiated at build time using **OpenID Connect (OIDC)** tokens with short time-to-live (TTL) allocations, combined with secret stores using Kubernetes CSI Secret Store drivers or external key vaults.

### 2. Elimination of Docker-Outside-of-Docker (DooD)
- **Observed Deficiency**: Mounting `/var/run/docker.sock` provides unauthenticated, root-equivalent control over the host kernel to any process inside the container.
- **Enterprise Standard**: Production build clusters must deprecate the Docker daemon socket for build workflows. Image generation must transition to daemonless, unprivileged builders executing within isolated user namespaces:
  - **Google Kaniko**: Builds container images inside a container or Kubernetes cluster without a Docker daemon.
  - **Buildah / Podman**: Employs user namespaces (`userns`) to build OCI images rootlessly.
  - **Sysbox**: Specialized OCI runtime that encapsulates Docker daemons inside unprivileged system containers.

### 3. Forensic Triage via Ephemeral Storage Drivers
- **Observed Methodology**: Static analysis of container security incidents is most reliably conducted via host-level interrogation of the **OverlayFS UpperDir**. This preserves file system metadata, isolates malicious implants without executing unverified container binaries, and facilitates rapid signature development using YARA.
- **Enterprise Standard**: Runtime threat detection should be shifted left into CI/CD security gates and automated with kernel-level eBPF sensors (**Cilium Tetragon**, **Falco**, or **Tracee**) to detect anomalous system calls, process lineage mutations, and unexpected network egress in real time.

### 4. Defense-in-Depth Container Hardening
- **Observed Implementation**: Hardening workloads requires multi-layered controls. Combining `read_only: true`, `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]`, and non-root execution (`user: 10001:10001`) neutralizes arbitrary command execution primitives, preventing persistence mechanisms and host privilege escalation.

---

## Industry Frameworks and Compliance References

For formal compliance specifications and architectural reference models:
- **Center for Internet Security**: [CIS Docker Benchmark v1.6.0](https://www.cisecurity.org/benchmark/docker)
- **National Institute of Standards and Technology**: [NIST SP 800-190: Application Container Security Guide](https://csrc.nist.gov/publications/detail/sp/800-190/final)
- **Open Source Security Foundation (OpenSSF)**: [Supply-chain Levels for Software Artifacts (SLSA v1.0)](https://slsa.dev/)
- **MITRE ATT&CK Matrix for Enterprise**: [Container Threat Model](https://attack.mitre.org/matrices/enterprise/containers/)
- **Cloud Native Computing Foundation (CNCF)**: [Cloud Native Security Whitepaper v2](https://github.com/cncf/tag-security/blob/main/security-whitepaper/cloud-native-security-whitepaper.md)
