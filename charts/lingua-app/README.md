# Lingua App Helm Chart

Kubernetes Helm chart for deploying the Language Learning application to AWS EKS or any Kubernetes cluster.

## Features

- Multi-environment support (staging and production)
- Parameterized configuration for easy customization
- No in-cluster MongoDB (uses external database services)
- Support for Ingress, LoadBalancer, and NodePort service types
- Flexible resource limits for different environments
- AWS-ready environment variables

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- External database (MongoDB Atlas, AWS RDS, or DynamoDB)

## Installation

### 1. Add Chart Repository (Optional, if hosting remotely)

```bash
helm repo add lingua-charts https://your-repo-url
helm repo update
```

### 2. Install for Development/Local

```bash
helm install lingua-app charts/lingua-app -n lingua-app --create-namespace
```

### 3. Install for Staging (AWS)

```bash
helm install lingua-app charts/lingua-app \
  -f charts/lingua-app/values-staging.yaml \
  -n lingua-app-staging \
  --create-namespace
```

### 4. Install for Production (AWS)

```bash
helm install lingua-app charts/lingua-app \
  -f charts/lingua-app/values-prod.yaml \
  -n lingua-app-prod \
  --create-namespace
```

## Upgrade

```bash
# Upgrade with staging values
helm upgrade lingua-app charts/lingua-app \
  -f charts/lingua-app/values-staging.yaml \
  -n lingua-app-staging
```

## Configuration

### Key Values

All configuration is in `values.yaml`, `values-staging.yaml`, and `values-prod.yaml`.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `namespace.name` | `lingua-app` | Kubernetes namespace |
| `backend.replicas` | `1` | Backend pod replicas |
| `backend.image.tag` | `1.0.0` | Backend image tag |
| `backend.database.mongoUrl` | `mongodb://mongodb:27017` | Database connection URL |
| `nginx.replicas` | `1` | Nginx pod replicas |
| `nginx.service.type` | `NodePort` | Service type (NodePort, LoadBalancer, ClusterIP) |
| `ingress.enabled` | `false` | Enable Ingress |

### Database Configuration

For AWS environments, update the `backend.database.mongoUrl`:

**For MongoDB Atlas:**
```yaml
backend:
  database:
    mongoUrl: "mongodb+srv://username:password@cluster.mongodb.net/dbname"
```

**For DynamoDB** (update backend app code to use AWS SDK):
```yaml
backend:
  env:
    - name: DYNAMODB_TABLE
      value: "lingua-words"
    - name: AWS_REGION
      value: "us-east-1"
```

### Environment Variables

Add custom environment variables in values files:

```yaml
backend:
  env:
    - name: LOG_LEVEL
      value: "debug"
    - name: AWS_REGION
      value: "us-east-1"
```

## Validation

Lint the chart:

```bash
helm lint charts/lingua-app
```

Template rendering (preview):

```bash
helm template lingua-app charts/lingua-app -f charts/lingua-app/values-staging.yaml
```

## Uninstall

```bash
helm uninstall lingua-app -n lingua-app
```

## File Structure

```
charts/lingua-app/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default values
├── values-staging.yaml        # Staging-specific values
├── values-prod.yaml           # Production-specific values
├── README.md                  # This file
└── templates/
    ├── _helpers.tpl           # Template helpers
    ├── namespace.yaml         # Namespace resource
    ├── backend-deployment.yaml    # Backend deployment
    ├── backend-service.yaml       # Backend service
    ├── nginx-deployment.yaml      # Nginx deployment
    ├── nginx-service.yaml         # Nginx service
    └── ingress.yaml           # Ingress (optional)
```

## Next Steps

1. **Configure Database**: Update `mongoUrl` in `values-staging.yaml` and `values-prod.yaml` to point to your external database
2. **Set Up Ingress**: Update domain names in `values-staging.yaml` and `values-prod.yaml`
3. **Add AWS Credentials**: If using DynamoDB, configure AWS IAM roles via IRSA or environment variables
4. **Integrate with ArgoCD**: Create ArgoCD `Application` manifests to deploy this chart

## Support

For issues or questions, refer to the main repository: https://github.com/your-org/language-learning-gitops

## License

[Your License Here]
