#!/bin/bash
# AWS EC2用户数据 - 使用cloud-init进行初始化

# 创建临时cloud-init文件
cat > /tmp/cloud-init.yml <<'EOF'
${cloudinit}
EOF

# 替换cloud-init文件中的占位符
sed -i "s|%node_name%|${node_name}|g" /tmp/cloud-init.yml
sed -i "s|%netmaker_token%|${netmaker_token}|g" /tmp/cloud-init.yml
sed -i "s|%marzban_token%|${marzban_token}|g" /tmp/cloud-init.yml
sed -i "s|%netmaker_server%|${netmaker_server}|g" /tmp/cloud-init.yml
sed -i "s|%marzban_server%|${marzban_server}|g" /tmp/cloud-init.yml

# 使用cloud-init处理配置
cloud-init --file /tmp/cloud-init.yml init --local

# 清理
rm -f /tmp/cloud-init.yml

exit 0
