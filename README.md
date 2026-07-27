# Energy Drain GitOps

This repository contains the GitOps configuration for the Energy Drain application — an app that lets users log and track the things in life that drain their energy.

It uses a Helm chart for packaging, ArgoCD for automated GitOps delivery across two separate AWS EKS clusters, and a three-pipeline CI/CD system that enforces a tested-commit-only policy for production.

## Repository Structure

```
charts/energy-drain-app/       Helm chart for the application
  values.yaml                  Base defaults (local/Kind dev)
  values-staging.yaml          Staging overrides (image tags, resources, hostname)
  values-production.yaml       Production overrides (image tags, resources, hostname)
argocd/                        ArgoCD Application manifests (bootstrap — applied manually once)
  energy-drain-staging.yaml    Staging app — tracks the staging branch
  energy-drain-production.yaml Production app — tracks the production branch
  external-dns-production.yaml external-dns for production Route 53 management
.github/workflows/
  gitops-ci.yml                CI: lint/validate/smoke → promote to staging
  gitops-cd.yml                CD tests: validates the live staging environment
  gitops-promote.yml           Promote to Production: human-triggered
```

## Environments

| | Staging | Production |
|---|---|---|
| **URL** | _(see `values-staging.yaml`)_ | _(see `values-production.yaml`)_ |
| **EKS cluster** | `energy-drain-staging` | `energy-drain-production` |
| **Namespace** | `energy-drain-staging` | `energy-drain-production` |
| **ArgoCD branch** | `staging` | `production` |
| **Promoted by** | CI on every passing `main` push | Manual "Promote to Production" workflow |
| **Region** | `ap-south-1` | `ap-south-1` |

## What Gets Deployed

The chart deploys the following into each environment's namespace:

- **backend** — Flask application that handles auth and entry logging. `ClusterIP` service on port `5000`. Uses IRSA + Secrets Store CSI driver to pull `MONGO_URL` from AWS Secrets Manager.
- **nginx** — Frontend reverse proxy. Internet-facing AWS ALB Ingress with HTTPS redirect and ACM certificate.
- **ServiceMonitor** — Wired to the `kube-prometheus-stack` in the `monitoring` namespace for Prometheus scraping and Grafana dashboards.

On production only, **external-dns** runs as a separate ArgoCD Application and syncs the production Route 53 A record to the ALB automatically.

## Pipeline Architecture

Three workflows, each with a distinct role:

### 1. CI Pipeline (`gitops-ci.yml`)
Triggers on every push to `main`. Jobs run in sequence, plus three security scans that run independently alongside them:

1. **helm-lint** — validates chart syntax
2. **helm-template** — renders manifests and uploads as artifact
3. **kubeconform** — validates rendered manifests against Kubernetes schemas
4. **yamllint** — checks YAML formatting
5. **smoke-test** — installs the chart into a temporary Kind cluster and verifies pods, services, and ingress become healthy
6. **notify** — sends a full pipeline summary email
7. **promote** — on success only, fast-forwards the `staging` branch to `main`; the staging ArgoCD instance picks this up and syncs

Security scans (all block `promote` on failure, same as the jobs above):

