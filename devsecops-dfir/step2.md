# Challenge 2: Docker Daemon Socket Breakout & Host Escape

**Time Allocation: 15 - 18 minutes**

---

## Architectural Vulnerability: Docker Client-Server Daemon Model

In automated CI/CD environments, pipeline workflows often need to build and publish container images. To avoid running complex nested virtualization, administrators frequently implement **Docker-outside-of-Docker (DooD)** by mounting the host's Docker socket into the runner container:

```text
Host Architecture                     Container Workload
┌───────────────────────────────┐     ┌───────────────────────────────┐
│ dockerd (Host Root: UID 0)    │     │ Container User / Shell        │
│    │                          │     │    │                          │
│    └── /var/run/docker.sock ◄─┼─────┼────└── /var/run/docker.sock   │
└───────────────────────────────┘     └───────────────────────────────┘
```

### IPC Privilege Boundary Collapse

The Docker architecture is decoupled into a client CLI (`docker`) and a background daemon (`dockerd`):
- Communication occurs via the UNIX domain socket located at `/var/run/docker.sock`.
- The daemon executes on the host with native root authority (`UID 0`).
- By default, access to this socket does not enforce fine-grained access control or command filtering. Any process capable of writing to `/var/run/docker.sock` can instruct the host daemon to provision containers, mount underlying host storage devices, and disable kernel containment profiles.
- As cataloged under MITRE ATT&CK [T1611](https://attack.mitre.org/techniques/T1611/), mounting the Docker daemon socket inside an untrusted container collapses the security boundary between guest workload and host operating system.

---

## Technical Objectives

1. Access `cicd_runner_pipeline` and audit the permissions of `/var/run/docker.sock`.
2. Confirm API responsiveness by querying host daemon state through the container's native Docker client.
3. Formulate and launch an unconfined auxiliary container that bind-mounts the host root filesystem (`/`).
4. Transition the execution context into the host root filesystem using `chroot(2)` or direct path traversal.
5. Recover the host administrative flag from `/root/host_flag.txt`.
6. Exit the breakout session and store the recovered token in `/tmp/flag2.txt` on the host.

---

## Execution Guidelines

### 1. Socket Audit and IPC Verification
From inside `cicd_runner_pipeline`, verify that the UNIX socket file exists in `/var/run/` and confirm read/write permissions (`srw-rw----`). Execute `docker ps` from within the runner. Observe that the returned container list includes sibling workloads running on the host system, demonstrating uninhibited communication with `dockerd`.

### 2. Breakout Container Formulation
To escape the runner's isolated mount namespace, construct a `docker run` command submitted to the host daemon:
- **Base Image**: Select an existing minimal utility image pre-cached on the system (such as `alpine`).
- **Filesystem Mapping**: Use the volume parameter (`-v` or `--mount`) to map the host machine's absolute root directory (`/`) into a target directory within the auxiliary container (such as `/mnt/host`).
- **Execution Context**: Execute an interactive shell within the auxiliary container. To interact with the host operating system directly, apply `chroot(8)` against your mounted directory to redefine the apparent root directory for the current subshell process. Alternatively, investigate namespace-switching primitives using `nsenter(1)`.

### 3. Host Flag Extraction
Once inside the host filesystem context, inspect the contents of `/root/host_flag.txt`. Record the full flag string.

### 4. Cleanup and Deliverable Persistence
Terminate the auxiliary breakout container and exit the runner container session. On the host terminal, write the captured token into `/tmp/flag2.txt`:

```text
Deliverable: /tmp/flag2.txt
Content:     FLAG{...}
```

---

## Verification Requirements

Ensure `/tmp/flag2.txt` contains the host flag string. Run the verification harness:

```bash
/step2/verify.sh
```
