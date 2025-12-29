# ECS EC2 Setup Guide

Complete setup guide for deploying TODO App to AWS ECS with EC2 instances.

## Architecture

```
GitHub Actions (Self-Hosted Runner)
        ↓
Build & Push to ECR
        ↓
ECS Service (EC2 Launch Type)
        ↓
EC2 Instance(s) with ECS Agent
        ↓
Flask App Container
```

## Prerequisites

- AWS Account with appropriate permissions
- EC2 instance (t2.micro or larger, Ubuntu 20.04+)
- GitHub repository with code
- Self-hosted GitHub Actions runner

## Step 1: Create IAM Roles

### 1.1 Create ECS Task Execution Role

```bash
# Create assume role policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://trust-policy.json

# Attach policy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Attach CloudWatch policy
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
```

### 1.2 Create ECS Task Role

```bash
aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name ecsTaskRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

### 1.3 Create EC2 Instance Role

```bash
# Create assume role policy for EC2
cat > ec2-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name ecsInstanceRole \
  --assume-role-policy-document file://ec2-trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role

aws iam attach-role-policy \
  --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws iam attach-role-policy \
  --role-name ecsInstanceRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsAgentServerPolicy

# Create instance profile
aws iam create-instance-profile --instance-profile-name ecsInstanceProfile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name ecsInstanceProfile \
  --role-name ecsInstanceRole
```

## Step 2: Launch EC2 Instance

### 2.1 Create Security Group

```bash
# Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name todoapp-sg \
  --description "Security group for TODO app" \
  --query 'GroupId' --output text)

# Allow HTTP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# Allow HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

# Allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 22 --cidr YOUR_IP/32

# Allow port 5000 for debugging (optional)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 5000 --cidr 0.0.0.0/0

echo "Security Group ID: $SG_ID"
```

### 2.2 Launch Instance with ECS AMI

```bash
# Get latest ECS-optimized AMI
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-ecs-hvm-*-x86_64-ebs" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[ImageId]' \
  --output text)

# Launch instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name YOUR_KEY_NAME \
  --security-group-ids $SG_ID \
  --iam-instance-profile Name=ecsInstanceProfile \
  --region us-east-1

echo "Instance launched. Wait 2-3 minutes for ECS agent to register..."
```

### 2.3 Connect to Instance

```bash
# Get instance IP
INSTANCE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=todoapp" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# SSH into instance
ssh -i your-key.pem ec2-user@$INSTANCE_IP

# Or run setup script remotely
ssh -i your-key.pem ec2-user@$INSTANCE_IP \
  'bash -s' < scripts/setup-ecs-ec2.sh
```

## Step 3: Create ECS Cluster

### 3.1 Create Cluster

```bash
aws ecs create-cluster \
  --cluster-name todoapp-cluster \
  --region us-east-1
```

### 3.2 Register Container Instance

```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Get the ECS container instance ARN from the EC2 instance
# SSH into instance and run:
# curl http://localhost:51678/v1/metadata | jq

# Or get cluster ARN:
CLUSTER_ARN=$(aws ecs describe-clusters \
  --clusters todoapp-cluster \
  --query 'clusters[0].clusterArn' \
  --output text)

echo "Cluster ARN: $CLUSTER_ARN"
```

## Step 4: Create CloudWatch Log Group

```bash
aws logs create-log-group --log-group-name /ecs/todoapp --region us-east-1
aws logs create-log-stream --log-group-name /ecs/todoapp --log-stream-name ecs --region us-east-1
```

## Step 5: Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name todoapp \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true

# Get repository URI
ECR_REPO=$(aws ecr describe-repositories \
  --repository-names todoapp \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "ECR Repository: $ECR_REPO"
```

## Step 6: Update Task Definition

Edit `ecs-task-definition.json`:

```json
{
  "family": "todoapp-task",
  "networkMode": "bridge",
  "containerDefinitions": [
    {
      "name": "todoapp",
      "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/todoapp:latest",
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 0,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "memory": 512,
      "cpu": 256,
      "environment": [
        {
          "name": "FLASK_ENV",
          "value": "production"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/todoapp",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ],
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskRole"
}
```

### Register Task Definition

```bash
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definition.json \
  --region us-east-1
```

## Step 7: Create ECS Service

```bash
aws ecs create-service \
  --cluster todoapp-cluster \
  --service-name todoapp-service \
  --task-definition todoapp-task:1 \
  --desired-count 1 \
  --region us-east-1
```

## Step 8: Setup GitHub Actions