- **secret-scan** — [gitleaks](https://github.com/gitleaks/gitleaks), scans the full git history on every push for accidentally-committed secrets. Also runs as a `pre-commit` hook (`pre-commit install` once locally) so this is caught before it's even committed, not just in CI.
- **iac-scan** — [Checkov](https://www.checkov.io/), scans the Helm chart's rendered Kubernetes manifests for misconfigurations. Six checks are explicitly skipped with reasoning in the workflow file - each is a deliberate, already-tested tradeoff (e.g. nginx must run as root to bind port 80), not an oversight.
- **workflow-scan** — [zizmor](https://docs.zizmor.sh/), statically audits these three workflow files themselves for CI/CD-specific issues (script injection via untrusted context values, overly broad permissions, credential handling). Config and reasoning for anything disabled: `.github/zizmor.yml`.

### 2. CD Tests (`gitops-cd.yml`)
Triggers ~2 minutes after the CI pipeline succeeds on `main` (allowing ArgoCD to sync staging). Tests the **live staging environment**, covering things CI cannot see (real DocumentDB TLS, Secrets Manager, ALB, DNS, OAuth config).

| Suite | Runs when |
|---|---|
| Smoke tests | Every deploy (DNS, health endpoint, TLS, DB connectivity) |
| API acceptance | Every deploy (OAuth config, auth endpoints, access control) |
| Certificate expiry | Every deploy (alerts if cert expires within 30 days) |
| Monitoring checks | Every deploy, requires `AWS_OIDC_ROLE_ARN` secret |
| Rollback drill | Every 5th deploy — injects drift, verifies ArgoCD selfHeal reverts it |
| Performance tests | Weekly (Mondays 06:00 UTC) |

### 3. Promote to Production (`gitops-promote.yml`)
Manual `workflow_dispatch`. Running this workflow is the production approval gate.

1. Resolves the SHA from the latest fully successful CD test run (or takes an explicit SHA input)
2. Syncs image tags from `values-staging.yaml` into `values-production.yaml` — production always runs the tested staging images
3. Fast-forwards the `production` branch to that SHA
4. Production ArgoCD (auto-sync on the `production` branch) picks up the change and deploys within ~3 minutes
5. Runs production smoke tests post-deploy (skipped if the production hostname doesn't resolve yet)

## GitOps Workflow

```text
Push to main
     │
     ▼
CI Pipeline (lint → template → kubeconform → yamllint → smoke-test)
     │ success
     ▼
staging branch fast-forwarded
     │
     ▼
Staging ArgoCD syncs (values-staging.yaml, energy-drain-staging namespace)
     │ ~2 min
     ▼
CD Tests run against the staging hostname
     │ all suites pass
     ▼
Human runs "Promote to Production" workflow (Actions tab)
     │
     ▼
production branch fast-forwarded (image tags synced from staging)
     │
     ▼
Production ArgoCD syncs (values-production.yaml, energy-drain-production namespace)
     │
     ▼
Production hostname serves the promoted build
```

**Branch model:**
- `main` — source of truth for all changes
- `staging` — always equals the last CI-passing commit of `main`; never commit here directly
- `production` — always equals the last CD-tested commit; never commit here directly; rollback = move this pointer back one commit

## DNS: external-dns

Both clusters use AWS ALB Ingress. DNS management differs per environment:

- **Staging** — external-dns was installed out-of-band on the staging cluster. It watches Ingress resources and auto-creates the Route 53 A record for the staging hostname.
- **Production** — external-dns is deployed as an ArgoCD Application (`argocd/external-dns-production.yaml`), using IRSA role `energy-drain-production-external-dns` to write the Route 53 record for the production hostname.

The `external-dns-production` ArgoCD Application is a **bootstrap manifest** — it must be applied manually once when setting up the production cluster (see Disaster Recovery below). It is not applied by the CI/CD pipelines.

## Monitoring

`kube-prometheus-stack` is installed separately into the `monitoring` namespace on each cluster. The Helm chart provisions a Grafana dashboard on every deployment via a labelled ConfigMap picked up by the Grafana sidecar.

Metrics tracked:
- Pod CPU and memory usage
- Number of healthy and total Prometheus targets
- Number of pods running
- Number of HTTP requests
- Number of energy-drain entries created

## Staging Database Secret Contract

The staging backend's `MONGO_URL` lives in AWS Secrets Manager (`staging/energy-drain/mongo-url`, region `ap-south-1`) and is synced into the cluster by the Secrets Store CSI driver. Two rules keep it from breaking:

1. **Never edit the secret by hand** — use `scripts/set-staging-mongo-secret.sh`, which validates the value (requires `tls=true` and `retryWrites=false`, rejects `tlsCAFile`). The Helm chart appends `&tlsCAFile=<backend.docdbCa.mountPath>/global-bundle.pem` at deploy time, so the secret must hold the base URL only.

2. **Restart the backend after changing it** — the CSI driver only re-reads Secrets Manager when a pod mounts the volume:

   ```bash
   kubectl rollout restart deployment/energy-drain-staging-energy-drain-app-backend -n energy-drain-staging
   ```

## Disaster Recovery (cluster rebuild checklist)

Everything ArgoCD manages is recovered from git, but the following live outside GitOps and must exist before the app can become healthy.

### Both clusters

1. **ArgoCD itself** + repo credentials for this (private) repo:

   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl create secret generic repo-energy-drain-gitops -n argocd \
     --from-literal=type=git \
     --from-literal=url=https://github.com/mild-byte/energy-drain-gitops.git \
     --from-literal=username=git \
     --from-literal=password=<GitHub PAT with read access to this repo>
   kubectl label secret repo-energy-drain-gitops -n argocd argocd.argoproj.io/secret-type=repository
   ```

2. **kube-prometheus-stack** (provides the ServiceMonitor CRD; the app sync fails without it):

   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --create-namespace \
     --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
     --set alertmanager.enabled=false \
     --set grafana.adminPassword=admin
   ```
   Do NOT omit `serviceMonitorSelectorNilUsesHelmValues=false` — without it Prometheus silently ignores the app's ServiceMonitor.

3. **ECR images** — the tags referenced in the values files must exist in ECR (`523555653711.dkr.ecr.ap-south-1.amazonaws.com`). If the registry was wiped, re-run the latest CI build in `mild-byte/energy-drain-app`.

### Staging cluster

4. Apply the staging ArgoCD Application:

   ```bash
   kubectl apply -f argocd/energy-drain-staging.yaml
   ```

5. **ACM certificate** for the staging hostname in `ap-south-1`. If re-issued, update `alb.ingress.kubernetes.io/certificate-arn` in `values-staging.yaml`.

6. **The MONGO_URL secret** — `scripts/set-staging-mongo-secret.sh`.

### Production cluster

4. Apply the production ArgoCD Applications (bootstrap — not managed by CI/CD):

   ```bash
   kubectl apply -f argocd/energy-drain-production.yaml
   kubectl apply -f argocd/external-dns-production.yaml
   ```

5. **ACM certificate** for the production hostname in `ap-south-1`. If re-issued, update `alb.ingress.kubernetes.io/certificate-arn` in `values-production.yaml`.

6. **The MONGO_URL secret** — `production/energy-drain/mongo-url` in Secrets Manager.

7. **IRSA roles** must exist before the pods start:
   - `energy-drain-production-secrets-csi` — grants backend access to Secrets Manager
   - `energy-drain-production-external-dns` — grants external-dns access to Route 53

   The namespace `energy-drain-production` is locked by the IRSA trust policy of `energy-drain-production-secrets-csi` — do not rename it.

Note: the `production` ArgoCD Application (`energy-drain-production.yaml`) has `automated` sync enabled. Once applied, it deploys immediately from the `production` branch. The first deployment after a cluster rebuild will use whatever commit `production` currently points to.
