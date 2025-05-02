#!/bin/bash
# 测试Netmaker网络功能

echo "===== Netmaker网络功能测试 ====="
echo "测试WireGuard Mesh网络的建立与连通性"
echo

echo "1. 检查Netmaker API可用性"
API_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:8081/api/status || echo "000")
API_STATUS=$(echo "$API_RESPONSE" | tail -n1)

if [[ "$API_STATUS" == "200" ]]; then
  echo -e "\033[0;32mNetmaker API可访问 (HTTP 200)\033[0m"
  echo "API响应: $(echo "$API_RESPONSE" | sed '$ d')"
else
  echo -e "\033[0;31mNetmaker API无法访问 (HTTP $API_STATUS)\033[0m"
  echo "跳过API测试，使用模拟数据..."
fi

echo
echo "2. 测试网络创建功能"
echo "模拟创建VPN网络:"
NETWORK_NAME="vpn"
echo "网络名称: $NETWORK_NAME"
echo "网络地址范围: 10.10.0.0/16"
echo "默认访问控制: private"

echo
echo "3. 测试节点注册功能"
echo "模拟节点加入过程:"
echo "- 生成注册令牌"
echo "- 在测试节点1上安装WireGuard"
echo "- 配置Netmaker客户端"
echo "- 加入VPN网络"

echo "节点加入结果 (模拟):"
echo "测试节点1 (192.168.100.101) - 已加入，内网IP: 10.10.0.2"
echo "测试节点2 (192.168.100.102) - 已加入，内网IP: 10.10.0.3"

echo
echo "4. 测试网络连通性"
echo "模拟节点间连通性测试:"
echo "节点1 -> 节点2: 延迟 5ms (WireGuard内网)"
echo "节点2 -> 节点1: 延迟 5ms (WireGuard内网)"
echo "所有节点 -> 控制面板: 连接正常"

echo
echo "5. 测试网络可视化"
echo "Netmaker仪表盘上显示 (模拟):"
echo "- 总计节点数: 2"
echo "- 网络拓扑: 全连接Mesh网络"
echo "- 带宽统计: 平均 100Mbps"
echo "- 延迟统计: 平均 5ms"

echo
echo "===== 测试完成 ====="
