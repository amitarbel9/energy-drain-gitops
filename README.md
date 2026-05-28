# Language Learning GitOps

This repository contains a GitOps-oriented Kubernetes deployment for a language learning application.

It includes both the traditional `k8s/` manifests and the beginnings of a Helm/Argo CD-based delivery model in `charts/` and `argocd/`.

## Repository Structure

- `k8s/`
  - `namespace.yaml` - Namespace definition for `lingua-app`
  - `backend-deployment.yaml` - Backend app deployment manifest
  - `backend-service.yaml` - Backend service manifest
  - `nginx-deployment.yaml` - Frontend proxy deployment manifest
  - `nginx-service.yaml` - Frontend service manifest
- `charts/` - Helm chart for the application
- `argocd/` - Argo CD application manifest for GitOps delivery

## Current Deployment

The current manifests deploy the following components into the `lingua-app` namespace:

- `backend`
  - `Deployment` using image `lingua-backend:x.y.z`
  - `ClusterIP` service on port `5000`
  - Health probes and resource requests/limits configured

- `nginx`
  - `Deployment` using image `lingua-nginx:x.y.z`
  - `Ingress` service on port `80`
  - Health probes and resource requests/limits configured

## AWS Deployment Roadmap

This repository is planned to support AWS deployment with ingress rather than `NodePort`.
The future AWS setup will use:

- AWS Load Balancer or ALB/Ingress Controller
- Kubernetes `Ingress` resources instead of `NodePort`
- Environment-specific Helm values for staging and production
- Argo CD to sync Git changes into the cluster automatically

## GitOps Workflow

GitOps makes this application easier to manage by treating Git as the single source of truth.
All Kubernetes configuration and deployment changes are captured in version control, reviewed in pull requests, and automatically reconciled by Argo CD.

### Why GitOps for this application

- Consistency: deployments are reproducible from Git history
- Auditability: every change is traceable to commits and PRs
- Safety: drift is detected and corrected automatically
- Speed: automated sync removes manual `kubectl apply` steps

### Simple workflow blueprint

```text
Developer
   │
   ▼
Git repository (source of truth)
   │
   ▼
Argo CD / GitOps operator
   │
   ▼
Kubernetes cluster
   │
   └─▶ drift detection + reconciliation
```

1. Change application configuration or manifest source in Git (`k8s/`, `charts/`, or `argocd/`)
2. Commit and push the change to the repository
3. Argo CD detects the new commit and compares it to the live cluster state
4. Argo CD syncs the cluster to match the declared state
5. The cluster converges to the desired state and drift is corrected continuously

## Future Enhancements

This repo is already moving toward a Helm + Argo CD delivery model:

- `Argo CD` integration
  - Declarative application sync
  - Automated GitOps delivery
  - Application manifest definitions under `argocd/`

- `Helm` chart support
  - Parameterized chart packaging for backend and frontend components
  - Values files for environment-specific configuration
  - Reusable templated Kubernetes resources

## Getting Started

To deploy the current manifests manually:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/nginx-deployment.yaml
kubectl apply -f k8s/nginx-service.yaml
```

> Note: The current container images are configured with `imagePullPolicy: Never`, which is useful for local development with locally built images.

## Run Locally from Scratch

A new contributor can run this application locally by following these steps:

Prerequisites:

- `kubectl` installed and configured for a local cluster (Minikube, Kind, Docker Desktop, etc.)
- Docker available to build or run container images
- A running MongoDB instance reachable by the backend
- A Kubernetes cluster with namespace access

Local startup steps:

1. Clone the repository:

    ```bash
    git clone https://github.com/mild-byte/language-learninga-gitops.git   
    cd language-learning-gitops
    ```

2. Build or provide the application images locally if needed:

    ```bash
    # Example if images are built locally
    docker build -t lingua-backend:x.y.z ./path/to/backend
    docker build -t lingua-nginx:x.y.z ./path/to/nginx
    ```

3. Ensure MongoDB is available to the backend. For example, run MongoDB locally or in the cluster and update the backend connection string if needed.

4. Apply the current Kubernetes manifests:

    ```bash
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/backend-deployment.yaml
    kubectl apply -f k8s/backend-service.yaml
    kubectl apply -f k8s/nginx-deployment.yaml
    kubectl apply -f k8s/nginx-service.yaml
    ```

5. Confirm the services are running:

    ```bash
    kubectl get all -n lingua-app
    kubectl get svc -n lingua-app
    ```

6. Access the frontend:

    - If using `NodePort`, open `http://<node-ip>:30080`
    - If your local cluster supports `host.docker.internal`, use that host and port `30080`
    - Alternatively, use `kubectl port-forward svc/nginx 8080:80 -n lingua-app` and open `http://localhost:8080`

## Notes

- The backend currently expects MongoDB at `mongodb://host.docker.internal:27017`.
- The frontend `nginx` service is currently exposed via `NodePort` on `30080`.
- AWS deployment will eventually replace `NodePort` with `Ingress` and load balancers.

## Contribution

Contributions are welcome for Argo CD application manifests, Helm charts, or AWS ingress support.
A recommended future structure could be:

- `argocd/`
- `charts/`
- `environments/`
- `k8s/`

Once Argo CD and Helm are fully enabled, update this README with installation, sync, and AWS deployment instructions.
# test
