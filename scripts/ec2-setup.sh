#!/bin/bash

# EC2 Setup Script for TODO App Deployment
set -e

echo "🔧 Starting EC2 setup for TODO app..."

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Python and dependencies
sudo apt-get install -y python3.11 python3.11-venv python3-pip git

# Install Node.js (optional, for future enhancements)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Create app directory
sudo mkdir -p /home/ubuntu/todoapp
sudo chown ubuntu:ubuntu /home/ubuntu/todoapp

# Configure SSH for GitHub
mkdir -p ~/.ssh
chmod 700 ~/.ssh

echo "📝 EC2 setup complete!"
echo ""
echo "Next steps:"
echo "1. Add EC2_PUBLIC_IP to GitHub Secrets"
echo "2. Add EC2_PRIVATE_KEY to GitHub Secrets"
echo "3. Push changes to main branch to trigger deployment"
