#!/bin/bash
# 测试杂牌VPS节点添加功能
# 此脚本在主机上执行，模拟通过外部脚本添加杂牌VPS节点

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

echo -e "${BLUE}杂牌VPS节点测试工具${NC}"
echo -e "此工具模拟添加杂牌VPS节点到Marzban系统\n"

# 测试节点信息
NODE_NAME="test-generic-node-$(date +%s)"
NODE_IP="192.168.100.101"  # 测试节点1的IP
NODE_PROVIDER="test-provider"
NODE_REGION="test-region"

# 步骤1: 验证Marzban API可访问性
echo -e "${YELLOW}步骤1: 验证Marzban API可访问性...${NC}"
API_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:8000/api/system || echo "000")
API_STATUS=$(echo "$API_RESPONSE" | tail -n1)
API_CONTENT=$(echo "$API_RESPONSE" | sed '$ d')

if [[ "$API_STATUS" == "200" ]]; then
  echo -e "${GREEN}Marzban API可访问 (HTTP 200)${NC}"
  echo -e "系统信息: $API_CONTENT"
else
  echo -e "${RED}Marzban API无法访问 (HTTP $API_STATUS)${NC}"
  echo -e "${YELLOW}检查Marzban容器状态...${NC}"
  docker ps | grep marzban
fi

# 步骤2: 模拟通过API添加节点
echo -e "\n${YELLOW}步骤2: 模拟通过API添加节点...${NC}"
echo -e "节点名称: ${BLUE}$NODE_NAME${NC}"
echo -e "节点IP: ${BLUE}$NODE_IP${NC}"

# 使用API添加节点 (仅作为模拟)
ADD_RESPONSE=$(curl -s -X POST "http://localhost:8000/api/nodes" \
  -H "Authorization: Bearer marzban_api_key_for_test" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$NODE_NAME\",\"address\":\"$NODE_IP\",\"port\":443,\"remark\":\"测试杂牌VPS节点 ($NODE_PROVIDER/$NODE_REGION)\",\"add_as_inbound\":true}")

if [[ "$ADD_RESPONSE" == *"id"* ]]; then
  NODE_ID=$(echo $ADD_RESPONSE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
  echo -e "${GREEN}节点添加成功!${NC}"
  echo -e "节点ID: ${BLUE}$NODE_ID${NC}"
else
  echo -e "${RED}节点添加失败${NC}"
  echo -e "API响应: $ADD_RESPONSE"
fi

# 步骤3: 验证节点列表
echo -e "\n${YELLOW}步骤3: 验证节点列表...${NC}"
LIST_RESPONSE=$(curl -s "http://localhost:8000/api/nodes" \
  -H "Authorization: Bearer marzban_api_key_for_test")

# 显示所有节点
echo -e "${GREEN}系统中的节点:${NC}"
echo "$LIST_RESPONSE" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | while read -r name; do
  echo -e "- $name"
done

# 步骤4: 信息提示
echo -e "\n${YELLOW}测试结果总结:${NC}"

if [[ "$ADD_RESPONSE" == *"id"* ]]; then
  echo -e "${GREEN}✓ 杂牌VPS节点添加功能测试成功!${NC}"
  echo -e "${YELLOW}重要提示:${NC} 在实际环境中，add-generic-node.sh脚本将:"
  echo "1. 连接到杂牌VPS节点 (SSH)"
  echo "2. 上传并执行setup.sh脚本"
  echo "3. 在VPS上安装Xray、Netmaker客户端和监控组件"
  echo "4. 将节点加入Marzban和Netmaker网络"
else
  echo -e "${RED}✗ 杂牌VPS节点添加功能测试失败${NC}"
  echo -e "请检查Marzban API状态和配置"
fi

exit 0
