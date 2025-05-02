#!/bin/bash
# setup.sh - 一键安装脚本，用于 Xray + Netmaker + Marzban 节点设置
# 用法: curl -s https://your-server.com/setup.sh | bash -s -- --node-name=node1 --netmaker-token=xxxx --marzban-token=xxxx

set -e

# 默认配置
NODE_NAME="vpn-node-$(hostname -s)"
NETMAKER_TOKEN=""
MARZBAN_TOKEN=""
NETMAKER_SERVER="netmaker.your-domain.com"
MARZBAN_SERVER="panel.your-domain.com"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

# 解析命令行参数
for i in "$@"; do
  case $i in
    --node-name=*)
      NODE_NAME="${i#*=}"
      ;;
    --netmaker-token=*)
      NETMAKER_TOKEN="${i#*=}"
      ;;
    --marzban-token=*)
      MARZBAN_TOKEN="${i#*=}"
      ;;
    --netmaker-server=*)
      NETMAKER_SERVER="${i#*=}"
      ;;
    --marzban-server=*)
      MARZBAN_SERVER="${i#*=}"
      ;;
    *)
      echo -e "${RED}未知参数: $i${NC}"
      exit 1
      ;;
  esac
done

# 检查必要参数
if [ -z "$NETMAKER_TOKEN" ]; then
  echo -e "${RED}错误: Netmaker Token 不能为空${NC}"
  exit 1
fi

if [ -z "$MARZBAN_TOKEN" ]; then
  echo -e "${RED}错误: Marzban Token 不能为空${NC}"
  exit 1
fi

# 检测操作系统
echo -e "${GREEN}[1/6] 检测操作系统...${NC}"
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
  VERSION=$VERSION_ID
else
  echo -e "${RED}无法确定操作系统类型${NC}"
  exit 1
fi

echo -e "${GREEN}检测到操作系统: $OS $VERSION${NC}"

# 安装基础软件包
echo -e "${GREEN}[2/6] 安装基础软件包...${NC}"
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  apt update -y
  apt install -y curl wget jq socat unzip net-tools iptables
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
  yum update -y
  yum install -y curl wget jq socat unzip net-tools iptables
else
  echo -e "${RED}不支持的操作系统: $OS${NC}"
  exit 1
fi

# 安装 Docker
echo -e "${GREEN}[3/6] 安装 Docker...${NC}"
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
else
  echo -e "${YELLOW}Docker 已安装，跳过...${NC}"
fi

# 安装 Docker Compose
echo -e "${GREEN}安装 Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
  curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
else
  echo -e "${YELLOW}Docker Compose 已安装，跳过...${NC}"
fi

# 安装 Netmaker 客户端
echo -e "${GREEN}[4/6] 安装 Netmaker 客户端...${NC}"
if ! command -v netclient &> /dev/null; then
  curl -sL 'https://apt.netmaker.org/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/netclient.asc
  curl -sL 'https://apt.netmaker.org/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/netclient.list
  sudo apt update
  sudo apt install -y netclient

  # 加入 Netmaker 网络
  echo -e "${GREEN}加入 Netmaker 网络...${NC}"
  netclient join -t "$NETMAKER_TOKEN" -s "https://$NETMAKER_SERVER"
else
  echo -e "${YELLOW}Netmaker 客户端已安装，跳过...${NC}"
fi

# 安装 Node Exporter (用于监控)
echo -e "${GREEN}[5/6] 安装 Node Exporter...${NC}"
if [ ! -f "/etc/systemd/system/node_exporter.service" ]; then
  NODE_EXPORTER_VERSION="1.6.1"
  wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
  tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
  mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
  rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*
  
  cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter --collector.systemd --collector.processes

[Install]
WantedBy=default.target
EOF

  systemctl daemon-reload
  systemctl enable node_exporter
  systemctl start node_exporter
else
  echo -e "${YELLOW}Node Exporter 已安装，跳过...${NC}"
fi

# 准备 Marzban 节点配置
echo -e "${GREEN}[6/6] 注册 Marzban 节点...${NC}"
NODE_IPV4=$(curl -s https://api.ipify.org)
NODE_INTRANET_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)

# 创建临时目录
mkdir -p /opt/xray

# 注册节点到 Marzban
echo -e "${GREEN}向 Marzban 注册节点...${NC}"
REGISTER_PAYLOAD="{\"name\":\"$NODE_NAME\",\"address\":\"$NODE_INTRANET_IP\",\"inbound_tags\":[\"vmess\",\"vless\",\"trojan\",\"shadowsocks\"]}"

RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $MARZBAN_TOKEN" -d "$REGISTER_PAYLOAD" "https://$MARZBAN_SERVER/api/node")

if [[ "$RESPONSE" == *"id"* ]]; then
  NODE_ID=$(echo $RESPONSE | jq -r '.id')
  echo -e "${GREEN}节点注册成功! 节点ID: $NODE_ID${NC}"
  
  # 获取节点配置
  curl -s -H "Authorization: Bearer $MARZBAN_TOKEN" "https://$MARZBAN_SERVER/api/node/$NODE_ID/config" > /opt/xray/config.json
else
  echo -e "${RED}节点注册失败: $RESPONSE${NC}"
  exit 1
fi

# 创建 Docker Compose 文件
cat > /opt/xray/docker-compose.yml << EOF
version: '3'
services:
  xray:
    image: teddysun/xray
    container_name: xray
    restart: always
    ports:
      - 443:443
      - 80:80
    volumes:
      - ./config.json:/etc/xray/config.json
      - ./logs:/var/log/xray
    networks:
      - xray-network

networks:
  xray-network:
    driver: bridge
EOF

# 创建日志目录
mkdir -p /opt/xray/logs

# 启动 Xray
cd /opt/xray
docker-compose up -d

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}安装完成!${NC}"
echo -e "${GREEN}节点名称: $NODE_NAME${NC}"
echo -e "${GREEN}节点ID: $NODE_ID${NC}"
echo -e "${GREEN}节点公网IP: $NODE_IPV4${NC}"
echo -e "${GREEN}节点内网IP: $NODE_INTRANET_IP${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "${YELLOW}提示: 可以在 Marzban 面板中查看和管理此节点${NC}"
