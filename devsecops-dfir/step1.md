# Challenge 1: Poisoned Pipeline Execution & Process Memory Harvesting

**Time Allocation: 12 - 15 minutes**

---

## Threat Modeling: In-Memory Credential Exposure

Under the Poisoned Pipeline Execution (PPE) taxonomy (MITRE ATT&CK [T1195.002](https://attack.mitre.org/techniques/T1195/002/)), unreviewed or malicious Pull Requests executed within continuous integration build nodes can interrogate the execution environment. A frequent architectural deficiency in automated runners is the injection of static deployment secrets directly into the initial executor process or container entrypoint wrapper.

When build tasks execute within the container:
- Child sessions spawned via secondary channels (such as subshells or `docker exec` sessions) often run with sanitized or restricted environment tables, giving operators a false impression that parent secrets are concealed.
- However, standard Linux container isolation relies on namespaces. When tasks share a common PID namespace, all processes possess read access to the pseudo-filesystem `/proc` for processes running under the same UID (or as root).
- The Linux kernel exposes initial process environment blocks via `/proc/[PID]/environ`.

---

## Kernel Architecture: Memory Layout of `/proc/[PID]/environ`

The `/proc/[PID]/environ` file is a virtual interface generated dynamically by the Linux kernel from the process memory descriptors:
- The kernel reads the memory address range bounded by `mm_struct->env_start` and `mm_struct->env_end` in the target process address space.
- Format: Under POSIX standards, the environment block consists of consecutive `KEY=VALUE` assignments terminated by a null byte (`\x00` / ASCII 0), rather than standard line-break characters (`\n`).
- Binary Stream Behavior: Because standard text filters (`grep`, `tail`, `less`) interpret null bytes as binary delimiters or string terminators, passing raw pseudo-files directly to line-based utilities can lead to truncated reads or unstructured binary dumps.

To transform this memory stream into searchable, line-delimited records, leverage standard POSIX stream manipulation tools:
- `tr(1)`: Translate characters across byte boundaries (e.g., mapping `\0` to `\n`).
- `strings(1)`: Scan binary byte streams and extract sequences of printable characters.
- `awk(1)`: Re-parse field records using custom record separators (`RS="\0"`).

---

## Technical Objectives

1. Attach an interactive shell to the active workload container: `cicd_runner_pipeline`.
2. Enumerate the process table to map process lineage and identify the PID of the root pipeline daemon.
3. Inspect the virtual memory environment mapping of PID 1 under `/proc`.
4. Transform the null-terminated byte stream into line-delimited text and isolate the production credential associated with `DEPLOY_PRODUCTION_KEY`.
5. Exit the container and write the isolated token to `/tmp/flag1.txt` on the host machine.

---

## Execution Guidelines

### 1. Workload Attachment and Process Mapping
Access `cicd_runner_pipeline` using `docker exec`. Inspect running processes using `ps -ef` or `ps aux`. Differentiate between transient subshell processes and the persistent daemon executing as the namespace root (PID 1).

### 2. Environment Stream Interrogation
Inspect `/proc/1/environ`. Observe that querying `env` inside your current subshell does not reveal parent variables, but reading the memory structure of PID 1 exposes the underlying assignments passed during container initialization.

Using POSIX stream manipulation (`tr(1)`, `strings(1)`, or equivalent utilities), format the stream into individual lines and filter for the assignment key prefix `DEPLOY_` or the standard flag format `FLAG{...}`.

### 3. Artifact Extraction
Return to the host environment shell (`exit`) and store the captured credential in `/tmp/flag1.txt`:

```text
Deliverable: /tmp/flag1.txt
Content:     FLAG{...}
```

---

## Verification Requirements

Ensure `/tmp/flag1.txt` exists on the host and contains the exact flag string. Trigger the automated evaluation script:

```bash
/step1/verify.sh
```
