#!/bin/bash

# React App Deployment Script
# Usage: ./deploy-react-app.sh <app-name> <image> <url-prefix> [replicas] [api-base-url] [environment]
# Example: ./deploy-react-app.sh user-dashboard my-registry/user-dashboard:v1.0 /web/users 3 https://dev.lionis.ai/api/v2 development

set -e

# Check if required parameters are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <app-name> <image> <url-prefix> [replicas] [api-base-url] [environment]"
    echo ""
    echo "Examples:"
    echo "  $0 user-dashboard my-registry/user-dashboard:v1.0 /web/users"
    echo "  $0 admin-panel nginx:alpine /admin 2 https://api.example.com production"
    echo "  $0 analytics-ui my-app:latest /web/analytics 5 https://dev.lionis.ai/api/v2 development"
    exit 1
fi

APP_NAME=$1
REACT_IMAGE=$2
URL_PREFIX=$3
REPLICAS=${4:-2}
API_BASE_URL=${5:-"https://dev.lionis.ai/api/v2"}
ENVIRONMENT=${6:-"development"}

# Derived values
APP_LABEL=$APP_NAME

echo "⚛️  Deploying React app with the following configuration:"
echo "   App Name: $APP_NAME"
echo "   Image: $REACT_IMAGE"
echo "   URL Prefix: $URL_PREFIX"
echo "   Replicas: $REPLICAS"
echo "   API Base URL: $API_BASE_URL"
echo "   Environment: $ENVIRONMENT"
echo ""

# Create temporary deployment file
TEMP_FILE="/tmp/${APP_NAME}-react-deployment.yaml"

cat > $TEMP_FILE << EOF
---
# ConfigMap for Nginx Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}-nginx-config
  namespace: audience-ns
  labels:
    app: ${APP_LABEL}
    component: nginx-config
    argocd.argoproj.io/instance: dev-audworkstream-${APP_NAME}
data:
  nginx.conf: |
    user nginx;
    worker_processes auto;
    error_log /var/log/nginx/error.log notice;
    pid /var/run/nginx.pid;

    events {
        worker_connections 1024;
    }

    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                        '\$status \$body_bytes_sent "\$http_referer" '
                        '"\$http_user_agent" "\$http_x_forwarded_for"';

        access_log /var/log/nginx/access.log main;

        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        client_max_body_size 16M;

        # Gzip compression
        gzip on;
        gzip_vary on;
        gzip_min_length 1024;
        gzip_proxied any;
        gzip_comp_level 6;
        gzip_types
            text/plain
            text/css
            text/xml
            text/javascript
            application/json
            application/javascript
            application/xml+rss
            application/atom+xml
            image/svg+xml;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        server {
            listen 3000;
            server_name localhost;
            root /usr/share/nginx/html;
            index index.html index.htm;

            # Handle React Router (SPA routing)
            location / {
                try_files \$uri \$uri/ /index.html;
                
                # Cache static assets
                location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
                    expires 1y;
                    add_header Cache-Control "public, immutable";
                }
            }

            # Health check endpoint
            location /health {
                access_log off;
                return 200 "healthy\\n";
                add_header Content-Type text/plain;
            }

            # API proxy
            location /api/ {
                proxy_pass ${API_BASE_URL}/;
                proxy_http_version 1.1;
                proxy_set_header Upgrade \$http_upgrade;
                proxy_set_header Connection 'upgrade';
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
                proxy_cache_bypass \$http_upgrade;
            }

            error_page 404 /index.html;
            error_page 500 502 503 504 /50x.html;
            location = /50x.html {
                root /usr/share/nginx/html;
            }
        }
    }

---
# ConfigMap for Environment Variables
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}-env-config
  namespace: audience-ns
  labels:
    app: ${APP_LABEL}
    component: env-config
    argocd.argoproj.io/instance: dev-audworkstream-${APP_NAME}
data:
  config.js: |
    // Runtime configuration for ${APP_NAME}
    window.APP_CONFIG = {
      API_BASE_URL: '${API_BASE_URL}',
      ENVIRONMENT: '${ENVIRONMENT}',
      APP_NAME: '${APP_NAME}',
      VERSION: '1.0.0',
      FEATURES: {
        ANALYTICS: true,
        DEBUG: ${ENVIRONMENT} === 'development',
        MAINTENANCE_MODE: false
      },
      URLS: {
        SUPPORT: 'https://dev.lionis.ai/support',
        DOCS: 'https://dev.lionis.ai/docs',
        STATUS: 'https://dev.lionis.ai/status'
      }
    };

