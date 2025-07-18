# Database Deployment Toolkit

This toolkit provides templates and scripts for deploying production-ready databases with persistent volumes in your audience-ns namespace.

## 🎯 What This Toolkit Provides

- **Database templates** with persistent storage
- **Automated deployment scripts** for PostgreSQL, MySQL, and Redis
- **Security configurations** with NetworkPolicies
- **Health checks** and monitoring
- **Backup-ready configurations**

## 📁 Database Files Included

1. **db-service-template.yaml** - Generic database template with placeholders
2. **postgres-db-example.yaml** - Ready-to-deploy PostgreSQL example
3. **deploy-database.sh** - Automated database deployment script
4. **cleanup-service.sh** - Database removal script (reuses the main cleanup script)

## 🗄️ Supported Databases

| Database | Image | Default Port | Use Case |
|----------|-------|--------------|----------|
| **PostgreSQL** | `postgres:15-alpine` | 5432 | Relational data, ACID compliance |
| **MySQL** | `mysql:8.0` | 3306 | Web applications, WordPress |
| **Redis** | `redis:7-alpine` | 6379 | Caching, sessions, pub/sub |

## 🚀 Quick Start

### Option 1: Deploy PostgreSQL Example

```bash
# Deploy the example PostgreSQL database
kubectl apply -f postgres-db-example.yaml

# Check if it's running
kubectl get pods -n audience-ns -l app=postgres

# Connect to the database
kubectl exec -it deployment/postgres-db-deployment -n audience-ns -- psql -U postgres -d audience_db
```

### Option 2: Use the Automated Script

```bash
# Deploy PostgreSQL
./deploy-database.sh postgres user-db 20Gi mypassword userdata

# Deploy MySQL
./deploy-database.sh mysql product-db 15Gi secret123 products

# Deploy Redis
./deploy-database.sh redis cache-db 5Gi redispass
```

### Option 3: Use the Template Manually

1. Copy `db-service-template.yaml`
2. Replace all `{{PLACEHOLDER}}` values
3. Apply with `kubectl apply -f your-database.yaml`

## 🔧 Template Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{DB_SERVICE_NAME}}` | Database service name | `postgres-db`, `mysql-db` |
| `{{DB_APP_LABEL}}` | Application label | `postgres`, `mysql`, `redis` |
| `{{DB_IMAGE}}` | Database container image | `postgres:15-alpine` |
| `{{DB_PORT}}` | Database port | `5432`, `3306`, `6379` |
| `{{STORAGE_SIZE}}` | Persistent volume size | `10Gi`, `20Gi`, `50Gi` |
| `{{STORAGE_CLASS}}` | Storage class | `default`, `managed-premium` |
| `{{DB_SECRET_NAME}}` | Secret name | `postgres-secret` |
| `{{CPU_REQUEST}}` | CPU request | `500m`, `1000m` |
| `{{MEMORY_REQUEST}}` | Memory request | `512Mi`, `1Gi` |
| `{{CPU_LIMIT}}` | CPU limit | `1000m`, `2000m` |
| `{{MEMORY_LIMIT}}` | Memory limit | `1Gi`, `2Gi` |

## 🔐 Security Features

### Secrets Management
- Database credentials stored in Kubernetes secrets
- Base64 encoded passwords
- Separate secrets per database instance

### Network Security
- NetworkPolicies restrict database access to audience-ns namespace
- No external exposure by default
- Ingress rules only allow database port traffic

### Container Security
- Non-root containers (runAsUser: 999)
- Dropped capabilities (ALL capabilities dropped)
- No privilege escalation
- Proper file system permissions (fsGroup: 999)

## 💾 Persistent Storage

### Storage Configuration
- **ReadWriteOnce** access mode (single node mounting)
- **Recreate** deployment strategy (prevents data corruption)
- Configurable storage class and size
- Automatic volume provisioning

### Data Paths
- **PostgreSQL**: `/var/lib/postgresql/data`
- **MySQL**: `/var/lib/mysql`
- **Redis**: `/data`

## 🏥 Health Checks

### Liveness Probes
- **PostgreSQL**: `pg_isready -U postgres`
- **MySQL**: `mysqladmin ping`
- **Redis**: `redis-cli ping`

### Readiness Probes
- Same commands as liveness probes
- Faster intervals for quicker recovery
- Ensures database is ready before receiving traffic

## 📊 What Gets Created

Each database deployment creates:

1. **Secret** - Database credentials
2. **PersistentVolumeClaim** - Storage for data
3. **ConfigMap** - Database configuration (optional)
4. **Deployment** - Database pods with persistent storage
5. **Service** - Internal cluster networking
6. **Headless Service** - Direct pod access (optional)
7. **NetworkPolicy** - Security restrictions

## 🔍 Monitoring Your Database

```bash
# Check deployment status
kubectl get deployment your-db-deployment -n audience-ns

# View pods
kubectl get pods -n audience-ns -l app=your-db

# Check logs
kubectl logs -f deployment/your-db-deployment -n audience-ns

# Check persistent volume
kubectl get pvc your-db-pvc -n audience-ns

# Check storage usage
kubectl exec -it deployment/your-db-deployment -n audience-ns -- df -h
```

## 🔗 Database Connections

### Connection Strings

