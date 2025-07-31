# Deployment Guide - Steri-Tek Smart SOF

## 🚀 Deployment Overview

The Steri-Tek Smart SOF system supports multiple deployment strategies across development, staging, and production environments.

## 📋 Prerequisites

### Development Environment
- Docker Desktop 4.0+
- Node.js 18+
- Python 3.11+
- Git 2.30+

### Production Environment  
- GCP Account with billing enabled
- Terraform 1.6+
- kubectl 1.25+
- Docker with registry access

## 🏠 Local Development Deployment

### Quick Start
```bash
# Clone repository
git clone <repository-url>
cd steri-tek-smart-sof

# Start all services
docker-compose up -d

# Verify deployment
curl http://localhost:8000/health
curl http://localhost:3000
```

### Service URLs (Development)
- **Frontend**: http://localhost:3000
- **API Gateway**: http://localhost:8000
- **SOF Service**: http://localhost:8001
- **Auth Service**: http://localhost:8002
- **File Service**: http://localhost:8003
- **Audit Service**: http://localhost:8004
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379
- **MinIO Console**: http://localhost:9001

### Development Database Setup
```bash
# Connect to PostgreSQL
docker exec -it postgres psql -U sof_user -d sof_development

# Run migrations
docker exec -it api-gateway python -m alembic upgrade head

# Seed test data
docker exec -it api-gateway python scripts/seed_test_data.py
```

## 🧪 Testing Environment

### Run Test Suite
```bash
# Unit tests
docker exec -it api-gateway pytest tests/unit/
docker exec -it frontend npm run test:unit

# Integration tests  
docker exec -it api-gateway pytest tests/integration/

# E2E tests
cd frontend && npm run cypress:run

# Performance tests
k6 run tests/performance/load_test.js
```

### Test Data Management
```bash
# Reset test database
docker exec -it postgres psql -U sof_user -d sof_development -c "TRUNCATE TABLE sofs CASCADE;"

# Load fixture data
docker exec -it api-gateway python scripts/load_fixtures.py
```

## ☁️ Cloud Deployment (GCP)

### Infrastructure Setup

#### 1. Configure GCP Authentication
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Login and set project
gcloud auth login
gcloud config set project your-project-id
gcloud auth application-default login
```

#### 2. Enable Required APIs
```bash
gcloud services enable run.googleapis.com
gcloud services enable sql.googleapis.com  
gcloud services enable storage.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

#### 3. Deploy Infrastructure
```bash
cd infra/environments/staging

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="project_id=your-project-id" -var="environment=staging"

# Apply infrastructure
terraform apply -var="project_id=your-project-id" -var="environment=staging"
```

### Application Deployment

#### 1. Build and Push Images
```bash
# Set registry
export REGISTRY=gcr.io/your-project-id

# Build all services
docker build -t $REGISTRY/sof-api-gateway:latest ./services/api-gateway
docker build -t $REGISTRY/sof-service:latest ./services/sof-service
docker build -t $REGISTRY/sof-auth-service:latest ./services/auth-service
docker build -t $REGISTRY/sof-file-service:latest ./services/file-service
docker build -t $REGISTRY/sof-audit-service:latest ./services/audit-service
docker build -t $REGISTRY/sof-frontend:latest ./frontend

# Push images
docker push $REGISTRY/sof-api-gateway:latest
# ... repeat for all services
```

#### 2. Deploy via GitHub Actions
```bash
# Push to main branch triggers deployment
git push origin main

# Monitor deployment
gh run list --workflow=ci.yml
gh run view <run-id> --log
```

### Environment-Specific Configurations

#### Staging Environment
```bash
cd infra/environments/staging
terraform apply -var-file="staging.tfvars"
```

**staging.tfvars**:
```hcl
project_id = "sof-staging-project"
environment = "staging"
instance_count_min = 0
instance_count_max = 3
database_tier = "db-standard-1"
```

#### Production Environment
```bash
cd infra/environments/production
terraform apply -var-file="production.tfvars"
```

**production.tfvars**:
```hcl
project_id = "sof-production-project"
environment = "production"
instance_count_min = 2
instance_count_max = 10
database_tier = "db-standard-2"
backup_retention_days = 30
```

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

The CI/CD pipeline automatically:
1. **Linting & Testing**: Runs on every PR
2. **Security Scanning**: SAST and dependency checks
3. **Build & Push**: Docker images to registry
4. **Deploy Staging**: Automatic deployment to staging
5. **Deploy Production**: Manual approval required

### Pipeline Stages
```yaml
# Triggered on push to main or PR
Lint & Test → Security Scan → Build Images → Deploy Staging → [Manual Approval] → Deploy Production
```

### Deployment Commands
```bash
# Manual staging deployment
gh workflow run ci.yml -f environment=staging

# Manual production deployment  
gh workflow run ci.yml -f environment=production -f manual_approval=true
```

## 📊 Monitoring & Observability

### Health Checks
```bash
# Service health endpoints
curl https://api-gateway-staging-xyz.a.run.app/health
curl https://sof-service-staging-xyz.a.run.app/health

# Database connectivity
curl https://api-gateway-staging-xyz.a.run.app/health/db

# Storage connectivity  
curl https://file-service-staging-xyz.a.run.app/health/storage
```

