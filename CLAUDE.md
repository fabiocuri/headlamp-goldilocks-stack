# Project context for Claude Code

This file is auto-loaded by Claude Code. It captures the state and decisions from
the session that created this repo, so a fresh session can continue seamlessly.

## What this repo is
A **local Kubernetes observability + rightsizing playground**: a minikube cluster
with **Headlamp** (management dashboard) and **Goldilocks** (rightsizing, backed by
the VPA recommender + metrics-server). See `README.md` for the full write-up.

Origin story: the user was looking for a tool like a Kubernetes dashboard they saw
in a screenshot (workloads/pods/logs/CPU/RAM + a "Current vs Recommended plan"
panel). That turned out to be unrelated to the `linuxserver/Heimdall` app-dashboard
repo they had cloned. Headlamp + Goldilocks reproduce those capabilities with OSS.

## Current local state (as of creation)
- **minikube cluster is running** (reused an existing long-lived profile; metrics-server enabled).
- Deployed via `install.sh`:
  - `demo` namespace: `web-frontend` (2x nginx, over-provisioned), `cpu-worker`, `log-spitter`.
  - `headlamp` ns: Headlamp + a `headlamp-admin` ClusterRoleBinding (cluster-admin).
  - `vpa` ns: VPA **recommender only**.
  - `goldilocks` ns: Goldilocks controller + dashboard.
- Goldilocks already produced recommendations for the `demo` namespace.
- Pre-existing, NOT created here: `default/fastapi-app`, `default/mongodb`, and a
  `litellm` deployment stuck in **CrashLoopBackOff** (~76 days old). Leave alone unless asked.

## How to bring up the dashboards
```bash
./install.sh        # only needed once / after teardown (idempotent)
./dashboards.sh up  # start port-forwards
./dashboards.sh token   # Headlamp login token (paste into the "Token" login)
```
- Headlamp → http://localhost:8091
- Goldilocks → http://localhost:8092/namespaces  (click the `demo` namespace)

## Conventions & gotchas (important)
- **Commit messages: do NOT add a Claude `Co-Authored-By` trailer.** (Explicit user preference.)
- **Git remote / SSH:** push uses the SSH host alias **`github-fabiocuri`**
  (configured in `~/.ssh/config`). The string `github-fabio` does NOT resolve.
  Remote: `git@github-fabiocuri:fabiocuri/headlamp-goldilocks-stack.git`.
- **`kubectl` is the snap build** and has a quirk where some `kubectl get ... -n <ns>`
  calls print empty stdout. Workaround: use `kubectl get <res> -A | grep <ns>` or pipe to `cat`.
- VPA is installed **recommender-only** on purpose: the admission-controller/updater
  webhook-cert hook is flaky on minikube and Goldilocks doesn't need it.

## Possible next steps (not done yet)
- Add **Prometheus + Grafana** for richer, long-history CPU/RAM dashboards.
- Point Headlamp at a **real** cluster (install the Helm chart there, or use the desktop app).
