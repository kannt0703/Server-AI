#!/bin/bash

# Tạo cấu trúc thư mục hoàn chỉnh cho dự án server-ai

echo "=== TẠO CẤU TRÚC DỰ ÁN SERVER-AI ==="

# Kiểm tra xem đã có thư mục server-ai chưa
if [ -d "server-ai" ]; then
    echo "⚠️  Thư mục server-ai đã tồn tại!"
    read -p "Bạn có muốn tiếp tục? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 1. Tạo các thư mục chính
echo "1. Đang tạo thư mục chính..."
mkdir -p \
  server-ai/.github/workflows \
  server-ai/backend/{app/{api,core,models,middleware,utils},tests/{test_api,test_core,integration},config,scripts,alembic/versions,requirements} \
  server-ai/frontend/{public,src/{components/{Chat,ESP32Control,Search,Common,Layout},pages,services,store,hooks,utils,styles},tests/{unit/{components,services},integration}} \
  server-ai/esp32-code/{src,lib,tests,docs} \
  server-ai/docs/{api,architecture,setup,development} \
  server-ai/nginx/ssl \
  server-ai/scripts \
  server-ai/data/{chroma,logs,backups} \
  server-ai/monitoring/grafana/dashboards \
  server-ai/docker-volumes/{postgres-data,redis-data,chroma-data}

# 2. Tạo các file cần thiết ở thư mục gốc
echo "2. Đang tạo file ở thư mục gốc..."
touch server-ai/{.env.example,.gitignore,README.md,docker-compose.yml,docker-compose.prod.yml}

# 3. Backend Python files
echo "3. Đang tạo file backend..."
# Tạo __init__.py cho tất cả các thư mục Python (trừ __pycache__)
find server-ai/backend -type d -name "__pycache__" -prune -o -type d -exec touch {}/__init__.py \;

# Tạo các file backend quan trọng
touch server-ai/backend/{Dockerfile,Dockerfile.dev,requirements.txt,setup.py,pyproject.toml,.env}
touch server-ai/backend/app/{main.py,config.py}

# 4. Frontend files
echo "4. Đang tạo file frontend..."
touch server-ai/frontend/{package.json,Dockerfile,Dockerfile.dev,vite.config.js,.eslintrc.js,.prettierrc,jsconfig.json}
touch server-ai/frontend/public/{index.html,favicon.ico,robots.txt}
touch server-ai/frontend/src/{App.jsx,main.jsx,routes.jsx,setupTests.js}

# 5. ESP32 files
echo "5. Đang tạo file ESP32..."
touch server-ai/esp32-code/{requirements.txt,README.md}
touch server-ai/esp32-code/src/{main.py,config.py,wifi_manager.py,motor_controller.py,sensors.py}

# 6. Nginx config
echo "6. Đang tạo file nginx..."
touch server-ai/nginx/{nginx.conf,Dockerfile}

# 7. Monitoring
echo "7. Đang tạo file monitoring..."
touch server-ai/monitoring/{prometheus.yml,docker-compose.monitoring.yml}

# 8. Scripts
echo "8. Đang tạo file scripts..."
touch server-ai/scripts/{deploy.sh,backup.sh,monitor.sh}

# 9. Tạo nội dung mẫu cho một số file quan trọng
echo "9. Đang tạo nội dung mẫu..."

# .gitignore
cat > server-ai/.gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*.pyo
*.pyd
.Python
env/
venv/
.venv/
*.egg-info/
dist/
build/

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*

# Environment
.env
.env.local
.env.production

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Docker
data/
docker-volumes/

# Logs
*.log
logs/
EOF

# .env.example
cat > server-ai/.env.example << 'EOF'
# Database
CHROMA_HOST=localhost
CHROMA_PORT=8000

# API Keys
GOOGLE_API_KEY=your_google_api_key_here
OPENAI_API_KEY=your_openai_api_key_here

# ESP32
ESP32_BASE_URL=http://esp32.local
ESP32_TIMEOUT=10

# App Settings
DEBUG=true
LOG_LEVEL=INFO
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8000
SECRET_KEY=your_secret_key_here
EOF

# README.md
cat > server-ai/README.md << 'EOF'
# AI Server với ESP32 Integration

## Mô tả
Hệ thống AI server tích hợp ESP32 cho điều khiển robot thông minh.

## Tính năng
- Chat AI với RAG (Retrieval Augmented Generation)
- Điều khiển ESP32 qua API
- Tìm kiếm thông minh
- Dashboard monitoring

## Cài đặt

### Development
```bash
docker-compose up
