#!/bin/bash

# Database Deployment Script
# Usage: ./deploy-database.sh <db-type> <service-name> <storage-size> [db-password] [db-name]
# Example: ./deploy-database.sh postgres user-db 20Gi mypassword userdata
# Example: ./deploy-database.sh mysql product-db 15Gi secret123 products
# Example: ./deploy-database.sh redis cache-db 5Gi redispass

set -e

# Check if required parameters are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <db-type> <service-name> <storage-size> [db-password] [db-name]"
    echo ""
    echo "Supported database types: postgres, mysql, redis"
    echo ""
    echo "Examples:"
    echo "  $0 postgres user-db 20Gi mypassword userdata"
    echo "  $0 mysql product-db 15Gi secret123 products"
    echo "  $0 redis cache-db 5Gi redispass"
    exit 1
fi

DB_TYPE=$1
SERVICE_NAME=$2
STORAGE_SIZE=$3
DB_PASSWORD=${4:-"password123"}
DB_NAME=${5:-"mydatabase"}

# Validate database type
case $DB_TYPE in
    postgres|mysql|redis)
        ;;
    *)
        echo "❌ Unsupported database type: $DB_TYPE"
        echo "Supported types: postgres, mysql, redis"
        exit 1
        ;;
esac

# Set database-specific configurations
case $DB_TYPE in
    postgres)
        DB_IMAGE="postgres:15-alpine"
        DB_PORT=5432
        DB_USER="postgres"
        DATA_PATH="/var/lib/postgresql/data"
        HEALTH_CMD="pg_isready -U postgres"
        ;;
    mysql)
        DB_IMAGE="mysql:8.0"
        DB_PORT=3306
        DB_USER="root"
        DATA_PATH="/var/lib/mysql"
        HEALTH_CMD="mysqladmin ping"
        ;;
    redis)
        DB_IMAGE="redis:7-alpine"
        DB_PORT=6379
        DB_USER="redis"
        DATA_PATH="/data"
        HEALTH_CMD="redis-cli ping"
        ;;
esac

# Encode credentials to base64
DB_PASSWORD_B64=$(echo -n "$DB_PASSWORD" | base64)
DB_USER_B64=$(echo -n "$DB_USER" | base64)
DB_NAME_B64=$(echo -n "$DB_NAME" | base64)

echo "🗄️  Deploying $DB_TYPE database with the following configuration:"
echo "   Database Type: $DB_TYPE"
echo "   Service Name: $SERVICE_NAME"
echo "   Image: $DB_IMAGE"
echo "   Port: $DB_PORT"
echo "   Storage Size: $STORAGE_SIZE"
echo "   Database Name: $DB_NAME"
echo ""

# Create temporary deployment file
TEMP_FILE="/tmp/${SERVICE_NAME}-db-deployment.yaml"

cat > $TEMP_FILE << EOF
---
# Secret for Database Credentials
apiVersion: v1
kind: Secret
metadata:
  name: ${SERVICE_NAME}-secret
  namespace: audience-ns
  labels:
    app: ${SERVICE_NAME}
    db-type: ${DB_TYPE}
    argocd.argoproj.io/instance: dev-audworkstream-${SERVICE_NAME}
type: Opaque
data:
EOF

# Add database-specific secret data
case $DB_TYPE in
    postgres)
        cat >> $TEMP_FILE << EOF
  POSTGRES_PASSWORD: ${DB_PASSWORD_B64}
  POSTGRES_USER: ${DB_USER_B64}
  POSTGRES_DB: ${DB_NAME_B64}
EOF
        ;;
    mysql)
        cat >> $TEMP_FILE << EOF
  MYSQL_ROOT_PASSWORD: ${DB_PASSWORD_B64}
  MYSQL_DATABASE: ${DB_NAME_B64}
  MYSQL_USER: ${DB_USER_B64}
  MYSQL_PASSWORD: ${DB_PASSWORD_B64}
EOF
        ;;
    redis)
        cat >> $TEMP_FILE << EOF
  REDIS_PASSWORD: ${DB_PASSWORD_B64}
EOF
        ;;
esac

cat >> $TEMP_FILE << EOF

---
# PersistentVolumeClaim for Database Storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${SERVICE_NAME}-pvc
  namespace: audience-ns
  labels:
    app: ${SERVICE_NAME}
    db-type: ${DB_TYPE}
    argocd.argoproj.io/instance: dev-audworkstream-${SERVICE_NAME}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: default
  resources:
    requests:
      storage: ${STORAGE_SIZE}

