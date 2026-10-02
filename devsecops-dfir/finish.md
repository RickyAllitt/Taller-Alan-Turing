# 🎓 Workshop Completed: DevSecOps & Container DFIR

Congratulations! You have successfully completed the **DevSecOps & Container DFIR Workshop** at **CPIFP Alan Turing**.

You transitioned from dissecting an active supply chain attack to engineering a resilient, production-hardened container infrastructure.

---

## 🏆 Summary of Accomplishments

```text
+-----------------------------------------------------------------------------------------+
|                                  WORKSHOP ACHIEVEMENTS                                  |
+-----------------------------------------------------------------------------------------+
| [✔] Challenge 1: Harvested in-memory secrets from /proc/1/environ (T1552.003).          |
| [✔] Challenge 2: Executed container breakout via /var/run/docker.sock to host root.     |
| [✔] Challenge 3: Analyzed forensic evidence & engineered a YARA signature for C2 hooks. |
| [✔] Challenge 4: Enforced CIS Docker Hardening (read_only, cap_drop, non-root, tmpfs).  |
+-----------------------------------------------------------------------------------------+
```

---

## 🛡️ Core Security Architecture Principles

### 1. Secrets Management in Cloud-Native Pipelines
- **Anti-Pattern**: Passing sensitive production tokens into container process environments or build manifests.
- **Best Practice**: Use **ephemeral OpenID Connect (OIDC)** federations with AWS IAM, Google Cloud Workload Identity, or Azure Workload ID. If static secrets are required, store them in HashiCorp Vault or Kubernetes Secret Stores CSI Driver.

### 2. Eliminating Docker Socket Exposure (DooD)
- **Anti-Pattern**: Mounting `/var/run/docker.sock` to enable `docker build` within CI/CD runner containers.
- **Best Practice**: Use daemonless, user-namespaced builders such as **Google Kaniko**, **Buildah**, or isolated microVM runtimes like **Kata Containers** and **Sysbox**.

### 3. Container Forensics & Runtime Threat Hunting
- **Investigation**: When investigating container incidents, inspect the **OverlayFS UpperDir** on the host. This preserves volatile and non-volatile forensic artifacts without trusting binaries inside a compromised container.
- **Detection**: Standardize IoC detection with **YARA** in CI artifact repositories and deploy eBPF-based runtime observability (**Falco**, **Tetragon**, or **Tracee**) for kernel-level anomaly detection.

### 4. Defense-in-Depth Container Hardening
- Enforce **Immutable Infrastructure**: `read_only: true` neutralizes malware installation and script modification.
- Enforce **Least Privilege**: Drop all Linux capabilities (`cap_drop: ["ALL"]`), enforce non-root execution (`user: 10001:10001`), and enable `no-new-privileges:true`.

---

## 📚 Industry Standards & Further Reading

Explore these industry frameworks to deepen your cloud-native DevSecOps expertise:

- **CIS Docker Benchmark**: [Center for Internet Security Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- **OpenSSF SLSA Framework**: [Supply-chain Levels for Software Artifacts](https://slsa.dev/)
- **NIST SP 800-190**: [Application Container Security Guide](https://csrc.nist.gov/publications/detail/sp/800-190/final)
- **MITRE ATT&CK for Containers**: [Matrix for Enterprise - Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- **CNCF Cloud Native Security Whitepaper**: [Cloud Native Computing Foundation](https://github.com/cncf/tag-security/blob/main/security-whitepaper/cloud-native-security-whitepaper.md)
- **Sigstore / Cosign**: [Software Signing and Verification for Container Images](https://www.sigstore.dev/)

---

*Thank you for participating! Continue building secure, resilient cloud-native systems.*
