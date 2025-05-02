#!/bin/bash
# node-stats.sh - 节点性能统计和优化脚本
# 用法: ./node-stats.sh [--optimize]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

CONFIG_DIR="/Users/xigua/vpn3"
OPTIMIZE_MODE=false

# 检查参数
for i in "$@"; do
  case $i in
    --optimize)
      OPTIMIZE_MODE=true
      ;;
  esac
done

# 加载凭证
source "$CONFIG_DIR/credentials.env" 2>/dev/null || {
  echo -e "${RED}错误: 无法找到凭证文件 (credentials.env)${NC}"
  exit 1
}

# 获取所有Marzban节点数据
echo -e "${BLUE}获取Marzban节点数据...${NC}"
NODES_DATA=$(curl -s -X GET \
  -H "Authorization: Bearer $MARZBAN_API_TOKEN" \
  "https://$MARZBAN_SERVER/api/node")

# 提取节点ID列表
NODE_IDS=$(echo $NODES_DATA | jq -r '.[].id')

# 创建节点统计表
echo -e "\n${CYAN}===== 节点性能统计 =====${NC}"
printf "%-20s %-15s %-10s %-10s %-15s %-10s\n" "节点名称" "云服务商" "延迟(ms)" "连接数" "流量(最近24h)" "CPU使用率"
echo "--------------------------------------------------------------------------------"

# 定义云服务商统计变量
declare -A CLOUD_STATS
CLOUD_STATS["vultr"]="0"
CLOUD_STATS["digitalocean"]="0"
CLOUD_STATS["linode"]="0"
CLOUD_STATS["aws"]="0"
CLOUD_STATS["other"]="0"

declare -A CLOUD_LATENCY
CLOUD_LATENCY["vultr"]="0"
CLOUD_LATENCY["digitalocean"]="0"
CLOUD_LATENCY["linode"]="0"
CLOUD_LATENCY["aws"]="0"
CLOUD_LATENCY["other"]="0"

declare -A CLOUD_COUNT
CLOUD_COUNT["vultr"]="0"
CLOUD_COUNT["digitalocean"]="0"
CLOUD_COUNT["linode"]="0"
CLOUD_COUNT["aws"]="0"
CLOUD_COUNT["other"]="0"

# 遍历所有节点
BEST_NODES=()
WORST_NODES=()

for node_id in $NODE_IDS; do
  # 获取节点详情
  NODE_DETAIL=$(curl -s -X GET \
    -H "Authorization: Bearer $MARZBAN_API_TOKEN" \
    "https://$MARZBAN_SERVER/api/node/$node_id")
  
  # 解析节点信息
  NODE_NAME=$(echo $NODE_DETAIL | jq -r '.name')
  NODE_IP=$(echo $NODE_DETAIL | jq -r '.address')
  PING=$(echo $NODE_DETAIL | jq -r '.ping // "N/A"')
  CONNECTIONS=$(echo $NODE_DETAIL | jq -r '.connections // 0')
  CPU_USAGE=$(echo $NODE_DETAIL | jq -r '.cpu_usage // "N/A"')
  UPLINK=$(echo $NODE_DETAIL | jq -r '.uplink // 0')
  DOWNLINK=$(echo $NODE_DETAIL | jq -r '.downlink // 0')
  
  # 确定云服务商
  if [[ $NODE_NAME == *"vultr"* ]]; then
    PROVIDER="vultr"
  elif [[ $NODE_NAME == *"do"* ]]; then
    PROVIDER="digitalocean"
  elif [[ $NODE_NAME == *"linode"* ]]; then
    PROVIDER="linode"
  elif [[ $NODE_NAME == *"aws"* ]]; then
    PROVIDER="aws"
  else
    PROVIDER="other"
  fi
  
  # 计算总流量 (MB)
  TOTAL_TRAFFIC=$((($UPLINK + $DOWNLINK) / 1048576))
  
  # 收集云服务商统计
  CURRENT_COUNT=${CLOUD_COUNT[$PROVIDER]}
  CLOUD_COUNT[$PROVIDER]=$((CURRENT_COUNT + 1))
  
  if [[ $PING != "N/A" && $PING -gt 0 ]]; then
    CURRENT_LATENCY=${CLOUD_LATENCY[$PROVIDER]}
    CLOUD_LATENCY[$PROVIDER]=$((CURRENT_LATENCY + PING))
  fi
  
  CURRENT_TRAFFIC=${CLOUD_STATS[$PROVIDER]}
  CLOUD_STATS[$PROVIDER]=$((CURRENT_TRAFFIC + TOTAL_TRAFFIC))
  
  # 格式化流量
  if [ $TOTAL_TRAFFIC -ge 1024 ]; then
    TRAFFIC_DISPLAY="$(echo "scale=2; $TOTAL_TRAFFIC/1024" | bc)GB"
  else
    TRAFFIC_DISPLAY="${TOTAL_TRAFFIC}MB"
  fi
  
  # 打印节点信息
  printf "%-20s %-15s %-10s %-10s %-15s %-10s\n" \
    "$NODE_NAME" "$PROVIDER" "$PING" "$CONNECTIONS" "$TRAFFIC_DISPLAY" "$CPU_USAGE"
  
  # 收集最佳/最差节点
  if [[ $PING != "N/A" && $PING -gt 0 ]]; then
    NODE_SCORE=$(echo "($PING * 10) - ($CONNECTIONS * 5) - ($CPU_USAGE * 10)" | bc)
    BEST_NODES+=("$NODE_SCORE:$NODE_NAME:$node_id:$PROVIDER")
    WORST_NODES+=("$NODE_SCORE:$NODE_NAME:$node_id:$PROVIDER")
  fi
