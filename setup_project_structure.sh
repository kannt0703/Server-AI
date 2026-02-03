#!/bin/bash

# Tạo các thư mục chính
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

# Tạo các file cần thiết
touch server-ai/{.env.example,.gitignore,README.md,docker-compose.yml,docker-compose.prod.yml}

# Backend Python files: tạo __init__.py trong mỗi thư mục con của backend (trừ __pycache__)
find server-ai/backend -type d -name "__pycache__" -prune -o -type d -exec touch {}/__init__.py \;

# Tạo các file khác trong backend
touch server-ai/backend/{Dockerfile,Dockerfile.dev,requirements.txt,setup.py,pyproject.toml,.env}

# Frontend files
touch server-ai/frontend/{package.json,Dockerfile,Dockerfile.dev,vite.config.js,.eslintrc.js,.prettierrc,jsconfig.json}

# ESP32 files
touch server-ai/esp32-code/{requirements.txt,README.md}

# Nginx config
touch server-ai/nginx/{nginx.conf,Dockerfile}

# Monitoring
touch server-ai/monitoring/{prometheus.yml,docker-compose.monitoring.yml}

# Scripts
touch server-ai/scripts/{deploy.sh,backup.sh,monitor.sh}

echo "Cấu trúc dự án đã được tạo tại thư mục server-ai"
