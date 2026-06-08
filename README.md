# Energy Drain GitOps

This repository contains a GitOps-oriented Kubernetes deployment for the Energy Drain application — an app that logs the things in life that drain your energy.

It uses a Helm chart for packaging, Argo CD for automated GitOps delivery, and a CI pipeline for validation before every deployment.

## Repository Structure

- `charts/energy-drain-app/` - Helm chart for the application
- `argocd/` - Argo CD application manifest for GitOps delivery
- `monitoring/` - Grafana dashboard definition

## What the App Does

Energy Drain is an application that lets users log and track the things that take energy from them. It exposes metrics such as the number of entries created, which are visualised in Grafana.

## Components Deployed

The chart deploys the following into the `energy-drain-app` namespace:

- `backend`
  - Flask application that handles logging entries
  - `ClusterIP` service on port `5000`
  - Health probes and resource limits configured

- `nginx`
  - Frontend proxy
  - `Ingress` on port `80`
  - Health probes and resource limits configured

## Monitoring

Prometheus and Grafana are installed separately via `kube-prometheus-stack` into the `monitoring` namespace. The Helm chart automatically provisions a Grafana dashboard on every deployment via a labelled ConfigMap that the Grafana sidecar picks up.

Metrics tracked:

- Pod CPU and memory usage
- Number of healthy and total Prometheus targets
- Number of pods running
- Number of HTTP requests
- Number of energy-drain entries created

## CI Pipeline

Every push to `main` runs the following jobs in order:

1. **helm-lint** — validates chart syntax and structure
2. **helm-template** — renders manifests and checks for template errors
3. **kubeconform** — validates rendered manifests against Kubernetes schemas
4. **yamllint** — checks YAML formatting consistency
5. **smoke-test** — installs the chart into a temporary Kind cluster and verifies pods, services, and ingress become healthy
6. **notify** — sends a pipeline summary email
7. **promote** — pushes changes to the production branch for Argo CD to pick up

## GitOps Workflow

Git is the single source of truth. All changes go through the CI pipeline before Argo CD reconciles them into the cluster.

```text
Developer
   │
   ▼
Git repository (source of truth)
   │
   ▼
CI Pipeline (lint → template → validate → smoke test)
   │
   ▼
Argo CD
   │
   ▼
Kubernetes cluster
   │
   └─▶ drift detection + reconciliation
```

1. Push a change to `main`
2. CI pipeline validates the change
3. On success, the change is promoted to the production branch
4. Argo CD detects the new commit and syncs the cluster

## Getting Started

Prerequisites:

- `kubectl` configured for a local cluster (Kind, Minikube, Docker Desktop, etc.)
- `helm` v3 installed
- Argo CD installed in the cluster (optional for local dev)

Deploy manually:

```bash
helm install energy-drain-app charts/energy-drain-app \
  --namespace energy-drain-app \
  --create-namespace
```

Install Prometheus and Grafana:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set alertmanager.enabled=false \
  --set grafana.adminPassword=admin \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30300
```

Access Grafana:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open http://localhost:3000 — username: admin, password: admin
```

Confirm the app is running:

```bash
kubectl get all -n energy-drain-app
```

## Contribution

Contributions are welcome for Argo CD application manifests, Helm chart improvements, or monitoring enhancements.
