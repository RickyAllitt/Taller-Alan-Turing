# Challenge 1: Poisoned Pipeline Execution & Process Memory Harvesting

## Threat Modeling: In-Memory Credential Exposure

Under the Poisoned Pipeline Execution (PPE) taxonomy (MITRE ATT&CK [T1195.002](https://attack.mitre.org/techniques/T1195/002/)), untrusted code execution within a continuous integration build runner allows adversaries to inspect the container environment. A widespread architectural deficiency in CI/CD pipeline agents involves injecting high-privilege secrets directly into the initial executor process or container entrypoint.

When an unprivileged build job or subshell executes within the same container namespace:
- Child sessions spawned via secondary execution channels (such as supplementary shells or task runners) do not necessarily inherit variables that were unexported or cleared by child wrappers.
- However, Linux process isolation boundaries inside a container depend entirely on namespaces. When containers run without internal PID namespace virtualization, all processes share a common `/proc` view.
- Under the Linux pseudo-filesystem `/proc`, the virtual file `/proc/[PID]/environ` exposes the initial environment block passed to `execve(2)` when that process was created.

---

## Technical Objectives

1. Access the target workload container named `cicd_runner_pipeline`.
2. Inspect the process hierarchy and determine the process identifier (PID) of the primary worker daemon.
3. Interrogate the process memory structures exposed by the Linux kernel under `/proc` to identify leaked production credentials.
4. Extract the value associated with the variable `DEPLOY_PRODUCTION_KEY`.
5. Persist the recovered secret into `/tmp/flag1.txt` on the host filesystem.

---

## Investigation Vectors and Execution Guidelines

### Process Tree Enumeration
Spawn an interactive shell within the target runner container using `docker exec`. Once inside, evaluate the active process table using standard POSIX process enumeration utilities (such as `ps`). Note the distinction between short-lived worker commands and long-running daemons executing at the root of the container namespace (PID 1).

### Memory Block Parsing
Examine the process environment table corresponding to the initial daemon process.

In the Linux kernel, `/proc/[PID]/environ` represents an array of null-byte (`0x00` / ASCII `\0`) delimited key-value strings (`KEY=VALUE\0KEY2=VALUE2...`). Because standard shell utilities treat null bytes as string terminators or non-printable delimiters, executing standard line-oriented commands like `grep` directly against raw pseudo-files will often fail to produce parsed records or will return the entire stream as a single binary blob.

Determine which native text-processing tools (such as `tr(1)`, `strings(1)`, `awk(1)`, or `sed(1)`) allow you to translate null-byte delimiters into standard newline characters (`\n`), enabling precise regular expression filtering.

### Key Recovery
Filter the parsed output for variables prefixed with `DEPLOY_` or containing standard flag encodings (`FLAG{...}`).

---

## Verification Requirements

Return to the host environment and write the isolated flag string into `/tmp/flag1.txt`:

```text
Target File: /tmp/flag1.txt
Expected Format: FLAG{...}
```

Once written, execute the verification check using the Killercoda interface or by invoking:

```bash
/step1/verify.sh
```
