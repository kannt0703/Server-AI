CÀI ĐẶT SERVER UBUNTU 24.04 TỪ ĐẦU
Tôi sẽ hướng dẫn bạn cài đặt tất cả những gì cần thiết cho server Ubuntu 24.04 mới.

1. CẬP NHẬT HỆ THỐNG CƠ BẢN
bash
# Cập nhật package list và nâng cấp hệ thống
sudo apt update && sudo apt upgrade -y

# Cài đặt các công cụ cơ bản
sudo apt install -y curl wget git vim nano htop net-tools tree zip unzip build-essential software-properties-common
2. CÀI ĐẶT DOCKER & DOCKER COMPOSE
bash
# Xóa các bản cũ nếu có
sudo apt remove docker docker-engine docker.io containerd runc -y

# Cài đặt các package cần thiết
sudo apt install -y ca-certificates curl gnupg lsb-release

# Thêm Docker GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Thêm Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Cài đặt Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Kiểm tra Docker
sudo docker --version
sudo docker compose version

# Thêm user vào group docker (để chạy docker không cần sudo)
sudo usermod -aG docker $USER
newgrp docker

# Khởi động Docker
sudo systemctl enable docker
sudo systemctl start docker
3. CÀI ĐẶT NODE.JS & NPM (CHO FRONTEND)
bash
# Cài đặt Node.js 20.x (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Kiểm tra cài đặt
node --version
npm --version

# Cài đặt các global packages cần thiết
sudo npm install -g yarn pnpm
4. CÀI ĐẶT PYTHON & PIP (CHO BACKEND)
bash
# Cài đặt Python 3.11 và các công cụ
sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip python3-venv

# Cài đặt pip và pipx
sudo apt install -y python3-pip python3-pipx
python3 -m pip install --upgrade pip

# Tạo symlink (nếu cần)
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
sudo update-alternatives --config python3

# Kiểm tra cài đặt
python3 --version
pip3 --version
5. CÀI ĐẶT NGINX (TUỲ CHỌN)
bash
# Cài đặt Nginx
sudo apt install -y nginx

# Khởi động Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Kiểm tra trạng thái
sudo systemctl status nginx

# Mở firewall cho HTTP/HTTPS
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw enable
6. CÀI ĐẶT DATABASE CLIENTS
bash
# Cài đặt PostgreSQL client
sudo apt install -y postgresql-client

# Cài đặt Redis client
sudo apt install -y redis-tools

# Cài đặt SQLite
sudo apt install -y sqlite3
7. CÀI ĐẶT CÁC CÔNG CỤ QUẢN LÝ
bash
# Cài đặt tmux (terminal multiplexer)
sudo apt install -y tmux

# Cài đặt screen
sudo apt install -y screen

# Cài đặt fail2ban (bảo mật)
sudo apt install -y fail2ban

# Cài đặt certbot (SSL certificates)
sudo apt install -y certbot python3-certbot-nginx

# Cài đặt monitoring tools
sudo apt install -y nmon sysstat iotop iftop
8. CÀI ĐẶT PROJECT DEPENDENCIES
A. Backend dependencies:
bash
# Di chuyển vào thư mục backend
cd ~/server-ai/backend

# Tạo virtual environment
python3 -m venv venv
source venv/bin/activate

# Cài đặt Python dependencies
pip install --upgrade pip
pip install -r requirements.txt
B. Frontend dependencies:
bash
# Di chuyển vào thư mục frontend
cd ~/server-ai/frontend

# Cài đặt Node dependencies
npm install

# Hoặc nếu dùng yarn
# yarn install
9. FILE SETUP SCRIPT TỰ ĐỘNG
Tạo file setup_server.sh để tự động hóa toàn bộ:

bash
cat > ~/setup_server.sh << 'EOF'
#!/bin/bash

echo "========================================="
echo "  CÀI ĐẶT SERVER UBUNTU 24.04 COMPLETE  "
echo "========================================="

# Hàm kiểm tra lỗi
check_error() {
    if [ $? -ne 0 ]; then
        echo "❌ Lỗi tại bước: $1"
        exit 1
    fi
}

# 1. Cập nhật hệ thống
echo "1. Cập nhật hệ thống..."
sudo apt update && sudo apt upgrade -y
check_error "Cập nhật hệ thống"

# 2. Cài công cụ cơ bản
echo "2. Cài đặt công cụ cơ bản..."
sudo apt install -y curl wget git vim nano htop net-tools tree zip unzip build-essential software-properties-common
check_error "Cài công cụ cơ bản"

# 3. Cài Docker
echo "3. Cài đặt Docker..."
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
check_error "Cài Docker"

