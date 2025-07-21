# WordPress with Nginx Ingress Controller on Kind Cluster

This document outlines the process of setting up WordPress with Nginx Ingress Controller on a Kind cluster, including troubleshooting steps and solutions.

## Environment

- Kind cluster running on Docker
- WordPress and MySQL deployments
- MetalLB for load balancing
- Nginx Ingress Controller for ingress management

## Setup Steps

### 1. Install MetalLB

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

Configure MetalLB with an IP address pool:

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

### 2. Install Nginx Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

### 3. Modify Nginx Ingress Controller Service

Change the service to listen on port 8080 instead of 80:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  type: LoadBalancer
  ports:
    - name: http
      port: 8080
      targetPort: 80
      protocol: TCP
    - name: https
      port: 443
      targetPort: 443
      protocol: TCP
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/component: controller
```

### 4. Create Ingress Resource for WordPress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/use-port-in-redirects: "true"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wordpress
            port:
              number: 80
```

### 5. Update WordPress Site URL

Create a PHP script to update the WordPress site URL in the database:

```php
<?php
// WordPress database settings from wp-config.php
require_once('/var/www/html/wp-config.php');

// Connect to the database
$connection = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);

if ($connection->connect_error) {
    die("Connection failed: " . $connection->connect_error);
}

// Get the external IP address
$external_ip = '192.168.107.202';

// Update the WordPress site URL and home URL
$connection->query("UPDATE {$table_prefix}options SET option_value = 'http://{$external_ip}:8080' WHERE option_name = 'siteurl'");
$connection->query("UPDATE {$table_prefix}options SET option_value = 'http://{$external_ip}:8080' WHERE option_name = 'home'");

echo "WordPress URLs updated to http://{$external_ip}:8080\n";

$connection->close();
?>
```

Copy the script to the WordPress pod and execute it:

```bash
kubectl cp ./update-wp-url.php wordpress-pod:/var/www/html/update-wp-url.php
kubectl exec wordpress-pod -- php /var/www/html/update-wp-url.php
```

## Issues Encountered and Solutions

### 1. Webhook Validation Issues

When applying the Ingress resource, we encountered webhook validation issues:

```
Error from server (InternalError): error when creating: Internal error occurred: failed calling webhook "validate.nginx.ingress.kubernetes.io": failed to call webhook: Post "https://ingress-nginx-controller-admission.ingress-nginx.svc:443/networking/v1/ingresses?timeout=10s": context deadline exceeded
```

Solution: Delete the webhook configuration:

```bash
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission
```

### 2. WordPress Redirect Issues

WordPress was redirecting to 127.0.0.1:8080, which failed.

Solution: Update the WordPress site URL in the database to use the correct external IP and port.

## Accessing WordPress

WordPress is now accessible at http://192.168.107.202:8080

## Best Practices

1. **Use Nginx Ingress Controller**: For production environments, Nginx Ingress Controller provides more features and better performance than basic ingress resources.

2. **Configure WordPress Site URL**: Always ensure WordPress is configured with the correct site URL to avoid redirection issues.

3. **Use HTTPS**: For production environments, configure HTTPS with proper certificates.

4. **Resource Limits**: Set appropriate resource limits for all components to ensure stability.

5. **Regular Backups**: Implement regular backups of WordPress data and database.

## Conclusion

This setup provides a production-ready WordPress installation with Nginx Ingress Controller on a Kind cluster. The combination of MetalLB and Nginx Ingress Controller allows for proper load balancing and ingress management.
