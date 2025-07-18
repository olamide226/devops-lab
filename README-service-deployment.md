# Kubernetes Service Deployment Toolkit

This toolkit provides templates and scripts for quickly deploying services in your audience-ns namespace following your organization's established patterns.

## 🎯 What This Toolkit Provides

- **Cookie-cutter templates** following your organization's conventions
- **Automated deployment scripts** for emergency deployments
- **Proper integration** with Istio service mesh
- **HPA configuration** for auto-scaling
- **ArgoCD-compatible labels** for future GitOps integration

## 📁 Files Included

1. **k8s-service-template.yaml** - Generic template with placeholders
2. **hello-world-example.yaml** - Ready-to-deploy example
3. **deploy-service.sh** - Automated deployment script
4. **cleanup-service.sh** - Service removal script

## 🚀 Quick Start

### Option 1: Deploy the Hello World Example

```bash
# Deploy the example hello-world service
kubectl apply -f hello-world-example.yaml

# Check if it's running
kubectl get pods -n audience-ns -l app=hello-world-service

# Access it at: https://dev.lionis.ai/web/hello-world
```

### Option 2: Use the Automated Script

```bash
# Basic usage
./deploy-service.sh my-api nginx:latest 80

# Advanced usage with custom URL and replicas
./deploy-service.sh my-api nginx:latest 80 /api/v1/my-api 3

# Deploy a Node.js app
./deploy-service.sh node-app node:16-alpine 3000 /web/node-app 2
```

### Option 3: Use the Template Manually

1. Copy `k8s-service-template.yaml`
2. Replace all `{{PLACEHOLDER}}` values
3. Apply with `kubectl apply -f your-service.yaml`

## 🔧 Template Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{SERVICE_NAME}}` | Your service name | `my-awesome-api` |
| `{{APP_LABEL}}` | Application label | `my-awesome-api` |
| `{{CONTAINER_IMAGE}}` | Container image | `nginx:latest` |
| `{{CONTAINER_PORT}}` | App port | `8080`, `3000`, `80` |
| `{{SERVICE_PORT}}` | Service port | Usually same as container port |
| `{{URL_PREFIX}}` | URL routing path | `/web/my-app` or `/api/v1/my-app` |
| `{{REPLICAS}}` | Number of replicas | `1`, `2`, `3` |
| `{{CPU_REQUEST}}` | CPU request | `100m`, `500m` |
| `{{MEMORY_REQUEST}}` | Memory request | `128Mi`, `512Mi` |
| `{{CPU_LIMIT}}` | CPU limit | `500m`, `1000m` |
| `{{MEMORY_LIMIT}}` | Memory limit | `256Mi`, `1Gi` |

## 🌐 URL Patterns

Your services will be accessible at:
- **Web apps**: `https://dev.lionis.ai/web/your-service`
- **APIs**: `https://dev.lionis.ai/api/v1/your-service` or `https://dev.lionis.ai/api/v2/your-service`

## 📊 What Gets Created

Each deployment creates:

1. **Deployment** - Manages your pods and replica sets
2. **Service** - Internal cluster networking
3. **VirtualService** - Istio routing configuration
4. **HorizontalPodAutoscaler** - Auto-scaling based on CPU/memory

## 🔍 Monitoring Your Service

```bash
# Check deployment status
kubectl get deployment your-service-deployment -n audience-ns

# View pods
kubectl get pods -n audience-ns -l app=your-service

# Check logs
kubectl logs -f deployment/your-service-deployment -n audience-ns

# Check HPA status
kubectl get hpa your-service-hpa -n audience-ns

# Check Istio routing
kubectl get virtualservice your-service-vs -n default
```

## 🗑️ Cleanup

```bash
# Remove a service completely
./cleanup-service.sh your-service-name

# Or manually
kubectl delete deployment your-service-deployment -n audience-ns
kubectl delete service your-service-svc -n audience-ns
kubectl delete virtualservice your-service-vs -n default
kubectl delete hpa your-service-hpa -n audience-ns
```

## 🔒 Security Features

- **Non-root containers** (runAsUser: 1001)
- **Dropped capabilities** (ALL capabilities dropped)
- **No privilege escalation**
- **Read-only root filesystem** option available

## 🎛️ Customization Options

### Environment Variables
Uncomment and modify the `env` section in the template:
```yaml
env:
- name: NODE_ENV
  value: development
- name: DATABASE_URL
  value: "your-db-url"
```

### Secrets
Uncomment the `envFrom` section:
```yaml
envFrom:
- secretRef:
    name: your-service-secret
```

### Private Registry
Uncomment the `imagePullSecrets` section:
```yaml
imagePullSecrets:
- name: acrshareddeveastus2001
```

## 🚨 Emergency Deployment Checklist

When ArgoCD is down and you need to deploy quickly:

1. ✅ Ensure your container image is accessible
2. ✅ Choose appropriate resource limits
3. ✅ Select a unique URL prefix
4. ✅ Run the deployment script
5. ✅ Verify the service is accessible
6. ✅ Monitor logs for any issues
7. ✅ Update ArgoCD configuration when it's back online

## 🔄 Integration with ArgoCD

All resources include ArgoCD labels:
- `argocd.argoproj.io/instance: dev-audworkstream-{service-name}`

When ArgoCD is restored, you can:
1. Add your service to the ArgoCD application
2. ArgoCD will adopt the existing resources
3. Future updates will be managed through GitOps

## 📝 Examples

### Deploy a Simple Web App
```bash
./deploy-service.sh my-webapp nginx:latest 80 /web/my-webapp 2
```

### Deploy a REST API
```bash
./deploy-service.sh user-api my-api:v1.0 8080 /api/v1/users 3
```

### Deploy a Microservice
```bash
./deploy-service.sh payment-service payment-svc:latest 3000 /api/v2/payments 1
```

## 🆘 Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod -n audience-ns -l app=your-service
kubectl logs -n audience-ns -l app=your-service
```

### Service Not Accessible
```bash
# Check service endpoints
kubectl get endpoints your-service-svc -n audience-ns

# Check Istio configuration
kubectl describe virtualservice your-service-vs -n default
```

### HPA Not Scaling
```bash
# Check metrics server
kubectl top pods -n audience-ns
kubectl describe hpa your-service-hpa -n audience-ns
```

## 🎉 Success!

Your service should now be:
- ✅ Running in the audience-ns namespace
- ✅ Accessible via Istio gateway
- ✅ Auto-scaling with HPA
- ✅ Following organizational patterns
- ✅ Ready for ArgoCD adoption

Happy deploying! 🚀
