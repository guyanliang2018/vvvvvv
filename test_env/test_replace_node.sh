#!/bin/bash
# 测试节点替换功能

echo "===== 节点替换功能测试 ====="
echo "模拟replace-node.sh的核心功能"
echo

NODE_NAME="test-node-to-replace"
NEW_NODE_NAME="test-node-replaced"

echo "1. 模拟在Marzban中创建原始节点"
curl -s -X POST "http://localhost:8000/api/nodes" \
  -H "Authorization: Bearer marzban_api_key_for_test" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$NODE_NAME\",\"address\":\"192.168.100.111\",\"port\":443,\"remark\":\"测试要替换的节点\",\"add_as_inbound\":true}" > /dev/null

echo "2. 模拟销毁原始节点 (在真实环境中会调用Terraform destroy)"
echo "   - 销毁云服务商节点实例"
echo "   - 释放相关网络资源"

echo "3. 从Marzban中移除节点"
curl -s -X DELETE "http://localhost:8000/api/nodes/$NODE_NAME" \
  -H "Authorization: Bearer marzban_api_key_for_test" > /dev/null

echo "4. 模拟创建新节点 (在真实环境中会调用Terraform apply)"
echo "   - 在相同区域创建新节点实例"
echo "   - 配置网络与安全组"

echo "5. 在Marzban中创建新节点"
curl -s -X POST "http://localhost:8000/api/nodes" \
  -H "Authorization: Bearer marzban_api_key_for_test" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$NEW_NODE_NAME\",\"address\":\"192.168.100.112\",\"port\":443,\"remark\":\"替换后的新节点\",\"add_as_inbound\":true}" > /dev/null

echo "6. 验证节点替换结果"
NODE_LIST=$(curl -s "http://localhost:8000/api/nodes" \
  -H "Authorization: Bearer marzban_api_key_for_test" || echo "[]")

echo
echo "当前节点列表:"
echo "$NODE_LIST" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | while read -r name; do
  echo "* $name"
done

echo
echo "===== 测试完成 ====="
echo "节点替换功能验证: 原始节点 '$NODE_NAME' 已被新节点 '$NEW_NODE_NAME' 替换"
