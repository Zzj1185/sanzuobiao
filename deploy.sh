#!/bin/bash
# 三坐标测量数据生成工具 - 一键部署脚本
# 适用于 Ubuntu/Debian 服务器

set -e

echo "=========================================="
echo "  三坐标测量工具 - 一键部署"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请使用 root 用户运行此脚本${NC}"
  echo "执行: sudo bash deploy.sh"
  exit 1
fi

# 安装目录
INSTALL_DIR="/opt/sanzuobiao"
SERVICE_NAME="sanzuobiao"
PORT=5000

echo ""
echo "[1/6] 更新系统并安装依赖..."
apt update -qq
apt install -y python3 python3-pip python3-venv git > /dev/null

echo "[2/6] 克隆项目..."
if [ -d "$INSTALL_DIR" ]; then
  echo "目录已存在，更新代码..."
  cd $INSTALL_DIR
  git pull
else
  git clone https://github.com/Zzj1185/sanzuobiao.git $INSTALL_DIR
  cd $INSTALL_DIR
fi

echo "[3/6] 创建虚拟环境并安装依赖..."
python3 -m venv venv
source venv/bin/activate
pip install -q flask openpyxl gunicorn

echo "[4/6] 创建 systemd 服务..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=三坐标测量数据生成工具
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/venv/bin/gunicorn -w 2 -b 0.0.0.0:${PORT} web_app:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "[5/6] 启动服务..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME} > /dev/null 2>&1
systemctl restart ${SERVICE_NAME}

echo "[6/6] 检查服务状态..."
sleep 2
if systemctl is-active --quiet ${SERVICE_NAME}; then
  echo -e "${GREEN}✓ 服务启动成功！${NC}"
else
  echo -e "${RED}✗ 服务启动失败，请检查日志：journalctl -u ${SERVICE_NAME}${NC}"
  exit 1
fi

# 获取服务器 IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo -e "${GREEN}部署完成！${NC}"
echo "=========================================="
echo ""
echo "访问地址: http://${SERVER_IP}:${PORT}"
echo ""
echo "常用命令:"
echo "  查看状态: systemctl status ${SERVICE_NAME}"
echo "  重启服务: systemctl restart ${SERVICE_NAME}"
echo "  查看日志: journalctl -u ${SERVICE_NAME} -f"
echo "  停止服务: systemctl stop ${SERVICE_NAME}"
echo ""
echo -e "${RED}重要：请在腾讯云控制台防火墙中放行 ${PORT} 端口！${NC}"
echo "=========================================="
