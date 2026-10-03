# Challenge 4: CIS Hardening & Empirical Validation

**Time Allocation: 15 - 18 minutes**

---

## DevSecOps Engineering: CIS Docker Benchmark Compliance

In earlier challenges, you analyzed how default runtime configurations enable credential theft, host filesystem compromise, and uninhibited malware persistence. To establish a secure operational baseline, workloads must implement **Defense-in-Depth** and **Least Privilege** controls defined in the **CIS Docker Benchmark** and **NIST SP 800-190** (Application Container Security Guide).

---

## Security Remediation Matrix

The following table correlates the vulnerabilities exploited during the simulation with their corresponding CIS Docker Benchmark controls and required Docker Compose directives:

| Vulnerability / Attack Vector | Exploited Condition in Lab | CIS Benchmark Control | Docker Compose Directive |
| :--- | :--- | :--- | :--- |
| **Daemon API Hijacking** | `/var/run/docker.sock` mounted in container | **CIS 5.31**: Do not mount Docker socket | Remove `- /var/run/docker.sock:/var/run/docker.sock` from `volumes` |
| **Root Execution Context** | Process executes as default `UID 0` | **CIS 4.1**: Create and enforce non-root user | `user: "10001:10001"` |
| **Implant Persistence** | Writable container root filesystem | **CIS 5.12**: Mount container rootfs as read-only | `read_only: true` |
| **Kernel Privilege Abuse** | Default ambient Linux capabilities retained | **CIS 5.2**: Restrict Linux capabilities | `cap_drop: ["ALL"]` |
| **Privilege Escalation** | SUID/SGID binary execution | **CIS 5.25**: Restrict privilege escalation | `security_opt: ["no-new-privileges:true"]` |
| **Scratch Space Availability** | Read-only rootfs prevents necessary temporary writes | **NIST SP 800-190**: Isolated ephemeral partitions | `tmpfs: ["/tmp:rw,noexec,nosuid,size=64m"]` |

---

## Technical Objectives

1. Audit the existing vulnerable configuration at `/assets/docker-compose.yml`.
2. Author a hardened service manifest at `/assets/docker-compose.hardened.yml`.
3. Apply all six security controls documented in the remediation matrix.
4. Redeploy the service using `docker compose` with the `--force-recreate` flag.
5. Execute empirical validation commands to confirm that breakout vectors, unauthorized writes, and privilege escalations fail with kernel-enforced errors.

---

## Execution Guidelines

### 1. Hardened Manifest Construction
Create and edit `/assets/docker-compose.hardened.yml`. Preserve the original service name (`cicd_runner_pipeline`), image (`alan-turing/cicd-runner:vulnerable`), and environment variables (`RUNNER_NAME`, `RUNNER_ORGANIZATION`, `CI_ENVIRONMENT`), while integrating the hardening parameters:

```yaml
version: '3.8'

services:
  cicd_runner_pipeline:
    container_name: cicd_runner_pipeline
    image: alan-turing/cicd-runner:vulnerable
    restart: unless-stopped
    user: "10001:10001"
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=64m
    environment:
      - RUNNER_NAME=worker-01
      - RUNNER_ORGANIZATION=AlanTuring-SecOps
      - CI_ENVIRONMENT=production
    # NOTE: The /var/run/docker.sock volume has been completely removed.
```

### 2. Service Redeployment
Deploy the hardened configuration, instructing Docker Compose to recreate the container instance:

```bash
docker compose -f /assets/docker-compose.hardened.yml up -d --force-recreate
```

Verify that the newly deployed container is running:

```bash
docker ps --filter "name=cicd_runner_pipeline"
```

### 3. Empirical Security Validation
Execute direct validation tests against the running container to prove that the defenses are actively enforced by the Linux kernel:

1. **Verify Filesystem Immutability**:
   Attempt to create an arbitrary file on the root filesystem:
   ```bash
   docker exec cicd_runner_pipeline touch /test_write
   ```
   *Expected Result*: `touch: /test_write: Read-only file system` (Kernel error code `EROFS`).

2. **Verify User Context**:
   Query the effective user and group identifiers:
   ```bash
   docker exec cicd_runner_pipeline id
   ```
   *Expected Result*: `uid=10001(cicduser) gid=10001(cicdgroup)`.

3. **Verify Daemon Socket Elimination**:
   Confirm that the UNIX domain socket is absent:
   ```bash
   docker exec cicd_runner_pipeline ls -la /var/run/docker.sock
   ```
   *Expected Result*: `ls: /var/run/docker.sock: No such file or directory`.

4. **Verify Ephemeral Storage**:
   Confirm that write operations to `/tmp` remain functional while backed purely by volatile RAM:
   ```bash
   docker exec cicd_runner_pipeline touch /tmp/test_ok && echo "Tmpfs write successful"
   ```
   *Expected Result*: `Tmpfs write successful`.

---

## Verification Requirements

Confirm that `/assets/docker-compose.hardened.yml` exists and that `cicd_runner_pipeline` reflects the audited security parameters. Execute the automated compliance audit:

```bash
/step4/verify.sh
```
