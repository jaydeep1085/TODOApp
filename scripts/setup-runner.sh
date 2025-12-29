#!/bin/bash

# Setup script for GitHub Actions self-hosted runner
# Run this on your EC2 instance

set -e

echo "🚀 Setting up GitHub Actions self-hosted runner..."

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
if ! command -v docker &> /dev/null; then
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
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

# Install AWS CLI v2
if ! command -v aws &> /dev/null; then
    echo "☁️  Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
    echo "✅ AWS CLI v2 installed"
else
    echo "✅ AWS CLI already installed"
fi

# Install Python 3.11
if ! command -v python3.11 &> /dev/null; then
    echo "🐍 Installing Python 3.11..."
    sudo apt-get install -y python3.11 python3.11-venv python3-pip
    echo "✅ Python 3.11 installed"
else
    echo "✅ Python 3.11 already installed"
fi

# Install git
if ! command -v git &> /dev/null; then
    echo "📂 Installing Git..."
    sudo apt-get install -y git
    echo "✅ Git installed"
else
    echo "✅ Git already installed"
fi

# Create runner directory
echo "📁 Creating runner directory..."
mkdir -p ~/actions-runner
cd ~/actions-runner

# Download latest runner
echo "⬇️  Downloading GitHub Actions runner..."
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep tag_name | cut -d'"' -f4 | sed 's/v//')
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
  -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

echo "✅ Runner setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Go to your GitHub repository Settings → Actions → Runners"
echo "2. Click 'New self-hosted runner' and copy the configuration command"
echo "3. Run the configuration command in ~/actions-runner directory"
echo "4. Run: sudo ./svc.sh install && sudo ./svc.sh start"
echo ""
echo "For more info, visit: https://docs.github.com/en/actions/hosting-your-own-runners"
