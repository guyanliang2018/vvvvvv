#!/bin/bash
# 测试节点状态检查功能

echo "===== 节点状态检查功能测试 ====="
echo "模拟check-nodes.sh的核心功能"
echo

echo "1. 获取Marzban面板节点列表"
NODE_LIST=$(curl -s "http://localhost:8000/api/nodes" \
  -H "Authorization: Bearer marzban_api_key_for_test" || echo "[]")

echo "2. 解析节点信息"
echo "$NODE_LIST" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | while read -r name; do
  echo "* 节点: $name"
  STATUS="在线"  # 模拟状态检查
  echo "  - 状态: $STATUS"
  echo "  - 地区: 测试区域"
  echo "  - 上行: 0 MB"
  echo "  - 下行: 0 MB"
done

echo
echo "3. 检查测试节点连接"
for i in 1 2; do
  echo "* 测试节点$i (192.168.100.10$i):"
  if docker exec -i test-node-$i hostname > /dev/null 2>&1; then
    echo "  - 容器状态: 运行中"
  else
    echo "  - 容器状态: 离线"
  fi
done

echo
echo "===== 测试完成 ====="