done

# 计算云服务商平均延迟
for provider in "${!CLOUD_COUNT[@]}"; do
  count=${CLOUD_COUNT[$provider]}
  if [ $count -gt 0 ]; then
    latency=${CLOUD_LATENCY[$provider]}
    CLOUD_LATENCY[$provider]=$(echo "scale=1; $latency / $count" | bc)
  fi
done

# 打印云服务商统计
echo -e "\n${CYAN}===== 云服务商统计 =====${NC}"
printf "%-15s %-10s %-15s %-15s\n" "云服务商" "节点数量" "平均延迟(ms)" "总流量"
echo "----------------------------------------------------------"

for provider in "${!CLOUD_COUNT[@]}"; do
  count=${CLOUD_COUNT[$provider]}
  latency=${CLOUD_LATENCY[$provider]}
  traffic=${CLOUD_STATS[$provider]}
  
  # 格式化流量
  if [ $traffic -ge 1024 ]; then
    traffic_display="$(echo "scale=2; $traffic/1024" | bc)GB"
  else
    traffic_display="${traffic}MB"
  fi
  
  printf "%-15s %-10s %-15s %-15s\n" \
    "$provider" "$count" "$latency" "$traffic_display"
done

# 优化建议
echo -e "\n${CYAN}===== 优化建议 =====${NC}"

# 排序获取最佳/最差节点
IFS=$'\n' sorted_best=($(sort -n <<<"${BEST_NODES[*]}" | head -3))
IFS=$'\n' sorted_worst=($(sort -r -n <<<"${WORST_NODES[*]}" | head -3))

echo -e "${GREEN}性能最好的节点:${NC}"
for node in "${sorted_best[@]}"; do
  IFS=':' read -ra node_info <<< "$node"
  echo -e " - ${node_info[1]} (${node_info[3]}) - 推荐作为主要节点"
done

echo -e "\n${RED}性能最差的节点:${NC}"
for node in "${sorted_worst[@]}"; do
  IFS=':' read -ra node_info <<< "$node"
  echo -e " - ${node_info[1]} (${node_info[3]}) - 考虑替换或升级"
done

# 根据延迟优化云服务商分布
lowest_latency_provider=""
lowest_latency=1000
highest_latency_provider=""
highest_latency=0

for provider in "${!CLOUD_LATENCY[@]}"; do
  latency=${CLOUD_LATENCY[$provider]}
  count=${CLOUD_COUNT[$provider]}
  
  if [ $count -gt 0 ] && (( $(echo "$latency < $lowest_latency" | bc -l) )); then
    lowest_latency=$latency
    lowest_latency_provider=$provider
  fi
  
  if [ $count -gt 0 ] && (( $(echo "$latency > $highest_latency" | bc -l) )); then
    highest_latency=$latency
    highest_latency_provider=$provider
  fi
done

echo -e "\n${YELLOW}云服务商优化建议:${NC}"
if [ -n "$lowest_latency_provider" ] && [ -n "$highest_latency_provider" ] && [ "$lowest_latency_provider" != "$highest_latency_provider" ]; then
  echo -e " - 考虑增加 ${GREEN}$lowest_latency_provider${NC} 的节点数量 (平均延迟: ${lowest_latency}ms)"
  echo -e " - 考虑减少 ${RED}$highest_latency_provider${NC} 的节点数量 (平均延迟: ${highest_latency}ms)"
fi

# 执行优化操作
if [ "$OPTIMIZE_MODE" = true ]; then
  echo -e "\n${CYAN}===== 执行优化操作 =====${NC}"
  
  # 获取最差节点，准备替换
  IFS=':' read -ra worst_node <<< "${sorted_worst[0]}"
  worst_node_id=${worst_node[2]}
  worst_node_provider=${worst_node[3]}
  
  echo -e "${YELLOW}正在替换性能最差的节点: ${worst_node[1]}${NC}"
  
  # 使用replace-node.sh脚本替换节点
  "$CONFIG_DIR/scripts/replace-node.sh" "$worst_node_provider" "$worst_node_id"
  
  # 为最佳节点提升优先级
  for node in "${sorted_best[@]}"; do
    IFS=':' read -ra node_info <<< "$node"
    node_id=${node_info[2]}
    
    echo -e "${GREEN}提升节点 ${node_info[1]} 的优先级...${NC}"
    
    # 更新节点优先级
    curl -s -X PUT \
      -H "Authorization: Bearer $MARZBAN_API_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"priority": 10}' \
      "https://$MARZBAN_SERVER/api/node/$node_id"
  done
fi

echo -e "\n${CYAN}===== 统计完成 =====${NC}"
