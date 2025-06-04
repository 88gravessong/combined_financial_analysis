#!/bin/bash

# 🚀 财务数据分析系统 - 云服务器一键部署脚本
# 适用于: Ubuntu/Debian/CentOS 系统

set -e  # 遇到错误时退出

echo "🚀 财务数据分析系统 - 云服务器一键部署"
echo "========================================"

# 检测操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "❌ 无法检测操作系统版本"
    exit 1
fi

echo "📋 检测到操作系统: $OS $VER"

# 更新系统
echo "📦 更新系统包..."
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y python3 python3-pip python3-venv git curl wget nginx
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
    yum update -y
    yum install -y python3 python3-pip git curl wget nginx
else
    echo "❌ 不支持的操作系统: $OS"
    exit 1
fi

# 检查Python版本
echo "🐍 检查Python环境..."
python3 --version
pip3 --version

# 创建应用目录
APP_DIR="/var/www/financial-analysis"
echo "📁 创建应用目录: $APP_DIR"
mkdir -p $APP_DIR
cd $APP_DIR

# 克隆项目代码
echo "📥 下载项目代码..."
if [ -d ".git" ]; then
    echo "项目已存在，更新代码..."
    git pull origin main
else
    git clone https://github.com/88gravessong/combined_financial_analysis.git .
fi

# 创建Python虚拟环境
echo "🔧 创建Python虚拟环境..."
python3 -m venv venv
source venv/bin/activate

# 安装Python依赖
echo "📦 安装Python依赖..."
pip install --upgrade pip
pip install -r requirements.txt

# 创建systemd服务文件
echo "⚙️ 创建系统服务..."
cat > /etc/systemd/system/financial-analysis.service << EOF
[Unit]
Description=Financial Analysis System
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/python app.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 设置权限
echo "🔐 设置文件权限..."
chown -R www-data:www-data $APP_DIR
chmod +x $APP_DIR/app.py

# 配置Nginx反向代理
echo "🌐 配置Nginx..."
cat > /etc/nginx/sites-available/financial-analysis << EOF
server {
    listen 80;
    server_name _;  # 替换为您的域名
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        proxy_send_timeout 300s;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# 启用Nginx站点
if [ -f /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi
ln -sf /etc/nginx/sites-available/financial-analysis /etc/nginx/sites-enabled/

# 测试Nginx配置
echo "🧪 测试Nginx配置..."
nginx -t

# 启动服务
echo "🚀 启动服务..."
systemctl daemon-reload
systemctl enable financial-analysis
systemctl start financial-analysis
systemctl enable nginx
systemctl restart nginx

# 配置防火墙（Ubuntu/Debian）
if command -v ufw &> /dev/null; then
    echo "🔥 配置防火墙..."
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 22/tcp
    echo "y" | ufw enable
fi

# 显示状态
echo ""
echo "✅ 部署完成！"
echo "========================================"
echo "📊 应用状态:"
systemctl status financial-analysis --no-pager -l

echo ""
echo "🌐 Nginx状态:"
systemctl status nginx --no-pager -l

echo ""
echo "🎉 访问信息:"
echo "HTTP地址: http://$(curl -s ifconfig.me || hostname -I | awk '{print $1}')"
echo "本地测试: http://localhost"

echo ""
echo "📋 管理命令:"
echo "查看应用日志: journalctl -u financial-analysis -f"
echo "重启应用: systemctl restart financial-analysis"
echo "停止应用: systemctl stop financial-analysis"
echo "更新代码: cd $APP_DIR && git pull && systemctl restart financial-analysis"
echo ""
echo "🎯 部署完成！请在浏览器中访问您的应用。" 