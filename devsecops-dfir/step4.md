# Challenge 4: Production Hardening (DevSecOps)

## 📖 Background & Security Principles

In the previous challenges, you exploited common misconfigurations:
1. Process environment credential exposure ([T1552.003](https://attack.mitre.org/techniques/T1552/003/))
2. Unrestricted Docker daemon socket access allowing host takeover ([T1611](https://attack.mitre.org/techniques/T1611/))
3. Writable container root filesystems allowing attackers to drop and execute implants ([T1059.004](https://attack.mitre.org/techniques/T1059/004/))

As a DevSecOps engineer, your goal is to enforce **Defense-in-Depth** and **Least Privilege**. In this final challenge, you will refactor the deployment configuration to implement the **CIS Docker Benchmark** recommendations.

---

## 🛡️ Hardening Controls Overview

| Security Control | Benchmark Directive | Security Benefit |
| :--- | :--- | :--- |
| **Eliminate Docker Socket** | CIS Docker 5.31 | Removes the capability to control the host Docker daemon. |
| **Run as Non-Root User** | CIS Docker 4.1 (`user: "10001:10001"`) | Ensures process does not execute as UID 0, limiting kernel attack surface. |
| **Read-Only Root Filesystem** | CIS Docker 5.12 (`read_only: true`) | Prevents adversaries or malware from modifying binaries or dropping scripts. |
| **Drop All Capabilities** | CIS Docker 5.2 (`cap_drop: ["ALL"]`) | Removes default Linux capabilities (`CAP_NET_RAW`, `CAP_CHOWN`, etc.). |
| **Prevent Privilege Escalation** | CIS Docker 5.25 (`security_opt: ["no-new-privileges:true"]`) | Prevents processes from acquiring additional privileges via `setuid`/`setgid` binaries. |
| **Ephemeral Memory Storage** | Security Best Practice (`tmpfs: ["/tmp"]`) | Provides volatile in-memory storage for temporary files without weakening rootfs immutability. |

---

## 🛠️ Step-by-Step Instructions

### 1. Review the Vulnerable Configuration

Inspect the existing vulnerable configuration at `/assets/docker-compose.yml`:

```bash
cat /assets/docker-compose.yml
```

Notice the presence of the Docker socket volume and the absence of capability restrictions and read-only flags.

### 2. Create the Hardened Compose File

Create the new hardened configuration file at `/assets/docker-compose.hardened.yml`:

```bash
cat << "EOF" > /assets/docker-compose.hardened.yml
version: '3.8'

services:
  cicd_runner_pipeline:
    container_name: cicd_runner_pipeline
    image: alan-turing/cicd-runner:vulnerable
    restart: unless-stopped
    
    # 1. Run as non-root user (created in Dockerfile as UID 10001)
    user: "10001:10001"
    
    # 2. Immutable root filesystem: prevent any writes to /
    read_only: true
    
    # 3. Prevent privilege escalation via setuid binaries
    security_opt:
      - no-new-privileges:true
      
    # 4. Drop all default Linux capabilities
    cap_drop:
      - ALL
      
    # 5. Provide volatile in-memory scratch space for temporary files
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=64m
      
    environment:
      - RUNNER_NAME=worker-01
      - RUNNER_ORGANIZATION=AlanTuring-SecOps
      - CI_ENVIRONMENT=production

    # NOTE: The /var/run/docker.sock volume has been completely removed!
EOF
```

Verify that the file is created:

```bash
cat /assets/docker-compose.hardened.yml
```

### 3. Deploy the Hardened Container Stack

Recreate the container stack using your hardened definition. Use the `--force-recreate` flag to ensure the old container is replaced:

```bash
docker compose -f /assets/docker-compose.hardened.yml up -d --force-recreate
```

Verify that the new container is running:

```bash
docker ps
```

### 4. Verify Hardening Controls Inside the Container

Test the defenses you have established:

#### Test A: Immutability (Read-Only Root Filesystem)
Attempt to create a file in the root filesystem:

```bash
docker exec cicd_runner_pipeline touch /malicious_payload
```

**Expected Result:** `touch: /malicious_payload: Read-only file system`

#### Test B: Non-Root Execution
Check the current user ID and group ID:

```bash
docker exec cicd_runner_pipeline id
```

**Expected Result:** `uid=10001(cicduser) gid=10001(cicdgroup)`

#### Test C: Absence of Docker Socket
Verify that `/var/run/docker.sock` no longer exists:

```bash
docker exec cicd_runner_pipeline ls -la /var/run/docker.sock
```

**Expected Result:** `ls: /var/run/docker.sock: No such file or directory`

#### Test D: Functional Ephemeral Scratch Space
Verify that temporary operations can still write to `/tmp`:

```bash
docker exec cicd_runner_pipeline touch /tmp/test_scratch && echo "Scratch space works!"
```

**Expected Result:** `Scratch space works!`

---

## 🔍 DevSecOps Key Takeaway

> By combining `read_only: true`, `cap_drop: ["ALL"]`, `no-new-privileges:true`, and non-root execution, you transform a fragile container into a resilient, hardened workload. Even if an adversary achieves arbitrary code execution inside the container, they cannot drop persistent malware, tamper with runtime binaries, or interact with host kernel capabilities.

---

## ✅ Verification

Click the **Check** button below or run the verification script directly from your terminal:

```bash
/step4/verify.sh
```
