#!/bin/bash

echo "Cập nhật hệ thống và cài đặt các gói cơ bản..."
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget git vim tree htop

echo "Cài đặt Docker..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "Thêm user vào group Docker..."
sudo usermod -aG docker $USER
newgrp docker

echo "Cài đặt Docker Compose standalone (nếu cần)..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo "Kiểm tra cài đặt..."
docker --version
docker-compose --version

echo "Hoàn tất cài đặt!"
