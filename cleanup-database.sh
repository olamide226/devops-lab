#!/bin/bash

# Database Cleanup Script
# Usage: ./cleanup-database.sh <service-name>
# Example: ./cleanup-database.sh postgres-db

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <service-name>"
    echo "Example: $0 postgres-db"
    exit 1
fi

SERVICE_NAME=$1

echo "🗑️  Cleaning up database service: $SERVICE_NAME"
echo ""

# Check if resources exist before trying to delete them
echo "🔍 Checking existing resources..."

DEPLOYMENT_EXISTS=$(kubectl get deployment ${SERVICE_NAME}-deployment -n audience-ns --ignore-not-found=true)
SERVICE_EXISTS=$(kubectl get service ${SERVICE_NAME}-svc -n audience-ns --ignore-not-found=true)
HEADLESS_EXISTS=$(kubectl get service ${SERVICE_NAME}-headless -n audience-ns --ignore-not-found=true)
PVC_EXISTS=$(kubectl get pvc ${SERVICE_NAME}-pvc -n audience-ns --ignore-not-found=true)
SECRET_EXISTS=$(kubectl get secret ${SERVICE_NAME}-secret -n audience-ns --ignore-not-found=true)
CONFIGMAP_EXISTS=$(kubectl get configmap ${SERVICE_NAME}-config -n audience-ns --ignore-not-found=true)
NETPOL_EXISTS=$(kubectl get networkpolicy ${SERVICE_NAME}-netpol -n audience-ns --ignore-not-found=true)

if [ -n "$DEPLOYMENT_EXISTS" ]; then
    echo "🔄 Deleting deployment..."
    kubectl delete deployment ${SERVICE_NAME}-deployment -n audience-ns
fi

if [ -n "$SERVICE_EXISTS" ]; then
    echo "🔄 Deleting service..."
    kubectl delete service ${SERVICE_NAME}-svc -n audience-ns
fi

if [ -n "$HEADLESS_EXISTS" ]; then
    echo "🔄 Deleting headless service..."
    kubectl delete service ${SERVICE_NAME}-headless -n audience-ns
fi

if [ -n "$SECRET_EXISTS" ]; then
    echo "🔄 Deleting secret..."
    kubectl delete secret ${SERVICE_NAME}-secret -n audience-ns
fi

if [ -n "$CONFIGMAP_EXISTS" ]; then
    echo "🔄 Deleting configmap..."
    kubectl delete configmap ${SERVICE_NAME}-config -n audience-ns
fi

if [ -n "$NETPOL_EXISTS" ]; then
    echo "🔄 Deleting network policy..."
    kubectl delete networkpolicy ${SERVICE_NAME}-netpol -n audience-ns
fi

# Ask about PVC deletion since it contains data
if [ -n "$PVC_EXISTS" ]; then
    echo ""
    echo "⚠️  WARNING: PersistentVolumeClaim contains your database data!"
    echo "   Deleting it will permanently remove all data."
    echo ""
    read -p "Do you want to delete the PVC and all data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Deleting PVC and all data..."
        kubectl delete pvc ${SERVICE_NAME}-pvc -n audience-ns
        echo "💀 All database data has been permanently deleted!"
    else
        echo "✅ PVC preserved. Your data is safe."
        echo "   PVC name: ${SERVICE_NAME}-pvc"
        echo "   To delete later: kubectl delete pvc ${SERVICE_NAME}-pvc -n audience-ns"
    fi
fi

echo ""
echo "✅ Database cleanup completed!"
echo ""

# Verify cleanup
echo "🔍 Verifying cleanup..."
kubectl get deployment,service,secret,configmap,networkpolicy -n audience-ns -l app=${SERVICE_NAME} --ignore-not-found=true
kubectl get pvc -n audience-ns -l app=${SERVICE_NAME} --ignore-not-found=true

echo ""
echo "🎉 Database service '$SERVICE_NAME' has been cleaned up!"
