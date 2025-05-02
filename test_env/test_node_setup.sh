#!/bin/bash
# 测试环境专用节点设置脚本

set -e

# 测试环境配置
NODE_NAME="test-generic-node"
MARZBAN_API_URL="http://host.docker.internal:8000/api"
MARZBAN_API_KEY="marzban_api_key_for_test"
NODE_REGION="test"
NODE_PROVIDER="generic"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

echo -e "${YELLOW}开始测试杂牌VPS节点配置流程${NC}"
echo -e "节点名称: ${GREEN}$NODE_NAME${NC}"
echo -e "Marzban API: ${GREEN}$MARZBAN_API_URL${NC}"

# 安装基础依赖
echo -e "${YELLOW}安装基础依赖...${NC}"
apt-get update
apt-get install -y curl jq wget

# 测试API连接
echo -e "${YELLOW}测试Marzban API连接...${NC}"
if curl -s -o /dev/null -w "%{http_code}" "$MARZBAN_API_URL/system" -H "Authorization: Bearer $MARZBAN_API_KEY"; then
  echo -e "${GREEN}API连接成功${NC}"
else
  echo -e "${RED}无法连接到Marzban API${NC}"
  echo -e "${YELLOW}尝试直接连接到API，忽略认证...${NC}"
  curl -v "$MARZBAN_API_URL/system" || true
  echo -e "${RED}请检查容器网络和API配置${NC}"
  exit 1
fi

# 注册节点到Marzban
echo -e "${YELLOW}注册节点到Marzban...${NC}"
RESPONSE=$(curl -s -X POST "$MARZBAN_API_URL/nodes" \
  -H "Authorization: Bearer $MARZBAN_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$NODE_NAME\",\"address\":\"$(hostname -I | awk '{print $1}')\",\"port\":443,\"remark\":\"测试杂牌VPS节点\",\"add_as_inbound\":true}")

# 进行模拟安装
echo -e "${YELLOW}模拟安装Xray...${NC}"
mkdir -p /usr/local/etc/xray
touch /usr/local/etc/xray/config.json
echo '{"inbounds":[], "outbounds":[]}' > /usr/local/etc/xray/config.json

# 汇报成功
echo -e "${GREEN}测试节点配置完成!${NC}"
echo -e "节点名称: ${GREEN}$NODE_NAME${NC}"
echo -e "节点IP: ${GREEN}$(hostname -I | awk '{print $1}')${NC}"
echo -e "API响应: ${YELLOW}$RESPONSE${NC}"

exit 0
