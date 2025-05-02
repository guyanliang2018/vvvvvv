#!/bin/bash
# check-nodes.sh - 节点状态检查脚本
# 使用方法: ./check-nodes.sh [--alert]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

CONFIG_DIR="/Users/xigua/vpn3"
ALERT_MODE=false

# 检查参数
for i in "$@"; do
  case $i in
    --alert)
      ALERT_MODE=true
      ;;
  esac
done

# 加载凭证
source "$CONFIG_DIR/credentials.env" 2>/dev/null || {
  echo -e "${RED}错误: 无法找到凭证文件 (credentials.env)${NC}"
  exit 1
}

# 获取所有Marzban节点
echo -e "${BLUE}获取Marzban节点列表...${NC}"
NODES=$(curl -s -X GET \
  -H "Authorization: Bearer $MARZBAN_API_TOKEN" \
  "https://$MARZBAN_SERVER/api/node")

# 检查是否获取成功
if [ -z "$NODES" ] || [ "$NODES" == "null" ] || [[ "$NODES" == *"error"* ]]; then
  echo -e "${RED}无法获取节点列表: $NODES${NC}"
  exit 1
fi

# 节点计数
TOTAL_NODES=$(echo $NODES | jq '. | length')
ONLINE_NODES=0
OFFLINE_NODES=0
PROBLEM_NODES=0

# 表头
printf "%-20s %-15s %-15s %-10s %-15s %-8s\n" "节点名称" "状态" "IP地址" "负载" "流量(上行/下行)" "延迟"
echo "--------------------------------------------------------------------------------"

# 遍历所有节点
echo $NODES | jq -c '.[]' | while read -r node; do
  NODE_ID=$(echo $node | jq -r '.id')
  NODE_NAME=$(echo $node | jq -r '.name')
  NODE_STATUS=$(echo $node | jq -r '.status')
  NODE_IP=$(echo $node | jq -r '.address')
  
  # 获取节点详情
  NODE_DETAIL=$(curl -s -X GET \
    -H "Authorization: Bearer $MARZBAN_API_TOKEN" \
    "https://$MARZBAN_SERVER/api/node/$NODE_ID")
  
  # 解析详情
  UPTIME=$(echo $NODE_DETAIL | jq -r '.uptime // "N/A"')
  LOAD=$(echo $NODE_DETAIL | jq -r '.load // "N/A"')
  UPLINK=$(echo $NODE_DETAIL | jq -r '.uplink // 0')
  DOWNLINK=$(echo $NODE_DETAIL | jq -r '.downlink // 0')
  PING=$(echo $NODE_DETAIL | jq -r '.ping // "N/A"')
  
  # 格式化流量数据 (转换为MB或GB)
  format_traffic() {
    local bytes=$1
    if [ "$bytes" == "N/A" ]; then
      echo "N/A"
    elif [ $bytes -ge 1073741824 ]; then
      echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    else
      echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    fi
  }
  
  UPLINK_FORMAT=$(format_traffic $UPLINK)
  DOWNLINK_FORMAT=$(format_traffic $DOWNLINK)
  TRAFFIC="${UPLINK_FORMAT}/${DOWNLINK_FORMAT}"
  
  # 设置状态颜色
  STATUS_COLOR=$NC
  if [ "$NODE_STATUS" == "online" ]; then
    STATUS_COLOR=$GREEN
    ONLINE_NODES=$((ONLINE_NODES + 1))
  elif [ "$NODE_STATUS" == "offline" ]; then
    STATUS_COLOR=$RED
    OFFLINE_NODES=$((OFFLINE_NODES + 1))
    PROBLEM_NODES=$((PROBLEM_NODES + 1))
  else
    STATUS_COLOR=$YELLOW
    PROBLEM_NODES=$((PROBLEM_NODES + 1))
  fi
  
  # 打印节点信息
  printf "${STATUS_COLOR}%-20s${NC} %-15s %-15s %-10s %-15s %-8s\n" \
    "$NODE_NAME" "$NODE_STATUS" "$NODE_IP" "$LOAD" "$TRAFFIC" "$PING"
  
  # 收集问题节点信息
  if [ "$NODE_STATUS" != "online" ] && [ "$ALERT_MODE" = true ]; then
    PROBLEM_NODE_INFO="$PROBLEM_NODE_INFO\n节点 '$NODE_NAME' ($NODE_IP) 状态: $NODE_STATUS"
  fi
done

# 等待后台作业完成
wait

# 打印统计信息
echo "--------------------------------------------------------------------------------"
echo -e "节点统计: 总计 ${TOTAL_NODES} 个节点，在线 ${GREEN}${ONLINE_NODES}${NC} 个，离线 ${RED}${OFFLINE_NODES}${NC} 个"

# 如果在告警模式下且有问题节点，发送告警
if [ "$ALERT_MODE" = true ] && [ $PROBLEM_NODES -gt 0 ]; then
  echo -e "${YELLOW}检测到 $PROBLEM_NODES 个问题节点，发送告警...${NC}"
  
  # 如果配置了Telegram告警
  if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    ALERT_MESSAGE="⚠️ *VPN节点告警* ⚠️\n\n检测到 $PROBLEM_NODES 个问题节点:$PROBLEM_NODE_INFO\n\n请及时处理!"
    curl -s -X POST \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\":\"$TELEGRAM_CHAT_ID\",\"text\":\"$ALERT_MESSAGE\",\"parse_mode\":\"Markdown\"}" \
      "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" > /dev/null
    
    echo -e "${GREEN}Telegram告警已发送${NC}"
  else
    echo -e "${YELLOW}未配置Telegram告警信息，跳过发送${NC}"
  fi
fi

# 返回状态码
if [ $PROBLEM_NODES -gt 0 ]; then
  exit 1
else
  exit 0
fi
