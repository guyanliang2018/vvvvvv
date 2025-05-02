#!/bin/bash
# VPN节点初始化脚本 - 用于Linode StackScripts处理cloud-init配置

# 处理输入参数
NODE_NAME="$${NODE_NAME:-$1}"
NETMAKER_TOKEN="$${NETMAKER_TOKEN:-$2}"
MARZBAN_TOKEN="$${MARZBAN_TOKEN:-$3}"
NETMAKER_SERVER="$${NETMAKER_SERVER:-$4}"
MARZBAN_SERVER="$${MARZBAN_SERVER:-$5}"

# 创建临时cloud-init文件
TMP_CLOUDINIT="/tmp/cloud-init.yml"

# 将模板内容替换为实际值并写入临时文件
cat > $TMP_CLOUDINIT <<EOF
${cloudinit_content}
EOF

# 替换占位符
sed -i "s|%node_name%|$NODE_NAME|g" $TMP_CLOUDINIT
sed -i "s|%netmaker_token%|$NETMAKER_TOKEN|g" $TMP_CLOUDINIT
sed -i "s|%marzban_token%|$MARZBAN_TOKEN|g" $TMP_CLOUDINIT
sed -i "s|%netmaker_server%|$NETMAKER_SERVER|g" $TMP_CLOUDINIT
sed -i "s|%marzban_server%|$MARZBAN_SERVER|g" $TMP_CLOUDINIT

# 安装cloud-init (如果尚未安装)
if ! command -v cloud-init &> /dev/null; then
    apt-get update
    apt-get install -y cloud-init
fi

# 使用cloud-init处理配置
cloud-init --file $TMP_CLOUDINIT init --local

# 清理
rm -f $TMP_CLOUDINIT

exit 0
