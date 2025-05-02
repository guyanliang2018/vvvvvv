#!/bin/bash
# 测试环境添加节点脚本

echo -e "\033[0;34m添加测试节点到Marzban\033[0m"
echo "使用以下API和节点配置:"
echo "Marzban API: http://localhost:8000/api"
echo "API密钥: marzban_api_key_for_test"
echo "节点1: 192.168.100.101"
echo "节点2: 192.168.100.102"
echo
echo "可以通过以下方式添加节点:"
echo "1. 使用generic_nodes模块 (模拟): "
echo "   cp terraform.tfvars.test /path/to/terraform/terraform.tfvars"
echo
echo "2. 使用add-generic-node.sh脚本 (实际测试):"
echo "   cd /path/to/vpn3"
echo "   ./scripts/add-generic-node.sh -n test-node-1 -i 192.168.100.101 -r local -u root -k /Users/xigua/vpn3/test_env/ssh_keys/id_rsa"
echo
