# Deploy TODO App to AWS ECS with GitHub Actions & Self-Hosted Runner

A complete guide to deploy your TODO Flask app to AWS ECS using GitHub Actions with a self-hosted runner.

## Architecture Overview

```
GitHub Repository
        ↓
GitHub Actions Workflow (on push to main)
        ↓
Self-Hosted Runner (your EC2 instance)
        ↓
Build Docker Image → Push to AWS ECR
        ↓
Run Tests
        ↓
Deploy to AWS ECS Fargate
```

## Prerequisites

- AWS Account with appropriate permissions
- GitHub Repository
- EC2 Instance (t2.micro or larger, Ubuntu 20.04+)
- Internet connectivity on EC2

## Step 1: Setup AWS

### 1.1 Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name todoapp \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true
```

**Save the repository URI** (you'll need it later)

### 1.2 Create IAM User for GitHub Actions

```bash
# Create user
aws iam create-user --user-name github-actions

# Create access key
aws iam create-access-key --user-name github-actions

# Attach ECR permissions
aws iam attach-user-policy --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

# Attach ECS permissions
aws iam attach-user-policy --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
```

**Save the Access Key ID and Secret Access Key**

### 1.3 Create CloudWatch Log Group

```bash
aws logs create-log-group --log-group-name /ecs/todoapp --region us-east-1
aws logs create-log-stream --log-group-name /ecs/todoapp --log-stream-name ecs --region us-east-1
```

### 1.4 Create ECS Cluster

```bash
aws ecs create-cluster \
  --cluster-name todoapp-cluster \
  --region us-east-1
```

### 1.5 Register Task Definition

First, update `ecs-task-definition.json`:
- Replace `ACCOUNT_ID` with your AWS Account ID (find with `aws sts get-caller-identity`)
- Keep the region as `us-east-1` or change to your preferred region

```bash
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definition.json \
  --region us-east-1
```

### 1.6 Create ECS Service

```bash
# Get your VPC subnet and security group
aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query 'Subnets[0].[SubnetId,AvailabilityZone]'
aws ec2 describe-security-groups --filters "Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId'