**PostgreSQL:**
```
Host: your-db-svc.audience-ns.svc.cluster.local
Port: 5432
Database: your_database
Username: postgres
Password: your_password
```

**MySQL:**
```
Host: your-db-svc.audience-ns.svc.cluster.local
Port: 3306
Database: your_database
Username: root
Password: your_password
```

**Redis:**
```
Host: your-db-svc.audience-ns.svc.cluster.local
Port: 6379
Password: your_password
```

### From Application Code

```yaml
# In your application deployment
env:
- name: DATABASE_URL
  value: "postgresql://postgres:password@postgres-db-svc.audience-ns.svc.cluster.local:5432/mydatabase"
- name: REDIS_URL
  value: "redis://:password@redis-db-svc.audience-ns.svc.cluster.local:6379"
```

## 🛠️ Database Administration

### PostgreSQL Commands
```bash
# Connect to database
kubectl exec -it deployment/postgres-db-deployment -n audience-ns -- psql -U postgres -d mydatabase

# Create database
kubectl exec -it deployment/postgres-db-deployment -n audience-ns -- createdb -U postgres newdatabase

# Dump database
kubectl exec -it deployment/postgres-db-deployment -n audience-ns -- pg_dump -U postgres mydatabase > backup.sql
```

### MySQL Commands
```bash
# Connect to database
kubectl exec -it deployment/mysql-db-deployment -n audience-ns -- mysql -u root -p mydatabase

# Create database
kubectl exec -it deployment/mysql-db-deployment -n audience-ns -- mysql -u root -p -e "CREATE DATABASE newdatabase;"

# Dump database
kubectl exec -it deployment/mysql-db-deployment -n audience-ns -- mysqldump -u root -p mydatabase > backup.sql
```

### Redis Commands
```bash
# Connect to Redis
kubectl exec -it deployment/redis-db-deployment -n audience-ns -- redis-cli -a password

# Get Redis info
kubectl exec -it deployment/redis-db-deployment -n audience-ns -- redis-cli -a password info

# Monitor Redis
kubectl exec -it deployment/redis-db-deployment -n audience-ns -- redis-cli -a password monitor
```

## 🔄 Backup and Recovery

### Manual Backup
```bash
# PostgreSQL backup
kubectl exec -it deployment/postgres-db-deployment -n audience-ns -- pg_dump -U postgres mydatabase > postgres-backup-$(date +%Y%m%d).sql

# MySQL backup
kubectl exec -it deployment/mysql-db-deployment -n audience-ns -- mysqldump -u root -p mydatabase > mysql-backup-$(date +%Y%m%d).sql

# Redis backup (RDB file)
kubectl cp audience-ns/postgres-db-deployment-xxx:/data/dump.rdb redis-backup-$(date +%Y%m%d).rdb
```

### Restore from Backup
```bash
# PostgreSQL restore
kubectl exec -i deployment/postgres-db-deployment -n audience-ns -- psql -U postgres mydatabase < postgres-backup.sql

# MySQL restore
kubectl exec -i deployment/mysql-db-deployment -n audience-ns -- mysql -u root -p mydatabase < mysql-backup.sql
```

## 📈 Scaling Considerations

### Single Instance Databases
- PostgreSQL and MySQL deployments use `replicas: 1`
- Uses `Recreate` strategy to prevent data corruption
- For high availability, consider using operators (e.g., PostgreSQL Operator)

### Redis Scaling
- Single instance for simple caching
- For production, consider Redis Cluster or Sentinel
- Can scale horizontally with sharding

## 🗑️ Cleanup

```bash
# Remove a database completely (includes PVC, secrets, etc.)
kubectl delete deployment your-db-deployment -n audience-ns
kubectl delete service your-db-svc -n audience-ns
kubectl delete pvc your-db-pvc -n audience-ns
kubectl delete secret your-db-secret -n audience-ns
kubectl delete networkpolicy your-db-netpol -n audience-ns

# Or use the cleanup script (only removes deployment and service)
./cleanup-service.sh your-db-name
```

## ⚠️ Important Notes

### Data Persistence
- **PersistentVolumes survive pod restarts and deletions**
- **Deleting PVC will permanently delete your data**
- Always backup before major changes

### Security
- Change default passwords in production
- Use strong passwords (consider password generators)
- Regularly rotate database credentials
- Monitor database access logs

### Performance
- Adjust resource limits based on your workload
- Monitor CPU and memory usage
- Consider using faster storage classes for production

## 🚨 Emergency Database Recovery

When you need to quickly restore database service:

1. ✅ Ensure PVC still exists with your data
2. ✅ Deploy database with same PVC name
3. ✅ Verify data integrity
4. ✅ Update application connection strings
5. ✅ Monitor database performance

## 🔄 Integration with Applications

### Environment Variables
```yaml
env:
- name: DB_HOST
  value: "postgres-db-svc.audience-ns.svc.cluster.local"
- name: DB_PORT
  value: "5432"
- name: DB_NAME
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_DB
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_USER
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_PASSWORD
```

## 🎉 Success!

Your database should now be:
- ✅ Running with persistent storage
- ✅ Secured with NetworkPolicies
- ✅ Health-checked and monitored
- ✅ Ready for application connections
- ✅ Following organizational patterns

Happy data storing! 🗄️