---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}-deployment
  namespace: audience-ns
  labels:
    app: ${APP_LABEL}
    component: frontend
    argocd.argoproj.io/instance: dev-audworkstream-${APP_NAME}
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app: ${APP_LABEL}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 50%
      maxUnavailable: 25%
  template:
    metadata:
      labels:
        app: ${APP_LABEL}
        component: frontend
    spec:
      containers:
      - name: ${APP_LABEL}
        image: ${REACT_IMAGE}
        ports:
        - containerPort: 3000
          name: http
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: NODE_ENV
          value: "${ENVIRONMENT}"
        - name: REACT_APP_API_BASE_URL
          value: "${API_BASE_URL}"
        - name: REACT_APP_ENVIRONMENT
          value: "${ENVIRONMENT}"
        - name: REACT_APP_VERSION
          value: "1.0.0"
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: env-config
          mountPath: /usr/share/nginx/html/config.js
          subPath: config.js
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: false
          runAsNonRoot: true
          runAsUser: 101
      volumes:
      - name: nginx-config
        configMap:
          name: ${APP_NAME}-nginx-config
      - name: env-config
        configMap:
          name: ${APP_NAME}-env-config
      securityContext:
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 101

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-svc
  namespace: audience-ns
  labels:
    app: ${APP_LABEL}
    component: frontend
    argocd.argoproj.io/instance: dev-audworkstream-${APP_NAME}
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 3000
    targetPort: 3000
    protocol: TCP
  selector:
    app: ${APP_LABEL}
  sessionAffinity: None

---
# VirtualService (Istio)
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${APP_NAME}-vs
  namespace: default
  labels:
    argocd.argoproj.io/instance: dev-audworkstream-${APP_NAME}
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
        host: ${APP_NAME}-svc.audience-ns.svc.cluster.local
        port:
          number: 3000
    headers:
      response:
        add:
          X-App-Name: ${APP_NAME}
          X-App-Version: "1.0.0"

---
# HorizontalPodAutoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${APP_NAME}-hpa
  namespace: audience-ns
  labels:
    app: ${APP_LABEL}
    component: frontend
    argocd.argoproj.io/instance: dev-audworkstream-${APP_NAME}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${APP_NAME}-deployment
  minReplicas: 2
  maxReplicas: 10
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

---
# PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${APP_NAME}-pdb
  namespace: audience-ns
  labels:
    app: ${APP_LABEL}
    component: frontend
    argocd.argoproj.io/instance: dev-audworkstream-${APP_NAME}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: ${APP_LABEL}
EOF

echo "📝 Generated deployment file: $TEMP_FILE"
echo ""

# Apply the deployment
echo "🔄 Applying React app deployment to Kubernetes..."
kubectl apply -f $TEMP_FILE

echo ""
echo "✅ React app deployment completed successfully!"
echo ""
echo "📊 Checking deployment status..."
kubectl get deployment ${APP_NAME}-deployment -n audience-ns
echo ""
kubectl get service ${APP_NAME}-svc -n audience-ns
echo ""
kubectl get virtualservice ${APP_NAME}-vs -n default
echo ""
kubectl get hpa ${APP_NAME}-hpa -n audience-ns
echo ""

echo "🌐 Your React app will be available at:"
echo "   https://dev.lionis.ai${URL_PREFIX}"
echo ""

echo "⚛️  React app features:"
echo "   ✅ Nginx with optimized configuration"
echo "   ✅ SPA routing support (React Router)"
echo "   ✅ Static asset caching"
echo "   ✅ API proxy to backend services"
echo "   ✅ Security headers"
echo "   ✅ Gzip compression"
echo "   ✅ Health checks"
echo "   ✅ Auto-scaling (HPA)"
echo "   ✅ High availability (PDB)"
echo ""

echo "🔍 To monitor your React app:"
echo "   kubectl get pods -n audience-ns -l app=${APP_LABEL}"
echo "   kubectl logs -f deployment/${APP_NAME}-deployment -n audience-ns"
echo ""

echo "🔧 Configuration files created:"
echo "   - Nginx config: ${APP_NAME}-nginx-config"
echo "   - Environment config: ${APP_NAME}-env-config"
echo ""

echo "🗑️  To delete this React app:"
echo "   kubectl delete -f $TEMP_FILE"
echo ""

# Clean up temp file
rm $TEMP_FILE