# 4. Cài Node.js
echo "4. Cài đặt Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g yarn pnpm
check_error "Cài Node.js"

# 5. Cài Python
echo "5. Cài đặt Python..."
sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip python3-venv
python3 -m pip install --upgrade pip
check_error "Cài Python"

# 6. Cài Nginx (tuỳ chọn)
echo "6. Cài đặt Nginx..."
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
check_error "Cài Nginx"

# 7. Thêm user vào group docker
echo "7. Cấu hình Docker permissions..."
sudo usermod -aG docker $USER

# 8. Khởi động services
echo "8. Khởi động các services..."
sudo systemctl enable docker
sudo systemctl start docker

# 9. Cài đặt các công cụ khác
echo "9. Cài đặt công cụ bổ sung..."
sudo apt install -y postgresql-client redis-tools sqlite3 tmux fail2ban

echo "========================================="
echo "✅ CÀI ĐẶT HOÀN TẤT!"
echo "========================================="
echo "Cần đăng xuất và đăng nhập lại để áp dụng các thay đổi về quyền."
echo "Hoặc chạy lệnh: newgrp docker"
echo ""
echo "Kiểm tra cài đặt:"
echo "  docker --version"
echo "  node --version"
echo "  python3 --version"
echo "  nginx -v"
EOF

# Cấp quyền thực thi
chmod +x ~/setup_server.sh
10. CHẠY DỰ ÁN SERVER-AI
bash
# Di chuyển vào thư mục dự án
cd ~/server-ai

# Kiểm tra cấu trúc
ls -la

# Khởi động project với Docker Compose
docker compose up -d --build

# Hoặc dùng docker-compose cũ
# docker-compose up -d --build

# Kiểm tra containers
docker ps

# Xem logs
docker compose logs -f

# Kiểm tra kết nối
curl http://localhost:8000
curl http://localhost:3000
11. KIỂM TRA KẾT QUẢ
bash
# Kiểm tra services đang chạy
sudo systemctl status docker
sudo systemctl status nginx

# Kiểm tra phiên bản
docker --version
docker compose version
node --version
npm --version
python3 --version

# Kiểm tra cổng mạng
sudo netstat -tulpn | grep -E '8000|3000|80'
12. QUẢN LÝ DỰ ÁN
Lệnh Docker Compose cơ bản:
bash
# Khởi động tất cả services
cd ~/server-ai
docker compose up -d

# Dừng tất cả services
docker compose down

# Xem logs realtime
docker compose logs -f

# Xem logs của service cụ thể
docker compose logs backend

# Rebuild containers
docker compose up -d --build

# Xóa volumes (cẩn thận)
docker compose down -v

# Kiểm tra resource usage
docker stats
Lệnh kiểm tra nhanh:
bash
# Kiểm tra frontend
curl -I http://localhost:3000

# Kiểm tra backend API
curl http://localhost:8000/health

# Kiểm tra API docs
curl http://localhost:8000/docs
13. XỬ LÝ LỖI THƯỜNG GẶP
Lỗi 1: Permission denied với Docker
bash
# Đăng xuất và đăng nhập lại
exit
# Sau đó SSH lại server

# Hoặc chạy lệnh
newgrp docker
Lỗi 2: Port đã được sử dụng
bash
# Kiểm tra process đang sử dụng port
sudo lsof -i :8000
sudo lsof -i :3000

# Dừng process
sudo kill -9 <PID>
Lỗi 3: Docker không chạy
bash
# Khởi động Docker service
sudo systemctl start docker
sudo systemctl enable docker
14. BACKUP & RESTORE
Backup dữ liệu:
bash
# Backup volumes
cd ~/server-ai
docker compose down
tar -czf backup_$(date +%Y%m%d_%H%M%S).tar.gz data/ docker-volumes/
docker compose up -d
Restore:
bash
# Restore từ backup
cd ~/server-ai
docker compose down
tar -xzf backup_YYYYMMDD_HHMMSS.tar.gz
docker compose up -d
15. THÔNG TIN TRUY CẬP
Sau khi cài đặt xong, bạn có thể truy cập:

Frontend: http://YOUR_SERVER_IP:3000

Backend API: http://YOUR_SERVER_IP:8000

API Documentation: http://YOUR_SERVER_IP:8000/docs

ChromaDB: http://YOUR_SERVER_IP:8001

KẾT LUẬN
Server Ubuntu 24.04 của bạn đã được cài đặt đầy đủ với:

✅ Docker & Docker Compose

✅ Node.js & npm

✅ Python 3.11 & pip

✅ Nginx

✅ Database clients

✅ Công cụ quản lý
