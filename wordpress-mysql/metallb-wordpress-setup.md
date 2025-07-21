# MetalLB with WordPress on Kind Cluster - Production Setup

This document outlines the process of setting up MetalLB with WordPress on a Kind cluster for a production-like environment, including troubleshooting steps and solutions.

## Environment

- Kind cluster running on Docker
- WordPress and MySQL deployments
- MetalLB for load balancing

## Issues Encountered

### 1. MetalLB Webhook Issues

When configuring MetalLB, we encountered webhook validation issues:

```
Error from server (InternalError): error when creating: Internal error occurred: failed calling webhook "l2advertisementvalidationwebhook.metallb.io": failed to call webhook: Post "https://webhook-service.metallb-system.svc:443/validate-metallb-io-v1beta1-l2advertisement?timeout=10s": context deadline exceeded
```

This was resolved by:
- Deleting the existing webhook configuration
- Reinstalling MetalLB with the latest stable version

### 2. Network Connectivity Issues

The external IP assigned by MetalLB (192.168.107.200) was not accessible from the host machine. This is a common issue with Kind clusters, as they run inside Docker containers and the MetalLB IP range is not automatically exposed to the host network.

### 3. WordPress Redirection Issues

WordPress was configured to redirect to a specific hostname and port (http://192.168.107.2:8080), which was not accessible.

## Solutions

### Solution 1: Port Forwarding (Development/Testing)

For development and testing purposes, port forwarding works well:

```bash
kubectl port-forward svc/wordpress-prod 8080:80
```

Then access WordPress at http://localhost:8080

### Solution 2: NodePort Service (Production-Ready)

For a more production-like setup, using NodePort services is recommended:

1. Create a NodePort service for WordPress:

```bash
kubectl expose deployment wordpress --type=NodePort --port=80 --target-port=80 --name=wordpress-prod
```

2. Access WordPress through the node's IP and the assigned NodePort:

```bash
kubectl get svc wordpress-prod
# Note the NodePort (e.g., 31285)
```

Then access WordPress at http://NODE_IP:NODE_PORT (e.g., http://192.168.107.2:31285)

### Solution 3: MetalLB with Kind (Advanced Production Setup)

For a true production setup with MetalLB on Kind:

1. Create a Kind cluster with port mappings:

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

2. Create the cluster:

```bash
kind create cluster --config kind-config.yaml
```

3. Install MetalLB:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

4. Configure MetalLB to use the Docker network subnet:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: production-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.107.200-192.168.107.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: production-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - production-pool
```

5. Deploy WordPress with a LoadBalancer service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  ports:
    - port: 80
  selector:
    app: wordpress
    tier: frontend
  type: LoadBalancer
```

## Best Practices

1. **Use NodePort for Kind Clusters**: For Kind clusters, NodePort services are more reliable than LoadBalancer services with MetalLB.

2. **Configure WordPress Site URL**: Ensure WordPress is configured with the correct site URL to avoid redirection issues:

```php
update_option('siteurl', 'http://your-node-ip:node-port');
update_option('home', 'http://your-node-ip:node-port');
```

3. **MetalLB Configuration**: When using MetalLB, ensure the IP range is within the Docker network subnet and doesn't conflict with other services.

4. **Webhook Troubleshooting**: If you encounter webhook issues, try:
   - Restarting the MetalLB pods
   - Deleting and reinstalling the webhook configuration
   - Using a newer version of MetalLB

## Current Working Solution

For our current setup, we're using a NodePort service to expose WordPress:

```bash
kubectl get svc wordpress-prod
```

Access WordPress at http://192.168.107.2:31285

For a true production environment, consider using a real Kubernetes cluster (EKS, GKE, AKS) with a proper load balancer implementation rather than Kind with MetalLB.
