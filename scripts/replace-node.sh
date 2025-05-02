#!/bin/bash
# replace-node.sh - 节点替换脚本
# 使用方法: ./replace-node.sh <provider> <node_id>

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

# 检查参数
if [ $# -lt 2 ]; then
  echo -e "${RED}错误: 缺少参数${NC}"
  echo -e "使用方法: $0 <provider> <node_id>"
  echo -e "支持的提供商: vultr, digitalocean, linode, aws, tencent, aliyun"
  exit 1
fi

PROVIDER=$1
NODE_ID=$2
CONFIG_DIR="/Users/xigua/vpn3"
TERRAFORM_DIR="$CONFIG_DIR/terraform/environments/prod"

# 检查提供商
case $PROVIDER in
  vultr|digitalocean|linode|aws|tencent|aliyun)
    echo -e "${GREEN}使用提供商: $PROVIDER${NC}"
    ;;
  *)
    echo -e "${RED}不支持的提供商: $PROVIDER${NC}"
    echo -e "支持的提供商: vultr, digitalocean, linode, aws, tencent, aliyun"
    exit 1
    ;;
esac

# 获取Marzban和Netmaker凭证
source "$CONFIG_DIR/credentials.env" 2>/dev/null || {
  echo -e "${RED}错误: 无法找到凭证文件 (credentials.env)${NC}"
  exit 1
}

# 步骤1: 从Marzban删除节点
echo -e "${GREEN}[1/4] 从Marzban删除节点 $NODE_ID...${NC}"
curl -s -X DELETE \
  -H "Authorization: Bearer $MARZBAN_API_TOKEN" \
  "https://$MARZBAN_SERVER/api/node/$NODE_ID"

echo -e "${GREEN}节点已从Marzban中删除${NC}"

# 步骤2: 从Netmaker删除节点
echo -e "${GREEN}[2/4] 从Netmaker删除节点...${NC}"
# 获取节点名称
NODE_NAME=$(curl -s -X GET \
  -H "Authorization: Bearer $NETMAKER_API_TOKEN" \
  "https://$NETMAKER_SERVER/api/nodes" | jq -r ".[] | select(.id==\"$NODE_ID\") | .name")

if [ -n "$NODE_NAME" ]; then
  curl -s -X DELETE \
    -H "Authorization: Bearer $NETMAKER_API_TOKEN" \
    "https://$NETMAKER_SERVER/api/nodes/$NODE_NAME"
  echo -e "${GREEN}节点已从Netmaker中删除${NC}"
else
  echo -e "${YELLOW}无法在Netmaker中找到节点，可能已被删除${NC}"
fi

# 步骤3: 销毁VPS实例
echo -e "${GREEN}[3/4] 销毁VPS实例...${NC}"
cd "$TERRAFORM_DIR"
# 设置Terraform变量
export TF_VAR_node_id=$NODE_ID
export TF_VAR_provider=$PROVIDER
export TF_VAR_action="destroy"

terraform apply -auto-approve -target="module.${PROVIDER}_nodes.null_resource.destroy_node[\"$NODE_ID\"]"

# 步骤4: 创建新节点
echo -e "${GREEN}[4/4] 创建新节点...${NC}"
# 生成新节点名
NEW_NODE_NAME="${PROVIDER}-$(date +%Y%m%d%H%M)"
export TF_VAR_node_name=$NEW_NODE_NAME
export TF_VAR_action="create"

terraform apply -auto-approve -target="module.${PROVIDER}_nodes.null_resource.create_node"

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}节点替换完成!${NC}"
echo -e "${GREEN}新节点名称: $NEW_NODE_NAME${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "${YELLOW}提示: 新节点将在几分钟内自动注册到系统${NC}"
