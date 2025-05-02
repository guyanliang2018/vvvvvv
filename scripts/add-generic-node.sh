#!/bin/bash
# 添加杂牌VPS节点到系统的脚本
# 作者: Cascade
# 日期: 2023-05-02

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 帮助信息
function show_help {
  echo -e "${BLUE}杂牌VPS节点添加工具${NC}"
  echo "此脚本帮助您将任何VPS服务器添加到多云VPN自动化系统中"
  echo
  echo "用法:"
  echo "  $0 [-n 节点名称] [-i IP地址] [-r 区域] [-u SSH用户] [-p SSH端口] [-k SSH密钥路径]"
  echo
  echo "选项:"
  echo "  -n    节点名称 (如: jp-vps-01)"
  echo "  -i    VPS的IP地址"
  echo "  -r    区域代码 (如: jp, hk, us, etc.)"
  echo "  -u    SSH用户名 (默认: root)"
  echo "  -p    SSH端口 (默认: 22)"
  echo "  -k    SSH密钥路径 (默认: ~/.ssh/id_rsa)"
  echo "  -b    批处理模式 (不询问确认)"
  echo "  -h    显示此帮助信息"
  echo
  echo "示例:"
  echo "  $0 -n jp-vps-01 -i 123.456.789.10 -r jp -u root"
  exit 1
}

# 默认值
SSH_USER="root"
SSH_PORT=22
SSH_KEY="~/.ssh/id_rsa"
BATCH_MODE=false
NODE_PROVIDER="generic"

# 解析命令行参数
while getopts "n:i:r:u:p:k:bh" opt; do
  case $opt in
    n) NODE_NAME="$OPTARG" ;;
    i) IP_ADDRESS="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    u) SSH_USER="$OPTARG" ;;
    p) SSH_PORT="$OPTARG" ;;
    k) SSH_KEY="$OPTARG" ;;
    b) BATCH_MODE=true ;;
    h) show_help ;;
    *) echo -e "${RED}无效选项: -$OPTARG${NC}" >&2; show_help ;;
  esac
done

# 检查必需参数
if [ -z "$NODE_NAME" ] || [ -z "$IP_ADDRESS" ] || [ -z "$REGION" ]; then
  echo -e "${RED}错误: 缺少必需参数${NC}"
  show_help
fi

# 询问确认
if [ "$BATCH_MODE" != true ]; then
  echo -e "${YELLOW}您将添加以下节点:${NC}"
  echo -e "节点名称: ${BLUE}$NODE_NAME${NC}"
  echo -e "IP地址: ${BLUE}$IP_ADDRESS${NC}"
  echo -e "区域: ${BLUE}$REGION${NC}"
  echo -e "SSH用户: ${BLUE}$SSH_USER${NC}"
  echo -e "SSH端口: ${BLUE}$SSH_PORT${NC}"
  echo -e "SSH密钥: ${BLUE}$SSH_KEY${NC}"
  echo
  read -p "确认添加此节点? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}操作已取消${NC}"
    exit 1
  fi
fi

# 测试SSH连接
echo -e "${YELLOW}测试SSH连接...${NC}"
SSH_TEST_RESULT=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 -p "$SSH_PORT" -i "$SSH_KEY" "$SSH_USER@$IP_ADDRESS" "echo 连接成功" 2>&1) || SSH_STATUS=$?