# Create service (replace SUBNET_ID and SECURITY_GROUP_ID)
aws ecs create-service \
  --cluster todoapp-cluster \
  --service-name todoapp-service \
  --task-definition todoapp-task:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[SUBNET_ID],securityGroups=[SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --region us-east-1
```

## Step 2: Setup Self-Hosted Runner

### 2.1 Launch EC2 Instance

- Image: Ubuntu 20.04 LTS
- Instance type: t2.micro (or larger)
- Security group: Allow port 22 (SSH)

### 2.2 Connect to EC2 and Install Dependencies

```bash
# SSH into your instance
ssh -i your-key.pem ubuntu@your-instance-ip

# Run setup script
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/TODOApp/main/scripts/setup-runner.sh
chmod +x setup-runner.sh
./setup-runner.sh

# Apply group changes
newgrp docker
```

### 2.3 Register Self-Hosted Runner

1. Go to GitHub repository → Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Select Linux and architecture (x64)
4. Copy the configuration command
5. Run it in `~/actions-runner` directory:

```bash
cd ~/actions-runner
# Paste the configuration command from GitHub
# Example:
./config.sh --url https://github.com/YOUR_USERNAME/TODOApp --token YOUR_TOKEN
```

### 2.4 Install and Start Runner Service

```bash
# Install as systemd service
sudo ./svc.sh install

# Start the service
sudo ./svc.sh start

# Check status
sudo ./svc.sh status
```

To manage the runner:
```bash
sudo ./svc.sh stop      # Stop
sudo ./svc.sh start     # Start
sudo ./svc.sh uninstall # Uninstall
```

## Step 3: Configure GitHub Secrets

In your GitHub repository:

1. Go to Settings → Secrets and variables → Actions
2. Add the following secrets:

| Secret Name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | From Step 1.2 |
| `AWS_SECRET_ACCESS_KEY` | From Step 1.2 |

## Step 4: Update Task Definition

Edit `ecs-task-definition.json`:

```json
{
  "family": "todoapp-task",
  "image": "YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/todoapp:latest",
  "executionRoleArn": "arn:aws:iam::YOUR_ACCOUNT_ID:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::YOUR_ACCOUNT_ID:role/ecsTaskRole"
}
```

## Step 5: Update GitHub Actions Workflow

Edit `.github/workflows/deploy-ecs.yml`:

```yaml
env:
  AWS_REGION: us-east-1        # Your region
  ECR_REPOSITORY: todoapp      # Your ECR repo name
  ECS_SERVICE: todoapp-service # Your ECS service name
  ECS_CLUSTER: todoapp-cluster # Your ECS cluster name
```

## Step 6: Update requirements.txt

Add testing dependencies:

```bash
pip install pytest pytest-cov gunicorn
```

Update `requirements.txt`:

```
Flask==3.0.0
Werkzeug==3.0.0
pytest==7.4.0
pytest-cov==4.1.0
gunicorn==21.2.0
```

## Step 7: Verify Everything

1. Push to main branch
2. Go to GitHub Actions tab
3. Watch the workflow run
4. Check ECS service for deployment status

```bash
aws ecs describe-services \
  --cluster todoapp-cluster \
  --services todoapp-service \
  --region us-east-1
```

## Monitoring & Troubleshooting

### View Logs

```bash
# CloudWatch logs
aws logs tail /ecs/todoapp --follow --region us-east-1

# ECS task logs
aws ecs list-tasks --cluster todoapp-cluster --region us-east-1
aws ecs describe-tasks \
  --cluster todoapp-cluster \
  --tasks YOUR_TASK_ID \
  --region us-east-1
```

### Check Runner Status

```bash
# On your EC2 instance
sudo ./svc.sh status

# View runner logs
tail -f ~/actions-runner/_diag/Runner_*.log
```

### Common Issues

| Issue | Solution |
|---|---|
| Runner not connecting | Check GitHub token isn't expired, verify security groups allow outbound |
| ECR auth failed | Verify IAM permissions, check AWS credentials in GitHub secrets |
| ECS deployment fails | Check task definition exists, verify CloudWatch log group permissions |
| Container won't start | Check app logs: `aws logs tail /ecs/todoapp --follow` |

## Deployment Flow

```
1. Developer pushes to main branch
   ↓
2. GitHub Actions triggers workflow
   ↓
3. Self-hosted runner checks out code
   ↓
4. Build Docker image locally
   ↓
5. Push image to AWS ECR
   ↓
6. Run pytest tests
   ↓
7. Update ECS task definition with new image
   ↓
8. Deploy to ECS service
   ↓
9. Wait for service stability (tasks become healthy)
   ↓
10. ✅ Deployment complete!
```

## API Endpoints

Once deployed, access your app at:
```
http://LOAD_BALANCER_IP:5000
```

To get the load balancer IP:
```bash
aws elbv2 describe-load-balancers --region us-east-1
# Or check ECS service for network info
```

## Advanced Configuration

### Auto Scaling

```bash
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/todoapp-cluster/todoapp-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 3
```

### Health Checks

Update `docker-compose.yml`:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5000/"]
  interval: 30s
  timeout: 10s
  retries: 3
```

## Clean Up

To remove everything:

```bash
# Delete ECS service
aws ecs delete-service --cluster todoapp-cluster --service todoapp-service --force

# Delete ECS cluster
aws ecs delete-cluster --cluster todoapp-cluster

# Delete ECR repository
aws ecr delete-repository --repository-name todoapp --force

# Delete IAM user
aws iam detach-user-policy --user-name github-actions --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
aws iam detach-user-policy --user-name github-actions --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam delete-access-key --user-name github-actions --access-key-id YOUR_KEY_ID
aws iam delete-user --user-name github-actions

# Delete logs
aws logs delete-log-group --log-group-name /ecs/todoapp
```

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-best-practices.html)
- [Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [AWS ECR Documentation](https://docs.aws.amazon.com/AmazonECR/latest/userguide/)

---

**Happy Deploying! 🚀**
