# Challenge 4: Production Hardening & Baseline Verification

## Engineering Security Controls: CIS Docker Benchmark Compliance

In the preceding challenges, you demonstrated that default container runtime configurations permit three critical vulnerability classes:
1. **Unrestricted IPC Exposure**: Direct access to the host daemon socket permits container breakout and root host compromise.
2. **Volatile File Permissiveness**: Writable root filesystems permit adversaries to stage backdoors, download payloads, and modify runtime libraries.
3. **Privilege Over-Allocation**: Executing workloads with default capability sets and root UID facilitates privilege escalation and kernel interaction.

To remediate these exposures in accordance with **CIS Docker Benchmark** and **NIST SP 800-190** standards, you must refactor the service definition into an immutable, least-privilege deployment manifest.

---

## Technical Objectives

1. Analyze the existing vulnerable service definition at `/assets/docker-compose.yml`.
2. Construct a production-grade hardened Compose configuration saved at `/assets/docker-compose.hardened.yml`.
3. Enforce the required security controls:
   - Complete removal of the Docker daemon socket mount.
   - Non-root UID/GID execution context (`10001:10001`).
   - Kernel-enforced read-only root filesystem (`read_only: true`).
   - Complete revocation of default Linux capabilities (`cap_drop: [ALL]`).
   - Prevention of privilege escalation via setuid binaries (`no-new-privileges:true`).
   - Allocation of an in-memory ephemeral scratch partition (`tmpfs`) at `/tmp`.
4. Deploy the hardened service using `docker compose` with the `--force-recreate` flag.
5. Empirically verify that file creation on `/` is blocked by kernel filesystem protection, that the process runs under the non-root identity, and that `/var/run/docker.sock` is absent.

---

## Specification and Architecture Directives

Construct `/assets/docker-compose.hardened.yml` maintaining the service name (`cicd_runner_pipeline`), image (`alan-turing/cicd-runner:vulnerable`), and environment parameters, while enforcing the following control directives:

### 1. IPC and Volume Deprecation (CIS Benchmark 5.31)
Under `volumes:`, purge the bind-mount entry for `/var/run/docker.sock`. Workload processes must have no communication channel to the host Docker daemon.

### 2. Principle of Least Privilege Execution (CIS Benchmark 4.1)
The base image contains an unprivileged service account created with UID/GID `10001:10001`. Enforce execution under this account using the Compose `user` directive:
```yaml
user: "10001:10001"
```

### 3. Filesystem Immutability (CIS Benchmark 5.12)
Prevent modifications to application binaries and system libraries by mounting the container's root filesystem in read-only mode:
```yaml
read_only: true
```

### 4. Linux Capability Stripping (CIS Benchmark 5.2)
By default, Docker allocates 14 Linux capabilities (e.g., `CAP_NET_RAW`, `CAP_CHOWN`, `CAP_MKNOD`) to unprivileged containers. Strip all ambient capabilities:
```yaml
cap_drop:
  - ALL
```

### 5. Privilege Escalation Prevention (CIS Benchmark 5.25)
Ensure that child processes cannot acquire additional execution privileges through setuid or setgid binaries:
```yaml
security_opt:
  - no-new-privileges:true
```

### 6. Ephemeral Scratch Space
Because `read_only: true` locks the entire container rootfs, applications requiring temporary workspace buffers must be provided an in-memory mount. Configure a `tmpfs` mount targeting `/tmp`:
```yaml
tmpfs:
  - /tmp:rw,noexec,nosuid,size=64m
```

---

## Deployment and Empirical Validation

### Service Deployment
Deploy the refactored workload:

```bash
docker compose -f /assets/docker-compose.hardened.yml up -d --force-recreate
```

Confirm that the new container is in an `Up` operational status.

### Empirical Control Testing
Validate each hardening boundary manually using `docker exec`:

1. **Test Rootfs Immutability**: Attempt to create an arbitrary file within root (e.g., `/test_immutability`). The command must fail with `Read-only file system`.
2. **Test Process Identity**: Query the active user identity (`id`). The output must confirm execution under `uid=10001(cicduser) gid=10001(cicdgroup)`.
3. **Test Socket Elimination**: Query the path `/var/run/docker.sock`. The shell must return `No such file or directory`.
4. **Test Scratch Space Functionality**: Attempt file creation within `/tmp`. Writes to `/tmp` must succeed while remaining confined to RAM.

---

## Verification Requirements

Ensure `/assets/docker-compose.hardened.yml` is populated and that the active `cicd_runner_pipeline` container reflects the hardened configuration.

Trigger the automated security audit script:

```bash
/step4/verify.sh
```
