#!/bin/bash

# Service Cleanup Script
# Usage: ./cleanup-service.sh <service-name>
# Example: ./cleanup-service.sh hello-world-service

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <service-name>"
    echo "Example: $0 hello-world-service"
    exit 1
fi

SERVICE_NAME=$1

echo "🗑️  Cleaning up service: $SERVICE_NAME"
echo ""

# Check if resources exist before trying to delete them
echo "🔍 Checking existing resources..."

DEPLOYMENT_EXISTS=$(kubectl get deployment ${SERVICE_NAME}-deployment -n audience-ns --ignore-not-found=true)
SERVICE_EXISTS=$(kubectl get service ${SERVICE_NAME}-svc -n audience-ns --ignore-not-found=true)
VS_EXISTS=$(kubectl get virtualservice ${SERVICE_NAME}-vs -n default --ignore-not-found=true)
HPA_EXISTS=$(kubectl get hpa ${SERVICE_NAME}-hpa -n audience-ns --ignore-not-found=true)

if [ -n "$DEPLOYMENT_EXISTS" ]; then
    echo "🔄 Deleting deployment..."
    kubectl delete deployment ${SERVICE_NAME}-deployment -n audience-ns
fi

if [ -n "$SERVICE_EXISTS" ]; then
    echo "🔄 Deleting service..."
    kubectl delete service ${SERVICE_NAME}-svc -n audience-ns
fi

if [ -n "$VS_EXISTS" ]; then
    echo "🔄 Deleting virtual service..."
    kubectl delete virtualservice ${SERVICE_NAME}-vs -n default
fi

if [ -n "$HPA_EXISTS" ]; then
    echo "🔄 Deleting HPA..."
    kubectl delete hpa ${SERVICE_NAME}-hpa -n audience-ns
fi

echo ""
echo "✅ Cleanup completed!"
echo ""

# Verify cleanup
echo "🔍 Verifying cleanup..."
kubectl get deployment,service,hpa -n audience-ns -l app=${SERVICE_NAME} --ignore-not-found=true
kubectl get virtualservice -n default -l argocd.argoproj.io/instance=dev-audworkstream-${SERVICE_NAME} --ignore-not-found=true

echo ""
echo "🎉 Service '$SERVICE_NAME' has been completely removed!"
