#!/bin/bash

# Setup ECS EC2 Instance
# Run this on your EC2 instance to configure it as an ECS agent

set -e

echo "🚀 Setting up EC2 instance for ECS..."

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER

# Install ECS Agent
echo "🤖 Installing ECS Agent..."
sudo apt-get install -y ecs-init

# Configure CloudWatch Logs
echo "📝 Configuring CloudWatch Logs..."
sudo apt-get install -y awslogs

# Create CloudWatch Logs configuration
sudo tee /etc/awslogs/config/ecs.conf > /dev/null <<EOF
[/ecs/todoapp]
log_group_name = /ecs/todoapp
log_stream_name = {instance_id}
datetime_format = %b %d %H:%M:%S
file = /var/log/ecs/ecs-agent.log
EOF

# Start services
echo "▶️  Starting services..."
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl enable ecs
sudo systemctl start ecs
sudo systemctl enable awslogs
sudo systemctl start awslogs

# Add user to docker group
newgrp docker

echo "✅ EC2 instance setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Update your IAM role: aws iam attach-role-policy --role-name ecsInstanceRole --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsAgentServerPolicy"
echo "2. Verify ECS agent is running: sudo systemctl status ecs"
echo "3. Create ECS cluster and register this instance"
echo ""
echo "Check ECS agent logs:"
echo "  sudo tail -f /var/log/ecs/ecs-agent.log"
