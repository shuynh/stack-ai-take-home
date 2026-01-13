# Supabase on AWS EKS

A production ready, highly automated, secure, and scalable deployment of Supabase on AWS using Terraform and K8s.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Technology Choices](#technology-choices)
- [Prerequisites](#prerequisites)
- [Deployment Instructions](#deployment-instructions)
- [Verification](#verification)
- [Tear-Down](#tear-down)
- [Security & Scalability](#security--scalability)
- [CI/CD Pipeline](#cicd-pipeline)
- [Challenges & Learnings](#challenges--learnings)
- [Future Improvements](#future-improvements)

---

## Overview

This project deploys a production-ready Supabase instance on AWS, leveraging:
- **Infrastructure as Code**: Terraform for AWS resources
- **Container Orchestration**: Amazon EKS for Kubernetes
- **Package Management**: Helm for Supabase deployment
- **Secrets Management**: AWS SSM Parameter Store with External Secrets Operator
- **Auto-Scaling**: HPA for pods, Cluster Autoscaler for nodes
- **CI/CD**: GitHub Actions for automated deployments

### Key Features
- ✅ Multi-environment support (dev/prod) via Terraform workspaces
- ✅ High availability with multi-AZ deployment
- ✅ Automatic horizontal and vertical scaling
- ✅ Secure secrets management (no secrets in Git)
- ✅ Production-ready monitoring and alerting
- ✅ GitOps workflow with automated deployments
- ✅ Zero-downtime rolling updates

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                The World Wide Web                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Application Load Balancer                    │
│                      (AWS ALB Controller)                       │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Kong Pod    │  │   Kong Pod    │  │   Kong Pod    │
│  (API GW)     │  │  (API GW)     │  │  (API GW)     │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐    ┌──────────────┐  ┌──────────────┐
│  PostgREST   │    │    GoTrue    │  │   Realtime   │
│  (REST API)  │    │    (Auth)    │  │  (WebSocket) │
└──────┬───────┘    └──────┬───────┘  └──────┬───────┘
       │                   │                  │
       └───────────────────┼──────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │                        │
              │  Amazon RDS PostgreSQL │
              │     (Multi-AZ)         │
              │                        │
              └────────────────────────┘

┌──────────────┐                    ┌──────────────┐
│   Storage    │                    │  External    │
│   Service    ├───────────────────▶│   Secrets    │
└──────┬───────┘                    │   Operator   │
       │                            └──────┬───────┘
       ▼                                   │
┌──────────────┐                           ▼
│  Amazon S3   │              ┌────────────────────────┐
│   Bucket     │              │   SSM Parameter Store  │
└──────────────┘              └────────────────────────┘
```

### Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      VPC (10.0.0.0/16)                      │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  Public Subnets                       │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │  │
│  │  │     NAT      │  │     NAT      │  │     ALB      │ │  │
│  │  │   Gateway    │  │   Gateway    │  │              │ │  │
│  │  │   (AZ-1)     │  │   (AZ-2)     │  │              │ │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  Private Subnets                      │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │            EKS Worker Nodes                     │  │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │  │  │
│  │  │  │   Node   │  │   Node   │  │   Node   │       │  │  │
│  │  │  │  (AZ-1)  │  │  (AZ-2)  │  │  (AZ-3)  │       │  │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘       │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │            RDS Subnet Group                     │  │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │  │  │
│  │  │  │   RDS    │  │   RDS    │  │   RDS    │       │  │  │
│  │  │  │  (AZ-1)  │  │  (AZ-2)  │  │  (AZ-3)  │       │  │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘       │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Technology Choices

### Infrastructure
| Technology | Purpose | Justification |
|------------|---------|---------------|
| **Terraform** | IAC | Industry standard, cloud agnostic, declarative syntax, state management, everyone hates CloudFormation |
| **Terraform Workspaces** | Multi-environment management | Single codebase for dev/prod, way less code duplication, easy context switching |
| **AWS EKS** | Managed Kubernetes | Reduces operational overhead vs self-managed K8s, integrates with AWS services, auto-upgrades |
| **AWS RDS PostgreSQL** | Database | Multi-AZ HA, read replicas for scaling, automatic backups, performance insights, storage auto-scaling |
| **AWS S3** | Object storage | 99.999999999% durability, cost-effective, native Supabase integration |
| **AWS SSM Parameter Store** | Secrets management | Free for standard parameters, native AWS integration, audit logging |

### K8s
| Technology | Purpose | Justification |
|------------|---------|---------------|
| **Helm** | Package management | Simplifies complex deployments, values-based configuration, version control, rollback capability |
| **External Secrets Operator** | Secret synchronization | Syncs AWS SSM → K8s secrets, enables secret rotation, eliminates manual updates |
| **AWS Load Balancer Controller** | Ingress management | Native ALB integration, automatic provisioning, SSL termination, WAF support |
| **Metrics Server** | Resource monitoring | Required for HPA, provides `kubectl top` functionality |
| **Cluster Autoscaler** | Node scaling | Automatically adjusts node count based on pod scheduling needs |

### "But why not ____?"
- **Azure/GCP**: Assignment specified AWS
- **ECS/Fargate**: This is actually my first choice but admittedly it is less flexible than Kubernetes for microservices, and autoscaling options are a bit more limited.
- **Secrets Manager**: SSM is a personal preference tbh. Provides same functionality (encryption, IAM access control, external Secrets support) at no cost vs $0.40 per secret in Secrets Manager. Would use Secrets Manager for compliance requirements or automatic rotation features.
- **NGINX Ingress**: AWS ALB Controller provides better AWS integration and security features
- **variables.tf**: Locals is a personal preference! Variables require passing values at runtime, while locals are computed automatically based on workspace. Simpler for environment-specific configs
- **NetworkPolicies**: Marked as "optional but highly recommended" in assignment. Not implemented due to time constraints. Security posture is still strong with private subnets, security groups, and IRSA. Would implement in production with deny-all-by-default policy.

---

## Prerequisites

### Required Tools
```bash
# Terraform via tfenv (version manager)
brew install tfenv
tfenv install 1.14.3
tfenv use 1.14.3
terraform --version

# AWS CLI
aws --version  # >= 2.0

# kubectl
kubectl version --client  # >= 1.28

# Helm
helm version  # >= 3.13

# jq (for JSON parsing)
jq --version
```

### AWS Setup
1. **AWS Account** with admin privileges

2. **AWS CLI configured**:

   Create `~/.aws/credentials`:
   ```ini
   [default]
   aws_access_key_id = YOUR_ACCESS_KEY_ID
   aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
   ```

   Create `~/.aws/config`:
   ```ini
   [default]
   region = us-east-2
   output = json
   ```

3. **IAM Permissions** required:
   - VPC, Subnets, Route Tables, NAT Gateways
   - EKS Clusters, Node Groups
   - RDS Clusters and Instances
   - S3 Buckets
   - SSM Parameters
   - IAM Roles and Policies
   - CloudWatch Logs and Alarms

> **Note**: Some placeholder values need updating before deployment:
> - ACM cert ARNs in `locals.tf` - swap in our actual wildcard cert
> - SMTP settings in `ssm.tf` - update manually in SSM after first deployment (has `lifecycle.ignore_changes`)

### Domain/DNS
- Domain name for Supabase (e.g., `supabase.stack-ai.com`)
- ACM certificate for HTTPS (provision via ACM before deployment)

---

## Deployment Instructions

### Step 1: Clone and Initialize

```bash
# Clone repository
git clone https://github.com/shuynh/stack-ai-take-home.git
cd stack-ai-take-home

# Initialize Terraform
terraform init
```

### Step 2: Select Environment

```bash
# For dev environment
terraform workspace new dev
terraform workspace select dev

# For prod environment
terraform workspace new prod
terraform workspace select prod
```

### Step 3: Review Configuration

Edit `locals.tf` to customize:
- AWS regions
- VPC CIDR blocks
- Subnet CIDRs
- Instance sizes
- Node counts

```bash
# Review what will be created
terraform plan
```

### Step 4: Deploy Infrastructure

```bash
# Deploy all AWS resources (VPC, EKS, RDS, S3, etc.)
terraform apply
```

### Step 5: Configure kubectl

```bash
# This uses your AWS credentials from ~/.aws/credentials to authenticate with EKS
aws eks update-kubeconfig --region us-east-2 --name $(terraform output -raw eks_cluster_name)

# Verify connection (kubectl will use 'aws eks get-token' for authentication)
kubectl cluster-info
kubectl get nodes
```

### Step 6: Verify Prerequisites

```bash
# Check External Secrets Operator is running
kubectl get pods -n external-secrets

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Check Metrics Server
kubectl get deployment metrics-server -n kube-system

# Check Cluster Autoscaler
kubectl get deployment cluster-autoscaler -n kube-system
```

### Step 7: Apply External Secrets Configuration

```bash
# Determine environment
ENV=$(terraform workspace show)

# Apply SecretStore
sed "s/us-east-1/$(terraform output -json | jq -r '.ssm_parameter_prefix.value' | cut -d'/' -f2)/g" k8s/base/secret-store.yaml | \
sed "s/ENV/${ENV}/g" | kubectl apply -f -

# Apply ExternalSecrets
sed "s/ENV/${ENV}/g" k8s/base/external-secrets.yaml | kubectl apply -f -

# Wait for secrets to sync (takes ~30 seconds)
sleep 30

# Verify secrets were created
kubectl get externalsecrets -n supabase
kubectl get secrets -n supabase
```

### Step 8: Deploy Supabase

```bash
# Add Supabase Helm repository
helm repo add supabase https://supabase-community.github.io/supabase-kubernetes
helm repo update

# Get environment
ENV=$(terraform workspace show)

# Install Supabase
helm upgrade --install supabase supabase/supabase \
  --namespace supabase \
  --create-namespace \
  --values k8s/base/supabase-values.yaml \
  --values k8s/overlays/${ENV}/supabase-values.yaml \
  --timeout 15m \
  --wait

# Monitor deployment
kubectl get pods -n supabase -w
```

### Step 9: Wait for Load Balancer

```bash
# Get ALB hostname (may take 5-10 minutes to provision)
kubectl get ingress -n supabase

# Wait until ADDRESS column shows ALB hostname
watch kubectl get ingress -n supabase
```

### Step 10: Update DNS (Optional)

```bash
# Get ALB hostname
ALB_HOSTNAME=$(kubectl get ingress -n supabase -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

echo "Create a CNAME record:"
echo "supabase.stack-ai.com → $ALB_HOSTNAME"
```

---

## Verification

### 1. Infrastructure Health Check

```bash
# Check EKS cluster
aws eks describe-cluster --name $(terraform output -raw eks_cluster_name) --query 'cluster.status'

# Check RDS instance
aws rds describe-db-instances --db-instance-identifier $(terraform output -raw rds_endpoint | cut -d'.' -f1) --query 'DBInstances[0].DBInstanceStatus'

# Check RDS read replica (prod only)
if [ "$(terraform output -raw environment)" == "prod" ]; then
  aws rds describe-db-instances --db-instance-identifier $(terraform output -raw rds_read_replica_endpoint | cut -d'.' -f1) --query 'DBInstances[0].DBInstanceStatus'
fi

# Check S3 bucket
aws s3 ls s3://$(terraform output -raw s3_bucket_name)
```

### 2. Kubernetes Health Check

```bash
# Check all pods are running
kubectl get pods -n supabase

# Expected output: All pods in "Running" status
# NAME                        READY   STATUS    RESTARTS   AGE
# kong-xxxxx                  1/1     Running   0          5m
# auth-xxxxx                  1/1     Running   0          5m
# rest-xxxxx                  1/1     Running   0          5m
# realtime-xxxxx              1/1     Running   0          5m
# storage-xxxxx               1/1     Running   0          5m
# meta-xxxxx                  1/1     Running   0          5m
# studio-xxxxx                1/1     Running   0          5m
```

### 3. Service Endpoints

```bash
# Get services
kubectl get svc -n supabase

# Test Kong service (API Gateway)
kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -v http://kong.supabase.svc.cluster.local:8000/health

# Expected: HTTP 200 OK
```

### 4. HPA Status

```bash
# Check autoscalers
kubectl get hpa -n supabase

# Expected output shows current/target CPU and replicas
# NAME       REFERENCE           TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
# kong       Deployment/kong     45%/70%   2         10        3          10m
# rest       Deployment/rest     32%/70%   2         15        2          10m
```

### 5. Smoke Test

```bash
# Get ingress URL
INGRESS_URL=$(kubectl get ingress -n supabase -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl -v http://$INGRESS_URL/health

# Test Studio (Supabase Dashboard)
curl -v http://$INGRESS_URL/

# Expected: HTTP 200 OK responses
```

### 6. Database Connection Test

```bash
# Get RDS endpoint
terraform output rds_endpoint

# Get read replica endpoint (prod only)
terraform output rds_read_replica_endpoint

# Port-forward to test connection (if needed)
kubectl run psql-test --image=postgres:15 --rm -it --restart=Never -- \
  psql -h $(terraform output -raw rds_endpoint) -U supabase_admin -d supabase

# Enter password from SSM Parameter Store
```

### 7. View Logs

```bash
# View Kong logs
kubectl logs -f deployment/kong -n supabase

# View Auth logs
kubectl logs -f deployment/auth -n supabase

# View all logs from namespace
kubectl logs -f -n supabase --all-containers=true --max-log-requests=20
```

### 8. Monitoring Dashboards

```bash
# View CloudWatch Container Insights
aws cloudwatch list-dashboards

# View RDS metrics in AWS Console
https://console.aws.amazon.com/rds/

# View EKS cluster metrics
https://console.aws.amazon.com/eks/
```

### 9. Rotate Secrets

```bash
# Update a secret in SSM Parameter Store
aws ssm put-parameter \
  --name "/dev/supabase/jwt/secret" \
  --value "new-secret-value" \
  --type "SecureString" \
  --overwrite

# Trigger External Secrets Operator to refresh (or wait up to 1h for automatic refresh)
kubectl annotate externalsecret supabase-jwt-secrets force-sync=$(date +%s) -n supabase

# Restart pods to pick up new secrets
kubectl rollout restart deployment/auth -n supabase
kubectl rollout restart deployment/kong -n supabase
```

---

## Tear-Down

**⚠️ WARNING**: This will destroy all resources! 

### Complete Teardown

```bash
# 1. Delete Supabase Helm release
helm uninstall supabase --namespace supabase

# 2. Delete namespaces (removes all K8s resources)
kubectl delete namespace supabase
kubectl delete namespace external-secrets

# 3. Wait for ALBs to be deleted (check AWS Console)
# External resources created by controllers must be deleted first

# 4. Disable RDS deletion protection
# Edit rds.tf: change deletion_protection = false
# Then: terraform apply -target=aws_rds_cluster.postgres

# 5. Destroy Terraform infrastructure
terraform destroy

# 6. Confirm with: yes
```

---

## Security & Scalability

### Security Measures Implemented

#### Network Security
- **Private Subnets**: EKS nodes and RDS in private subnets with no direct internet access
- **NAT Gateways**: Outbound-only internet access for updates and external APIs
- **Security Groups**: Restrictive ingress rules (RDS only from EKS, EKS only from ALB)
- **Network Policies**: Kubernetes NetworkPolicies restrict pod-to-pod communication (optional, can be enabled)

#### Secrets Management
- **AWS SSM Parameter Store**: Centralized secrets storage with encryption at rest
- **External Secrets Operator**: Automatic secret synchronization, no secrets in Git
- **IRSA (IAM Roles for Service Accounts)**: Pods assume IAM roles without long-lived credentials
- **KMS Encryption**: SecureString parameters encrypted with AWS KMS

#### Identity & Access Management
- **Least Privilege**: Each service has minimal IAM permissions required
- **RBAC**: Kubernetes Role-Based Access Control restricts API access
- **OIDC Provider**: EKS OIDC enables secure service account federation
- **Service Accounts**: Separate accounts for External Secrets, Load Balancer Controller, Storage, etc.

#### Data Protection
- **Encryption at Rest**: RDS, S3, and SSM all use encryption at rest
- **Encryption in Transit**: TLS/SSL for all communications (ALB → Pods, Pods → RDS)
- **Backup & Recovery**: RDS automated backups (7-30 days), S3 versioning enabled
- **WAF (Optional)**: Can attach AWS WAF to ALB for application-layer protection

### Scalability Architecture

#### Horizontal Pod Autoscaling (HPA)
| Component | Dev (Min/Max) | Prod (Min/Max) | Trigger |
|-----------|---------------|----------------|---------|
| Kong      | 1-4           | 3-15           | CPU > 70% |
| PostgREST | 1-6           | 4-20           | CPU > 70%, Memory > 80% |
| GoTrue    | 1-4           | 3-15           | CPU > 70% |
| Realtime  | 1-4           | 3-15           | CPU > 70% |
| Storage   | 1-4           | 3-12           | CPU > 70% |

#### Cluster Autoscaling
- **Cluster Autoscaler**: Automatically adds/removes EC2 nodes based on pod scheduling needs
- **Node Groups**: Tagged for auto-discovery by Cluster Autoscaler
- **Instance Types**: Dev uses t3.large, Prod uses t3.xlarge for better performance

#### Database Scalability
- **RDS PostgreSQL**: Multi-AZ deployment with automatic failover
- **Read Replica**: Production environment includes 1 read replica for horizontal read scaling
- **Storage Auto-Scaling**: Configured to automatically scale up to 2x allocated storage
- **Connection Pooling**: PgBouncer can be added for connection management

#### Storage Scalability
- **S3**: Unlimited storage capacity, automatic scaling
- **CloudFront (Future)**: Can add CDN for static asset distribution
- **IRSA for S3**: Eliminates credential management, scales to any number of pods

### Monitoring & Observability Strategy

#### Current Implementation
- **Metrics Server**: Pod and node resource metrics for HPA
- **CloudWatch Container Insights**: Pod/node metrics, logs aggregation
- **RDS Enhanced Monitoring**: 60-second granularity metrics
- **CloudWatch Alarms**: RDS CPU, memory, connections, storage alerts

#### Recommended Additions for Production
```bash
# Prometheus + Grafana for custom metrics
helm install prometheus prometheus-community/kube-prometheus-stack

# FluentBit for log aggregation
helm install fluent-bit fluent/fluent-bit

# Datadog/New Relic for APM (Application Performance Monitoring)
```

#### Key Metrics to Monitor
- **Pod-Level**: CPU, memory, restart count, readiness probe failures
- **Node-Level**: CPU, memory, disk usage, network throughput
- **Application**: Request rate, error rate, latency (RED metrics)
- **Database**: Connections, query latency, deadlocks, replication lag
- **Business**: User signups, API requests, storage usage

---

## CI/CD Pipeline

> **⚠️ Current State**: This project currently runs Terraform **locally** for development/testing purposes.
> While this works for the take-home, it's **not ideal for production** due to:
> - No remote state locking (risk of concurrent modifications)
> - Local state files (can be lost, not shared across team)
> - Manual execution (no audit trail, no approval workflow)
> - Credentials stored locally (security risk)

### Infrastructure Management (Terraform Cloud)

**Recommended Future State:** Infrastructure changes should be managed via **Terraform Cloud**:
- Workspace-based environment separation (dev/prod)
- Remote state management with locking
- Approval workflows for production changes
- Automatic plan generation on VCS commits
- Secure credential management
- Team collaboration and RBAC

### Application Deployment (GitHub Actions)

#### Deploy Supabase (`deploy-supabase.yml`)
**Triggers**: Manual dispatch (triggered after infrastructure changes)

**Jobs**:
- Configures kubectl for EKS cluster
- Applies External Secrets configuration
- Deploys/upgrades Supabase via Helm
- Runs smoke tests

**Features**:
- Environment-specific values overlays
- Automatic secret synchronization
- Rollback capability
- Health checks and verification

### Setting Up CI/CD

**Terraform Cloud Setup:**
1. Create Terraform Cloud account and organization
2. Connect repository to workspace (VCS-driven workflow)
3. Configure AWS credentials as workspace variables
4. Set workspace-specific variables for dev/prod

**GitHub Actions Setup:**

```bash
# 1. Create OIDC provider in AWS
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Create IAM role for GitHub Actions
# See: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

# 3. Add GitHub secrets
# AWS_ROLE_ARN: arn:aws:iam::123456789:role/GitHubActionsRole

# 4. Trigger deployment workflow after infrastructure changes
```

---

## Challenges & Learnings

### Challenge 1: Understanding Supabase Architecture
**Problem**: So acutally, I've Never used Supabase before :( I had to understand what it is, how components interact, and what infrastructure it needs.

**Approach**:
- Studied Supabase documentation and architecture diagrams
- Analyzed supabase-kubernetes Helm chart to understand service dependencies

**Learning**: Always start with architecture research before infrastructure. Understanding the application's components, communication patterns, and external dependencies is critical for designing proper networking, security groups, and resource allocation. Coming from "roll your own backend" experience, seeing how Supabase abstracts these concerns into microservices was interesting and eye-opening.

### Challenge 2: EKS Node Subnet Tagging
**Problem**: AWS Load Balancer Controller couldn't create ALBs due to missing subnet tags.

**Solution**: Added required tags to subnets:
```hcl
"kubernetes.io/role/elb" = "1"  # Public subnets
"kubernetes.io/role/internal-elb" = "1"  # Private subnets
"kubernetes.io/cluster/<cluster-name>" = "shared"
```

**Learning**: EKS integrations often require specific tags. Always check AWS documentation for tag requirements before deployment.

### Challenge 3: External Secrets Operator Timing
**Problem**: Helm deployment failed because ExternalSecrets hadn't synced yet.

**Solution**: Added explicit wait in deployment script:
```bash
sleep 30  # Wait for ESO to sync
kubectl get secrets -n supabase  # Verify before Helm install
```

**Learning**: External dependencies (like secret synchronization) need explicit wait conditions. Consider using `kubectl wait --for=condition=Ready externalsecret/<name>` for more robust checking.

### Challenge 4: Helm Values Merging
**Problem**: Needed different configurations per environment without duplicating entire values files.

**Solution**: Created base + overlay structure:
```
k8s/
├── base/supabase-values.yaml (common settings)
└── overlays/
    ├── dev/supabase-values.yaml (dev overrides)
    └── prod/supabase-values.yaml (prod overrides)
```

**Learning**: Helm's values merging is powerful. Always structure as base + environment-specific overlays to maintain DRY principles.

---

## Future Improvements

### Immediate Next Steps
1. **SSL/TLS Certificates**
   - Provision ACM certificates for domains
   - Update Ingress annotations with certificate ARNs
   - Enforce HTTPS-only traffic

2. **DNS Configuration**
   - Create Route53 hosted zone
   - Add CNAME records for Supabase endpoints

3. **Backup & Disaster Recovery**
   - Implement automated RDS snapshot rotation
   - S3 cross-region replication for disaster recovery
   - Document and test restore procedures (maybe use AWS Backup?)

4. **Enhanced Monitoring**
   - Deploy Prometheus + Grafana for custom metrics
   - Set up PagerDuty for alerting + oncall rotation
   - Create runbooks for common incidents
   - Implement Datadog Synthetics for automated endpoint testing and uptime monitoring

### Medium-Term Enhancements
5. **Cost Optimization**
   - RDS reserved instances
   - Use Spot instances for non-critical workloads
   - Enable S3 Intelligent-Tiering for cost savings

6. **Security Hardening**
   - Enable Kubernetes Network Policies
   - Implement Pod Security Standards (PSS)
   - Add AWS WAF rules for common vulnerabilities
   - Enable GuardDuty for threat detection

7. **Performance Tuning**
   - Enable CloudFront CDN for static assets
   - Implement caching layer (Redis/ElastiCache)

8. **Advanced Autoscaling**
   - Implement custom metrics for HPA (e.g., request queue length)
   - Use Predictive Autoscaling based on historical patterns
   - Add VPA (Vertical Pod Autoscaler) for right-sizing

### Long-Term Architecture Evolution
9. **Multi-Account Strategy**
   - Split prod into its own AWS account for blast radius isolation
   - Use AWS Organizations for centralized billing and policy management
   - Implement cross-account roles for controlled access
   - Separate dev/prod + maybe staging into distinct accounts

10. **Multi-Region Deployment**
    - Deploy Supabase across multiple AWS regions
    - Implement RDS cross-region read replicas for disaster recovery

11. **GitOps Implementation**
    - Migrate to ArgoCD for declarative deployments
    - Add automated rollback on error rate spikes

12. **Compliance**
    - Implement AWS Config rules for compliance monitoring
    - Add OPA (Open Policy Agent) for policy enforcement
    - Enable CloudTrail for audit logging
    - Consider Vanta or similar for managed compliance (SOC 2, ISO 27001, etc.)

### Potential Architecture Changes
- **Database**: Consider adding additional read replicas or upgrading instance class for higher throughput
- **Storage**: Evaluate EFS for shared persistent volumes if needed
- **Compute**: Explore ECS for serverless pod execution (remove node management and simplifies Terraform code?)
- **Messaging**: Add SQS/SNS for asynchronous workloads
- **Caching**: Implement Redis for session storage and caching

---


## Quick Reference

### Common Commands

```bash
# Terraform
terraform workspace list              # List workspaces
terraform workspace select dev        # Switch workspace
terraform plan                        # Preview changes
terraform apply                       # Apply changes
terraform output                      # View outputs
terraform destroy                     # Destroy all resources

# kubectl
kubectl get pods -n supabase          # List pods
kubectl logs -f <pod> -n supabase     # Stream logs
kubectl describe pod <pod> -n supabase # Detailed pod info
kubectl exec -it <pod> -n supabase -- sh  # Shell into pod
kubectl port-forward -n supabase svc/kong 8000:8000  # Port forward

# Helm
helm list -n supabase                 # List releases
helm status supabase -n supabase      # Release status
helm upgrade supabase ...             # Upgrade release
helm rollback supabase -n supabase    # Rollback release
helm uninstall supabase -n supabase   # Uninstall release

# AWS CLI
aws eks list-clusters                 # List EKS clusters
aws rds describe-db-instances         # List RDS instances
aws s3 ls                             # List S3 buckets
aws ssm get-parameters-by-path --path /dev/supabase/ --recursive  # List SSM params
```

---

**Built with ❤️  so pls hire me**