---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE_NAME}-deployment
  namespace: audience-ns
  labels:
    app: ${SERVICE_NAME}
    db-type: ${DB_TYPE}
    argocd.argoproj.io/instance: dev-audworkstream-${SERVICE_NAME}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: ${SERVICE_NAME}
  template:
    metadata:
      labels:
        app: ${SERVICE_NAME}
        db-type: ${DB_TYPE}
    spec:
      containers:
      - name: ${DB_TYPE}
        image: ${DB_IMAGE}
        ports:
        - containerPort: ${DB_PORT}
          name: db-port
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        envFrom:
        - secretRef:
            name: ${SERVICE_NAME}-secret
EOF

# Add database-specific environment variables
case $DB_TYPE in
    postgres)
        cat >> $TEMP_FILE << EOF
        env:
        - name: PGDATA
          value: ${DATA_PATH}/pgdata
EOF
        ;;
    redis)
        cat >> $TEMP_FILE << EOF
        command: ["redis-server"]
        args: ["--requirepass", "\$(REDIS_PASSWORD)"]
EOF
        ;;
esac

cat >> $TEMP_FILE << EOF
        volumeMounts:
        - name: db-storage
          mountPath: ${DATA_PATH}
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - "${HEALTH_CMD}"
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - sh
            - -c
            - "${HEALTH_CMD}"
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
          runAsUser: 999
      volumes:
      - name: db-storage
        persistentVolumeClaim:
          claimName: ${SERVICE_NAME}-pvc
      securityContext:
        fsGroup: 999

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE_NAME}-svc
  namespace: audience-ns
  labels:
    app: ${SERVICE_NAME}
    db-type: ${DB_TYPE}
    argocd.argoproj.io/instance: dev-audworkstream-${SERVICE_NAME}
spec:
  type: ClusterIP
  ports:
  - name: db-port
    port: ${DB_PORT}
    targetPort: ${DB_PORT}
    protocol: TCP
  selector:
    app: ${SERVICE_NAME}
  sessionAffinity: None

---
# NetworkPolicy for Database Security
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${SERVICE_NAME}-netpol
  namespace: audience-ns
  labels:
    app: ${SERVICE_NAME}
    db-type: ${DB_TYPE}
    argocd.argoproj.io/instance: dev-audworkstream-${SERVICE_NAME}
spec:
  podSelector:
    matchLabels:
      app: ${SERVICE_NAME}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: audience-ns
    ports:
    - protocol: TCP
      port: ${DB_PORT}
  egress:
  - {}
EOF

echo "📝 Generated deployment file: $TEMP_FILE"
echo ""

# Apply the deployment
echo "🔄 Applying database deployment to Kubernetes..."
kubectl apply -f $TEMP_FILE

echo ""
echo "✅ Database deployment completed successfully!"
echo ""
echo "📊 Checking deployment status..."
kubectl get deployment ${SERVICE_NAME}-deployment -n audience-ns
echo ""
kubectl get service ${SERVICE_NAME}-svc -n audience-ns
echo ""
kubectl get pvc ${SERVICE_NAME}-pvc -n audience-ns
echo ""

echo "🔗 Database connection details:"
echo "   Host: ${SERVICE_NAME}-svc.audience-ns.svc.cluster.local"
echo "   Port: ${DB_PORT}"
echo "   Database: ${DB_NAME}"
echo "   Username: ${DB_USER}"
echo "   Password: ${DB_PASSWORD}"
echo ""

echo "🔍 To monitor your database:"
echo "   kubectl get pods -n audience-ns -l app=${SERVICE_NAME}"
echo "   kubectl logs -f deployment/${SERVICE_NAME}-deployment -n audience-ns"
echo ""

case $DB_TYPE in
    postgres)
        echo "🐘 PostgreSQL specific commands:"
        echo "   kubectl exec -it deployment/${SERVICE_NAME}-deployment -n audience-ns -- psql -U ${DB_USER} -d ${DB_NAME}"
        ;;
    mysql)
        echo "🐬 MySQL specific commands:"
        echo "   kubectl exec -it deployment/${SERVICE_NAME}-deployment -n audience-ns -- mysql -u ${DB_USER} -p${DB_PASSWORD} ${DB_NAME}"
        ;;
    redis)
        echo "🔴 Redis specific commands:"
        echo "   kubectl exec -it deployment/${SERVICE_NAME}-deployment -n audience-ns -- redis-cli -a ${DB_PASSWORD}"
        ;;
esac

echo ""
echo "🗑️  To delete this database:"
echo "   kubectl delete -f $TEMP_FILE"
echo ""

# Clean up temp file
rm $TEMP_FILE
