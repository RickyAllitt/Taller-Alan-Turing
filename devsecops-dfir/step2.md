# Challenge 2: Docker Daemon Socket Breakout & Host Escape

## Architectural Audit: UNIX Domain Socket Permissions

A frequent configuration anti-pattern in containerized CI/CD build environments is known as **Docker-outside-of-Docker (DooD)**. To allow build steps to assemble and push container images, system administrators frequently mount the host Docker engine's IPC channel into the runner container:

```text
/var/run/docker.sock (Host) -> /var/run/docker.sock (Container)
```

### Privilege Boundary Collapse

The Docker daemon (`dockerd`) executes with host root privileges (`UID 0`). The UNIX domain socket `/var/run/docker.sock` exposes the Docker Engine REST API without granular authorization or role-based access control by default.

When an unprivileged or containerized process is granted write access to this socket:
1. The process can interact directly with the host daemon via the Docker CLI or raw HTTP requests over the UNIX socket.
2. The daemon executes API requests within the host kernel context, not within the requesting container's restricted context.
3. Consequently, write access to `/var/run/docker.sock` is functionally equivalent to unrestricted, passwordless `sudo` on the underlying host system (MITRE ATT&CK [T1611](https://attack.mitre.org/techniques/T1611/)).

---

## Technical Objectives

1. From within `cicd_runner_pipeline`, confirm the presence, filesystem permissions, and responsiveness of the exposed Docker socket.
2. Leverage the local Docker client to orchestrate a breakout container on the host daemon.
3. Establish access to the host's root filesystem.
4. Locate the host security flag located at `/root/host_flag.txt`.
5. Extract and persist the flag value to `/tmp/flag2.txt` on the host machine.

---

## Investigation Vectors and Execution Guidelines

### Socket Verification
Audit the `/var/run/` directory inside `cicd_runner_pipeline`. Inspect the inode type of `docker.sock` (`srw-rw----`) and confirm whether your current container context possesses read and write permissions against it. Use the container's installed `docker` binary to query host daemon state (such as enumerating sibling containers).

### Breakout Mechanics
To traverse from the container execution context to the host filesystem, construct a deployment request directed at the host daemon:
- **Image Selection**: Use a standard minimal utility image present on the host (such as `alpine`).
- **Filesystem Mapping**: Utilize the volume mount flag (`-v` or `--mount`) to bind-mount the host's absolute root directory (`/`) into an arbitrary path inside the newly requested container (e.g., `/mnt/host` or `/host`).
- **Context Transition**: Consider how you will interact with the mounted host filesystem. You may directly reference mounted files, or execute a context switch into the mounted root directory using `chroot(2)` / `chroot(8)` to establish an interactive root shell within the host's operating system environment.

### Flag Retrieval
Identify and read the sensitive administrative flag file on the host filesystem: `/root/host_flag.txt`.

---

## Verification Requirements

Store the recovered flag string in `/tmp/flag2.txt` on the host:

```text
Target File: /tmp/flag2.txt
Expected Format: FLAG{...}
```

Validate the challenge using the Killercoda interface or by executing:

```bash
/step2/verify.sh
```