### 8.1 Create IAM User for GitHub

```bash
# Create user
aws iam create-user --user-name github-actions

# Create access key
aws iam create-access-key --user-name github-actions

# Attach policies
aws iam attach-user-policy --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

aws iam attach-user-policy --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
```

### 8.2 Add GitHub Secrets

In GitHub repo → Settings → Secrets and variables → Actions:

```
AWS_ACCESS_KEY_ID=<from step above>
AWS_SECRET_ACCESS_KEY=<from step above>
```

## Step 9: Setup Self-Hosted Runner

```bash
# SSH into your runner EC2
ssh -i your-key.pem ec2-user@runner-ip

# Create runner directory
mkdir ~/actions-runner && cd ~/actions-runner

# Download runner
curl -o actions-runner-linux-x64-2.x.x.tar.gz \
  -L https://github.com/actions/runner/releases/download/v2.x.x/actions-runner-linux-x64-2.x.x.tar.gz

tar xzf ./actions-runner-linux-x64-2.x.x.tar.gz

# Configure runner
./config.sh --url https://github.com/YOUR_USERNAME/TODOApp --token YOUR_TOKEN

# Install and start
sudo ./svc.sh install
sudo ./svc.sh start
```

## Step 10: Deploy

Push code to main branch:

```bash
git add .
git commit -m "Setup ECS EC2 deployment"
git push origin main
```

Watch GitHub Actions run and deploy to ECS!

## Monitoring

### Check ECS Service Status

```bash
aws ecs describe-services \
  --cluster todoapp-cluster \
  --services todoapp-service \
  --region us-east-1
```

### View Task Status

```bash
aws ecs list-tasks \
  --cluster todoapp-cluster \
  --service-name todoapp-service \
  --region us-east-1

# Get task details
aws ecs describe-tasks \
  --cluster todoapp-cluster \
  --tasks TASK_ARN \
  --region us-east-1
```

### View Logs

```bash
# CloudWatch logs
aws logs tail /ecs/todoapp --follow --region us-east-1

# EC2 ECS agent logs
ssh -i your-key.pem ec2-user@instance-ip
sudo tail -f /var/log/ecs/ecs-agent.log
```

### Check EC2 Instance

```bash
# SSH into instance
ssh -i your-key.pem ec2-user@instance-ip

# Check Docker
docker ps
docker logs CONTAINER_ID

# Check ECS agent
sudo systemctl status ecs
```

## Troubleshooting

### EC2 Instance not showing in cluster

```bash
# SSH into instance
ssh -i your-key.pem ec2-user@instance-ip

# Check ECS agent status
sudo systemctl status ecs
sudo systemctl restart ecs

# Check ECS agent logs
sudo tail -f /var/log/ecs/ecs-agent.log
```

### Task failing to start

```bash
# Check task logs
aws logs tail /ecs/todoapp --follow

# Check ECS agent logs on EC2
sudo tail -f /var/log/ecs/ecs-agent.log

# Check Docker on EC2
docker ps -a
docker logs CONTAINER_ID
```

### IAM permission errors

- Verify IAM roles have correct permissions
- Check GitHub Actions user has ECS_FullAccess
- Ensure EC2 instance profile is attached

### Port conflicts

- Change `hostPort` in task definition to `0` for dynamic port mapping
- Use load balancer to map ports

## Cleanup

```bash
# Delete service
aws ecs delete-service \
  --cluster todoapp-cluster \
  --service todoapp-service \
  --force

# Delete cluster
aws ecs delete-cluster --cluster todoapp-cluster

# Delete task definition
aws ecs deregister-task-definition --task-definition todoapp-task:1

# Terminate EC2 instances
aws ec2 terminate-instances --instance-ids INSTANCE_ID

# Delete security group
aws ec2 delete-security-group --group-id SG_ID

# Delete ECR repository
aws ecr delete-repository --repository-name todoapp --force

# Delete IAM roles
aws iam detach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
aws iam delete-role --role-name ecsTaskExecutionRole
# ... repeat for other roles
```

## Key Differences: EC2 vs Fargate

| Feature | EC2 | Fargate |
|---------|-----|--------|
| **Network Mode** | bridge | awsvpc |
| **Port Mapping** | Dynamic (hostPort: 0) | Fixed ports |
| **Infrastructure** | Manage EC2 instances | Serverless |
| **Cost** | Pay for EC2 | Pay per task |
| **Control** | More control | Less control |
| **Setup** | More complex | Simpler |

---

**Happy deploying with ECS EC2! 🚀**
