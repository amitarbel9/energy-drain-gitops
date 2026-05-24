# Language Learning GitOps

This repository contains a GitOps-oriented Kubernetes deployment for a language learning application.

## Repository Structure

- `k8s/`
  - `namespace.yaml` - Namespace definition for `lingua-app`
  - `backend-deployment.yaml` - Backend app deployment manifest
  - `backend-service.yaml` - Backend service manifest
  - `nginx-deployment.yaml` - Frontend proxy deployment manifest
  - `nginx-service.yaml` - Frontend service manifest

## Current Deployment

The current manifests deploy the following components into the `lingua-app` namespace:

- `backend`
  - `Deployment` using image `lingua-backend:1.0.0`
  - `ClusterIP` service on port `5000`
  - Health probes and resource requests/limits configured

- `nginx`
  - `Deployment` using image `lingua-nginx:1.0.2`
  - `NodePort` service on port `80` exposed at node port `30080`
  - Health probes and resource requests/limits configured

## GitOps Workflow

This repository is intended to serve as the source of truth for Kubernetes manifests.
Changes should be made via Git and applied through a GitOps operator.

### Current process

1. Edit YAML manifests in `k8s/`
2. Commit and push changes to the repository
3. Apply manifests with `kubectl` or from a GitOps operator

## Future Enhancements

This repo is planned to evolve with the following additions:

- `Argo CD` integration
  - Declarative application sync
  - GitOps automation for cluster delivery
  - Application manifests and Argo CD app definitions

- `Helm` chart support
  - Parameterized chart packaging for the backend and nginx services
  - Values files for environment-specific configuration
  - Better reuse and templating of Kubernetes resources

## Getting Started

To deploy the current manifests manually:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/nginx-deployment.yaml
kubectl apply -f k8s/nginx-service.yaml
```

> Note: The current container images are configured with `imagePullPolicy: Never`, which is useful for local development with built images available on the node.

## Notes

- The backend expects MongoDB at `mongodb://host.docker.internal:27017`.
- The frontend `nginx` service is currently exposed via `NodePort` on `30080`.

## Contribution

Feel free to add Argo CD application manifests or Helm charts to this repo.
A recommended future structure could be:

- `argocd/`
- `charts/`
- `environments/`
- `k8s/`

Once Argo CD and Helm are added, update this README with installation and sync instructions.
