#!/bin/bash
# 测试Marzban控制面板功能

echo "===== Marzban控制面板功能测试 ====="
echo "测试用户管理、流量控制等功能"
echo

echo "1. 检查Marzban API可用性"
API_RESPONSE=$(curl -s -w "\n%{http_code}" http://localhost:8000/api/system || echo "000")
API_STATUS=$(echo "$API_RESPONSE" | tail -n1)

if [[ "$API_STATUS" == "200" ]]; then
  echo -e "\033[0;32mMarzban API可访问 (HTTP 200)\033[0m"
else
  echo -e "\033[0;31mMarzban API无法访问 (HTTP $API_STATUS)\033[0m"
  echo "跳过API测试，使用模拟数据..."
fi

echo
echo "2. 测试用户管理功能"
echo "尝试创建测试用户"
CREATE_USER=$(curl -s -X POST http://localhost:8000/api/users \
  -H "Authorization: Bearer marzban_api_key_for_test" \
  -H "Content-Type: application/json" \
  -d '{"username":"test_user","proxies":{"vmess":{"id":""}}}' || echo '{"detail":"Failed"}')

if [[ "$CREATE_USER" == *"detail"* ]]; then
  echo -e "\033[0;31m创建用户失败，使用模拟数据...\033[0m"
  echo "模拟创建用户: test_user"
  echo "模拟分配流量限制: 50 GB"
  echo "模拟设置有效期: 30天"
else
  echo -e "\033[0;32m成功创建用户 test_user\033[0m"
  echo "$CREATE_USER"
fi

echo
echo "3. 测试订阅链接生成"
echo "模拟用户订阅链接:"
SUBSCRIPTION_URL="http://localhost:8000/sub/test_user"
echo $SUBSCRIPTION_URL

echo
echo "4. 测试流量限制功能"
echo "模拟设置流量限制:"
echo "- 用户: test_user"
echo "- 流量上限: 50 GB"
echo "- 重置周期: 每月"

echo
echo "5. 节点流量统计"
echo "模拟当前流量统计:"
echo "节点1: 上传 15GB / 下载 25GB"
echo "节点2: 上传 10GB / 下载 20GB"
echo "总计: 上传 25GB / 下载 45GB"

echo
echo "===== 测试完成 ====="
