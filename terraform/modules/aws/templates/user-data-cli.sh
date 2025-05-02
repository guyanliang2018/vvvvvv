#!/bin/bash
# AWS EC2用户数据模板 - 用于AWS CLI创建实例

# 设置变量
NODE_NAME="%node_name%"
NETMAKER_TOKEN="%netmaker_token%"
MARZBAN_TOKEN="%marzban_token%"
NETMAKER_SERVER="%netmaker_server%"
MARZBAN_SERVER="%marzban_server%"

# 运行初始化脚本
curl -s https://raw.githubusercontent.com/yourusername/vpnhello/main/scripts/setup.sh | bash -s -- \
  --node-name="$NODE_NAME" \
  --netmaker-token="$NETMAKER_TOKEN" \
  --marzban-token="$MARZBAN_TOKEN" \
  --netmaker-server="$NETMAKER_SERVER" \
  --marzban-server="$MARZBAN_SERVER"
