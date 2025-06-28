#!/bin/bash

echo "Updating and upgrading the system..."
sudo apt-get update && sudo apt-get upgrade -y

echo "Installing dependencies..."
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y

echo "Adding Docker's GPG key..."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Updating package database with Docker packages..."
sudo apt-get update

echo "Installing Docker..."
sudo apt-get install docker-ce docker-ce-cli containerd.io -y

echo "Configuring Docker log rotation..."
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

echo "Enabling Docker to start on boot..."
sudo systemctl enable docker
sudo systemctl restart docker

sudo usermod -aG docker $USER
echo "⚠️  Please log out and back in to use Docker without sudo."


echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

echo "Apply executable permissions to the Docker Compose binary"
sudo chmod +x /usr/local/bin/docker-compose

echo "Verifying Docker and Docker Compose installation..."
sudo docker --version
sudo docker-compose --version

echo "Docker and Docker Compose installed successfully."


sudo apt update
sudo apt install ufw -y

sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 9100/tcp
echo "y" | sudo ufw enable
sudo ufw reload

sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
