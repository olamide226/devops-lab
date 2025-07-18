#!/bin/bash

# Enterprise Kubernetes Discovery Script
# This script gathers information about your K8s enterprise patterns
# Run with: ./enterprise-k8s-discovery.sh

OUTPUT_FILE="k8s-enterprise-patterns.txt"
echo "🔍 Discovering Enterprise Kubernetes Patterns..." > $OUTPUT_FILE
echo "Generated on: $(date)" >> $OUTPUT_FILE
echo "=========================================" >> $OUTPUT_FILE

# Function to safely run kubectl commands
safe_kubectl() {
    local cmd="$1"
    local description="$2"
    echo "" >> $OUTPUT_FILE
    echo "### $description ###" >> $OUTPUT_FILE
    echo "Command: $cmd" >> $OUTPUT_FILE
    echo "---" >> $OUTPUT_FILE
    if eval $cmd >> $OUTPUT_FILE 2>&1; then
        echo "✅ Success: $description"
    else
        echo "❌ Failed: $description" >> $OUTPUT_FILE
        echo "⚠️  Failed: $description"
    fi
}

echo "🔍 Gathering enterprise patterns..."

# 1. Service Mesh Detection
safe_kubectl "kubectl get virtualservices --all-namespaces -o yaml" "Istio VirtualServices"
safe_kubectl "kubectl get gateways --all-namespaces -o yaml" "Istio Gateways"
safe_kubectl "kubectl get destinationrules --all-namespaces -o yaml" "Istio DestinationRules"

# 2. Ingress Patterns
safe_kubectl "kubectl get ingressclass -o yaml" "Ingress Classes"
safe_kubectl "kubectl get ingress --all-namespaces -o yaml" "All Ingress Resources"

# 3. Existing Services in Target Namespaces
safe_kubectl "kubectl get svc -n audience-ns -o yaml" "Services in audience-ns"
safe_kubectl "kubectl get svc -n audience -o yaml" "Services in audience namespace"

# 4. Load Balancer Services
safe_kubectl "kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer -o yaml" "LoadBalancer Services"

# 5. Existing Deployments for Pattern Analysis
safe_kubectl "kubectl get deployment -n audience-ns -o yaml" "Deployments in audience-ns"

# 6. TLS/Certificate Management
safe_kubectl "kubectl get secrets --all-namespaces | grep -E '(tls|cert)'" "TLS Certificates"
safe_kubectl "kubectl get certificates --all-namespaces -o yaml" "Certificate Resources (cert-manager)"

# 7. Network Policies
safe_kubectl "kubectl get networkpolicy --all-namespaces -o yaml" "Network Policies"

# 8. Monitoring Patterns
safe_kubectl "kubectl get servicemonitor --all-namespaces -o yaml" "ServiceMonitors (Prometheus)"
safe_kubectl "kubectl get podmonitor --all-namespaces -o yaml" "PodMonitors (Prometheus)"

# 9. API Gateway Detection
safe_kubectl "kubectl api-resources | grep -E '(gateway|route|virtualservice)'" "API Resources - Gateways/Routes"
safe_kubectl "kubectl get gateway --all-namespaces -o yaml" "Gateway Resources"

# 10. Enterprise CRDs
safe_kubectl "kubectl get crd | grep -E '(virtual|gateway|ingress|route|policy|monitor)'" "Enterprise CRDs"

# 11. Annotations and Labels Patterns
safe_kubectl "kubectl get svc -n audience-ns -o jsonpath='{range .items[*]}{\"=== Service: \"}{.metadata.name}{\" ===\"}{\"\n\"}{\"Labels: \"}{.metadata.labels}{\"\n\"}{\"Annotations: \"}{.metadata.annotations}{\"\n\n\"}{end}'" "Service Labels and Annotations"

# 12. Cluster Information
safe_kubectl "kubectl cluster-info" "Cluster Information"
safe_kubectl "kubectl get nodes -o wide" "Node Information"

# 13. Audience Service Specific Patterns
safe_kubectl "kubectl describe deployment audience-service-deployment -n audience-ns" "Audience Service Deployment Details"
safe_kubectl "kubectl get ingress,routes --all-namespaces | grep -i audience" "Audience Related Ingress/Routes"

# Summary
echo "" >> $OUTPUT_FILE
echo "### DISCOVERY COMPLETE ###" >> $OUTPUT_FILE
echo "Analysis file generated: $OUTPUT_FILE" >> $OUTPUT_FILE

echo ""
echo "✅ Discovery complete! Results saved to: $OUTPUT_FILE"
echo ""
echo "📋 Summary of what was gathered:"
echo "   • Service Mesh (Istio) configurations"
echo "   • Ingress controllers and routing patterns"
echo "   • Load balancer services"
echo "   • TLS certificate management"
echo "   • Monitoring (Prometheus) patterns"
echo "   • Network policies"
echo "   • Enterprise CRDs and API resources"
echo "   • Existing service annotations and labels"
echo ""
echo "📤 Please share the contents of '$OUTPUT_FILE' so I can create"
echo "   enterprise-compliant manifests for your aga-service."