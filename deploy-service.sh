#!/bin/bash

# Quick Service Deployment Script
# Usage: ./deploy-service.sh <service-name> <image> <port> [url-prefix] [replicas]
# Example: ./deploy-service.sh my-api nginx:latest 80 /api/v1/my-api 2

set -e

# Check if required parameters are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <service-name> <image> <port> [url-prefix] [replicas]"
    echo "Example: $0 my-api nginx:latest 80 /api/v1/my-api 2"
    exit 1
fi

SERVICE_NAME=$1
CONTAINER_IMAGE=$2
CONTAINER_PORT=$3
URL_PREFIX=${4:-"/web/$SERVICE_NAME"}
REPLICAS=${5:-1}

# Derived values
APP_LABEL=$SERVICE_NAME
SERVICE_PORT=$CONTAINER_PORT

echo "🚀 Deploying service with the following configuration:"
echo "   Service Name: $SERVICE_NAME"
echo "   Image: $CONTAINER_IMAGE"
echo "   Port: $CONTAINER_PORT"
echo "   URL Prefix: $URL_PREFIX"
echo "   Replicas: $REPLICAS"
echo ""

# Create temporary deployment file
TEMP_FILE="/tmp/${SERVICE_NAME}-deployment.yaml"

cat > $TEMP_FILE << EOF
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE_NAME}-deployment
  namespace: audience-ns
  labels:
    app: ${APP_LABEL}
    argocd.argoproj.io/instance: dev-audworkstream-${SERVICE_NAME}
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app: ${APP_LABEL}
  template:
    metadata:
      labels:
        app: ${APP_LABEL}
    spec:
      containers:
      - name: ${APP_LABEL}
        image: ${CONTAINER_IMAGE}
        ports:
        - containerPort: ${CONTAINER_PORT}
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: false
          runAsNonRoot: false
      securityContext:
        runAsUser: 1001

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE_NAME}-svc
  namespace: audience-ns
  labels:
    app: ${APP_LABEL}
    argocd.argoproj.io/instance: dev-audworkstream-${SERVICE_NAME}
spec:
  type: ClusterIP
  ports:
  - name: http
    port: ${SERVICE_PORT}
    targetPort: ${CONTAINER_PORT}
    protocol: TCP
  selector:
    app: ${APP_LABEL}
  sessionAffinity: None

---
# VirtualService (Istio)
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${SERVICE_NAME}-vs
  namespace: default
  labels:
    argocd.argoproj.io/instance: dev-audworkstream-${SERVICE_NAME}
spec:
  gateways:
  - istio-ingressgw-shared-dev-eastus2-001
  hosts:
  - '*'
  http:
  - match:
    - uri:
        prefix: ${URL_PREFIX}
    route:
    - destination:
        host: ${SERVICE_NAME}-svc.audience-ns.svc.cluster.local
        port:
          number: ${SERVICE_PORT}

---
# HorizontalPodAutoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${SERVICE_NAME}-hpa
  namespace: audience-ns
  labels:
    app: ${APP_LABEL}
    argocd.argoproj.io/instance: dev-audworkstream-${SERVICE_NAME}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${SERVICE_NAME}-deployment
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

echo "📝 Generated deployment file: $TEMP_FILE"
echo ""

# Apply the deployment
echo "🔄 Applying deployment to Kubernetes..."
kubectl apply -f $TEMP_FILE

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📊 Checking deployment status..."
kubectl get deployment ${SERVICE_NAME}-deployment -n audience-ns
echo ""
kubectl get service ${SERVICE_NAME}-svc -n audience-ns
echo ""
kubectl get virtualservice ${SERVICE_NAME}-vs -n default
echo ""
kubectl get hpa ${SERVICE_NAME}-hpa -n audience-ns
echo ""

echo "🌐 Your service will be available at:"
echo "   https://dev.lionis.ai${URL_PREFIX}"
echo ""

echo "🔍 To monitor your deployment:"
echo "   kubectl get pods -n audience-ns -l app=${APP_LABEL}"
echo "   kubectl logs -f deployment/${SERVICE_NAME}-deployment -n audience-ns"
echo ""

echo "🗑️  To delete this service:"
echo "   kubectl delete -f $TEMP_FILE"
echo ""

# Clean up temp file
rm $TEMP_FILE
