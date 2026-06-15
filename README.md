# headlamp-goldilocks-stack

A tiny, reproducible **local Kubernetes observability + rightsizing playground**.

It spins up a [minikube](https://minikube.sigs.k8s.io/) cluster and layers on two
open-source web dashboards:

| Tool | What it gives you |
|------|-------------------|
| **[Headlamp](https://headlamp.dev/)** (CNCF) | A management dashboard: browse **Workloads / Pods / Services / Ingress**, view **live logs**, see per-pod **CPU / Memory / Network** graphs, and **restart** pods. |
| **[Goldilocks](https://goldilocks.docs.fairwinds.com/)** (Fairwinds) | A **rightsizing** dashboard: shows **current vs. recommended** CPU/memory requests & limits per workload — the "you asked for X, you really need Y" view. |

Under the hood Goldilocks is powered by the **Vertical Pod Autoscaler (VPA)
recommender**, and the CPU/RAM numbers come from **metrics-server**.

> **Why these two together?** Headlamp answers *"what is my cluster doing right now,
> and let me act on it"*. Goldilocks answers *"are my resource requests sized
> correctly, and what should they be?"*. A management UI + a cost/rightsizing UI.

---

## How the pieces fit

```
        ┌─────────────────────────────────────────────────────┐
        │                  minikube cluster                    │
        │                                                      │
        │   demo namespace        metrics-server (CPU/RAM)     │
        │   ├─ web-frontend ─┐          │                      │
        │   ├─ cpu-worker    │          ▼                      │
        │   └─ log-spitter   │     VPA recommender             │
        │                    │          │                      │
        │                    │          ▼                      │
        │   Headlamp  ◀──────┘     Goldilocks ◀── reads VPA    │
        │   (reads K8s API)         (rightsizing)              │
        └───────┬───────────────────────┬─────────────────────┘
        kubectl port-forward     kubectl port-forward
                │                        │
        http://localhost:8091   http://localhost:8092
```

---

## Prerequisites

You need these on your PATH (all are free):

- [`minikube`](https://minikube.sigs.k8s.io/docs/start/)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
- [`helm`](https://helm.sh/docs/intro/install/)
- A container runtime for minikube (e.g. Docker)

---

## Quick start

```bash
./install.sh        # provision cluster + all components (idempotent)
./dashboards.sh up  # open the port-forwards
./dashboards.sh token   # print a Headlamp login token
```

Then open:

- **Headlamp** → <http://localhost:8091> — choose **"Token"** and paste the token from `./dashboards.sh token`
- **Goldilocks** → <http://localhost:8092/namespaces> — click the **`demo`** namespace

> Goldilocks needs a few minutes of metrics history before recommendations appear.
> If a workload shows no data, give it a moment and refresh.

---

## What gets deployed

### `demo` namespace (sample workloads — `demo-workloads.yaml`)

| Workload | Purpose |
|----------|---------|
| `web-frontend` (2 replicas, nginx) | Intentionally **over-provisioned** so Goldilocks recommends a smaller size. |
| `cpu-worker` (busybox) | Burns a little CPU continuously so the CPU graphs aren't flat. |
| `log-spitter` (busybox) | Emits a log line every second — handy for testing Headlamp's **Logs** view. |

The namespace is labelled `goldilocks.fairwinds.com/enabled: "true"`, which tells
Goldilocks to generate recommendations for everything in it.

### Components

| Component | Namespace | Installed via |
|-----------|-----------|---------------|
| metrics-server | `kube-system` | minikube addon |
| Headlamp | `headlamp` | Helm (`headlamp/headlamp`) |
| VPA recommender | `vpa` | Helm (`fairwinds-stable/vpa`, recommender-only) |
| Goldilocks (controller + dashboard) | `goldilocks` | Helm (`fairwinds-stable/goldilocks`) |

> **Why recommender-only VPA?** The VPA admission-controller/updater rely on a
> webhook-certificate hook that is flaky on minikube. Goldilocks only needs the
> **recommender**, so we disable the rest for a clean, reliable install.

---

## Managing the stack — `dashboards.sh`

```bash
./dashboards.sh up      # start cluster (if stopped) + both port-forwards
./dashboards.sh down    # stop the port-forwards (cluster keeps running)
./dashboards.sh token   # print a fresh 7-day Headlamp login token
./dashboards.sh stop    # stop the whole minikube cluster
```

Ports (edit at the top of `dashboards.sh` if they clash):

- Headlamp → `8091`
- Goldilocks → `8092`

---

## Add a workload to watch

```bash
kubectl create deployment hello --image=nginx -n demo
```

It appears in Headlamp immediately; Goldilocks picks it up within a few minutes.

---

## Teardown

```bash
./dashboards.sh down            # stop port-forwards
helm uninstall headlamp -n headlamp
helm uninstall goldilocks -n goldilocks
helm uninstall vpa -n vpa
kubectl delete -f demo-workloads.yaml
minikube stop                   # or: minikube delete  (removes the cluster)
```

---

## Notes

- This is a **local learning playground**, not a production setup. Headlamp's
  service account is bound to `cluster-admin` for convenience — don't copy that
  binding to a real cluster.
- To point Headlamp at a **real** cluster instead of minikube, just install the
  Helm chart there (or run the [Headlamp desktop app](https://headlamp.dev/)
  against your kubeconfig).