### Monitoring Setup
- **Grafana Dashboards**: Pre-configured dashboards for all services
- **Alerting**: Email/Slack notifications for critical issues
- **Log Aggregation**: Centralized logging with Cloud Logging
- **Tracing**: OpenTelemetry distributed tracing

### Key Metrics
- **API Response Time**: p95 < 750ms
- **Error Rate**: < 1%  
- **Database Connections**: < 80% utilization
- **Storage Usage**: Monitor bucket growth
- **User Sessions**: Active user tracking

## 🔒 Security & Compliance

### Secrets Management
```bash
# Create secrets in Google Secret Manager
gcloud secrets create sof-db-password --data-file=db_password.txt
gcloud secrets create sof-jwt-secret --data-file=jwt_secret.txt

# Grant service account access
gcloud secrets add-iam-policy-binding sof-db-password \
  --member="serviceAccount:sof-cloud-run@project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### SSL/TLS Configuration
- **Development**: Self-signed certificates via Docker
- **Staging/Production**: Google-managed SSL certificates
- **API Gateway**: TLS 1.3 minimum, HSTS headers
- **Database**: SSL-only connections enforced

### Compliance Monitoring
```bash
# Check audit logs
gcloud logging read "resource.type=cloud_run_revision" --limit=50

# Verify signature integrity
curl -X POST https://api/audit/verify-signatures

# Compliance dashboard
open https://console.cloud.google.com/monitoring/dashboards/custom/sof-compliance
```

## 🚨 Disaster Recovery

### Backup Strategy
- **Database**: Automated daily backups with 30-day retention
- **Files**: Cross-region replication with versioning
- **Code**: Git repository with multiple remotes
- **Infrastructure**: Terraform state in Cloud Storage

### Recovery Procedures

#### Database Recovery
```bash
# List available backups
gcloud sql backups list --instance=sof-postgres-production

# Restore from backup
gcloud sql backups restore BACKUP_ID --restore-instance=sof-postgres-production
```

#### File Recovery
```bash
# List object versions
gsutil ls -la gs://sof-files-production/

# Restore specific version
gsutil cp gs://sof-files-production/path/to/file#generation gs://sof-files-production/path/to/file
```

#### Infrastructure Recovery
```bash
# Rebuild infrastructure from Terraform
cd infra/environments/production
terraform destroy  # Only if necessary
terraform apply
```

### RTO/RPO Targets
- **Recovery Time Objective (RTO)**: 4 hours
- **Recovery Point Objective (RPO)**: 1 hour
- **Data Loss Tolerance**: Zero for signed SOFs
- **Availability Target**: 99.9% uptime

## 📈 Scaling Considerations

### Horizontal Scaling
- **Cloud Run**: Auto-scales from 0-10 instances per service
- **Database**: Read replicas for query offloading
- **File Storage**: Unlimited scaling with Cloud Storage
- **Caching**: Redis cluster for session management

### Performance Optimization
```bash
# Database query optimization
EXPLAIN ANALYZE SELECT * FROM sofs WHERE status = 'draft';

# Container optimization
docker build --build-arg PYTHON_VERSION=3.11-slim .

# CDN configuration
gcloud compute url-maps create sof-cdn --default-backend-bucket=sof-static-assets
```

### Cost Optimization
- **Resource Right-sizing**: Monitor CPU/memory utilization
- **Storage Lifecycle**: Automatic archival of old SOFs
- **Database Optimization**: Query performance tuning
- **CDN Caching**: Static asset optimization

## 🔧 Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check logs
docker logs api-gateway
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=api-gateway"

# Check environment variables
docker exec -it api-gateway env | grep -E "(DATABASE|REDIS|MINIO)"
```

#### Database Connection Issues
```bash
# Test connection
docker exec -it postgres psql -U sof_user -d sof_development -c "SELECT 1;"

# Check connection pool
curl http://localhost:8000/health/db
```

#### File Upload Issues
```bash
# Test MinIO connectivity
docker exec -it minio mc ls local/sof-files

# Check file service logs
docker logs file-service
```

### Debug Commands
```bash
# Service status
docker-compose ps

# Resource usage
docker stats

# Network connectivity
docker exec -it api-gateway ping postgres
docker exec -it api-gateway nslookup redis

# Database queries
docker exec -it postgres psql -U sof_user -d sof_development
```

## 📞 Support & Maintenance

### Regular Maintenance Tasks
- **Weekly**: Review error logs and performance metrics
- **Monthly**: Update dependencies and security patches  
- **Quarterly**: Disaster recovery testing
- **Annually**: Security audit and penetration testing

### Support Contacts
- **Development Team**: dev-team@steri-tek.com
- **DevOps Team**: devops@steri-tek.com  
- **Security Team**: security@steri-tek.com
- **On-call**: +1-555-SOF-HELP

### Documentation Links
- **API Documentation**: https://api-docs.steri-tek.com
- **User Manual**: https://docs.steri-tek.com/sof
- **Compliance Guide**: https://compliance.steri-tek.com
- **Status Page**: https://status.steri-tek.com