if [ -n "$SSH_STATUS" ]; then
  echo -e "${RED}SSH连接失败:${NC}"
  echo "$SSH_TEST_RESULT"
  
  if [[ "$SSH_TEST_RESULT" == *"Permission denied"* ]]; then
    echo -e "${YELLOW}提示: 可能是SSH密钥不匹配或权限问题。请检查:${NC}"
    echo "1. SSH密钥是否正确"
    echo "2. 用户名是否正确"
    echo "3. VPS是否允许SSH密钥认证"
  elif [[ "$SSH_TEST_RESULT" == *"Connection refused"* ]]; then
    echo -e "${YELLOW}提示: 连接被拒绝，请检查:${NC}"
    echo "1. IP地址是否正确"
    echo "2. SSH端口是否正确"
    echo "3. VPS防火墙是否开放SSH端口"
  elif [[ "$SSH_TEST_RESULT" == *"Connection timed out"* ]]; then
    echo -e "${YELLOW}提示: 连接超时，请检查:${NC}"
    echo "1. IP地址是否正确"
    echo "2. VPS是否在线"
    echo "3. 网络连接是否稳定"
  fi
  
  exit 1
fi

echo -e "${GREEN}SSH连接成功!${NC}"

# 读取现有terraform.tfvars
TERRAFORM_DIR="../terraform"
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
  echo -e "${YELLOW}未找到terraform.tfvars文件，将创建新文件${NC}"
  cp "$TERRAFORM_DIR/terraform.tfvars.example" "$TFVARS_FILE" || {
    echo -e "${RED}无法创建terraform.tfvars文件${NC}"
    exit 1
  }
  # 替换示例节点配置为空数组
  sed -i '' 's/generic_nodes = \[.*\]/generic_nodes = \[\]/g' "$TFVARS_FILE" || {
    echo -e "${RED}无法修改terraform.tfvars文件${NC}"
    exit 1
  }
fi

# 检查是否有现有generic_nodes配置
if grep -q "generic_nodes = \[\]" "$TFVARS_FILE"; then
  # 没有现有节点，添加第一个节点
  NEW_CONFIG=$(cat <<EOF
generic_nodes = [
  {
    name       = "$NODE_NAME"
    ip_address = "$IP_ADDRESS"
    provider   = "$NODE_PROVIDER"
    region     = "$REGION"
    ssh_user   = "$SSH_USER"
    ssh_port   = $SSH_PORT
  }
]
EOF
)
  sed -i '' "s/generic_nodes = \[\]/$(echo "$NEW_CONFIG" | sed 's/\//\\\//g')/g" "$TFVARS_FILE" || {
    echo -e "${RED}无法更新terraform.tfvars文件${NC}"
    exit 1
  }
elif grep -q "generic_nodes = \[" "$TFVARS_FILE"; then
  # 已有节点，追加新节点
  NEW_NODE=$(cat <<EOF
  {
    name       = "$NODE_NAME"
    ip_address = "$IP_ADDRESS"
    provider   = "$NODE_PROVIDER"
    region     = "$REGION"
    ssh_user   = "$SSH_USER"
    ssh_port   = $SSH_PORT
  }
EOF
)
  # 在最后一个节点后添加新节点
  sed -i '' "/  }/a\\
$NEW_NODE
" "$TFVARS_FILE" || {
    echo -e "${RED}无法更新terraform.tfvars文件${NC}"
    exit 1
  }
else
  # 没有找到generic_nodes配置，添加完整配置
  echo -e "${YELLOW}未找到generic_nodes配置，添加到文件末尾${NC}"
  NEW_CONFIG=$(cat <<EOF

# 通用杂牌VPS节点配置
generic_nodes = [
  {
    name       = "$NODE_NAME"
    ip_address = "$IP_ADDRESS"
    provider   = "$NODE_PROVIDER"
    region     = "$REGION"
    ssh_user   = "$SSH_USER"
    ssh_port   = $SSH_PORT
  }
]
EOF
)
  echo "$NEW_CONFIG" >> "$TFVARS_FILE" || {
    echo -e "${RED}无法更新terraform.tfvars文件${NC}"
    exit 1
  }
fi

echo -e "${GREEN}节点 $NODE_NAME 已成功添加到配置中!${NC}"
echo -e "${YELLOW}下一步操作:${NC}"
echo "1. 进入terraform目录: cd ../terraform"
echo "2. 应用配置: terraform apply -target=module.generic_nodes"
echo

exit 0
