#!/bin/bash
# security-audit.sh - 节点安全审计和加固脚本
# 用法: ./security-audit.sh [--fix] [--node hostname]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

CONFIG_DIR="/Users/xigua/vpn3"
FIX_MODE=false
TARGET_NODE=""

# 检查参数
for i in "$@"; do
  case $i in
    --fix)
      FIX_MODE=true
      ;;
    --node=*)
      TARGET_NODE="${i#*=}"
      ;;
  esac
done

# 加载凭证
source "$CONFIG_DIR/credentials.env" 2>/dev/null || {
  echo -e "${RED}错误: 无法找到凭证文件 (credentials.env)${NC}"
  exit 1
}

# 获取节点列表
get_nodes() {
  if [ -n "$TARGET_NODE" ]; then
    echo "$TARGET_NODE"
  else
    # 从Marzban API获取节点列表
    curl -s -X GET \
      -H "Authorization: Bearer $MARZBAN_API_TOKEN" \
      "https://$MARZBAN_SERVER/api/node" | jq -r '.[].address'
  fi
}

# 安全审计函数
audit_node() {
  local node=$1
  echo -e "${BLUE}====== 安全审计: $node ======${NC}"
  
  # 通过SSH连接到节点进行审计
  ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$node "bash -s" << 'EOL'
    # 获取系统信息
    echo -e "\n==== 系统信息 ===="
    hostname
    uname -a
    
    # 检查关键服务
    echo -e "\n==== 服务状态 ===="
    systemctl status fail2ban | grep "Active"
    docker ps --format "{{.Names}} ({{.Status}})"
    
    # 查找未授权SSH密钥
    echo -e "\n==== SSH密钥检查 ===="
    if [ -f ~/.ssh/authorized_keys ]; then
      echo "发现$(wc -l < ~/.ssh/authorized_keys)个授权SSH密钥"
    else
      echo "未找到授权SSH密钥文件"
    fi
    
    # 检查SSH配置
    echo -e "\n==== SSH安全配置检查 ===="
    grep "PermitRootLogin" /etc/ssh/sshd_config
    grep "PasswordAuthentication" /etc/ssh/sshd_config
    
    # 检查异常进程
    echo -e "\n==== 异常进程检查 ===="
    ps aux | grep -v grep | grep -E 'crypto|mine|monero|xmrig'
    
    # 检查定时任务
    echo -e "\n==== 定时任务检查 ===="
    crontab -l 2>/dev/null || echo "无定时任务"
    
    # 检查最近登录
    echo -e "\n==== 最近登录 ===="
    last | head -5
    
    # 检查防火墙规则
    echo -e "\n==== 防火墙规则 ===="
    iptables -L -n | wc -l
    
    # 检查开放端口
    echo -e "\n==== 开放端口 ===="
    netstat -tulpn | grep LISTEN | grep -v 127.0.0.1
    
    # 检查Docker镜像
    echo -e "\n==== Docker镜像检查 ===="
    docker images
    
    # 检查系统日志中的可疑条目
    echo -e "\n==== 日志可疑条目 ===="
    grep -i "Failed password\|authentication failure" /var/log/auth.log | tail -5
    
    # 检查系统用户
    echo -e "\n==== 系统用户检查 ===="
    grep -v "nologin\|false" /etc/passwd
    
    # 检查持久化后门
    echo -e "\n==== 后门检查 ===="
    find /etc/init.d /etc/init /etc/systemd/system -type f -name "*.service" | xargs grep -l "bash\|wget\|curl" 2>/dev/null
    
    # 安全漏洞检查结果
    echo -e "\n==== 安全检查总结 ===="
    
    ISSUES=0
    
    # 检查SSH密码认证
    if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
      echo -e "⚠️ SSH允许密码认证"
      ISSUES=$((ISSUES+1))
    else
      echo -e "✅ SSH已禁用密码认证"
    fi
    
    # 检查Root登录
    if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config && ! grep -q "PermitRootLogin prohibit-password" /etc/ssh/sshd_config; then
      echo -e "⚠️ 允许Root直接登录"
      ISSUES=$((ISSUES+1))
    else
      echo -e "✅ Root登录已限制"
    fi
    
    # 检查Fail2ban
    if ! systemctl is-active --quiet fail2ban; then
      echo -e "⚠️ Fail2ban未运行"
      ISSUES=$((ISSUES+1))
    else
      echo -e "✅ Fail2ban正在运行"
    fi
    
    # 检查防火墙
    if [ "$(iptables -L -n | grep -c "^Chain")" -lt 3 ]; then
      echo -e "⚠️ 防火墙规则不足"
      ISSUES=$((ISSUES+1))
    else
      echo -e "✅ 防火墙已配置"
    fi
    
    # 检查未禁用的无用端口
    ALL_PORTS=$(netstat -tulpn | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq)
    for PORT in $ALL_PORTS; do
      if ! [[ "$PORT" =~ ^(22|80|443|51820|51821|8080|8443|8444|8445|8446|8448|9100|10000)$ ]]; then
        echo -e "⚠️ 检测到未知端口: $PORT"
        ISSUES=$((ISSUES+1))
      fi
    done
    
    # 检查系统更新
    if [ -f /var/run/reboot-required ]; then
      echo -e "⚠️ 系统需要重启以应用更新"
      ISSUES=$((ISSUES+1))
    else
      echo -e "✅ 系统不需要重启"
    fi
    
    echo "发现 $ISSUES 个安全问题"
    
    # 输出修复标记，用于后续处理
    echo "SECURITY_ISSUES=$ISSUES"
EOL
}

# 修复节点安全问题
fix_node() {
  local node=$1
  echo -e "${YELLOW}====== 安全加固: $node ======${NC}"
  
  # 通过SSH连接到节点进行加固
  ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$node "bash -s" << 'EOL'
    # 禁用SSH密码认证
    echo -e "\n==== 加固SSH配置 ===="
    if grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then
      sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
      echo "✅ 已禁用SSH密码认证"
    fi
    
    # 限制Root登录仅允许密钥
    if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then
      sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
      echo "✅ 已限制Root登录"
    fi
    
    # 重启SSH服务
    systemctl restart sshd
    
    # 安装Fail2ban（如未安装）
    if ! command -v fail2ban-server &> /dev/null; then
      echo -e "\n==== 安装Fail2ban ===="
      apt-get update
      apt-get install -y fail2ban
    fi
    
    # 配置Fail2ban
    echo -e "\n==== 配置Fail2ban ===="
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
banaction = iptables-multiport

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
    
    # 启动Fail2ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    # 配置防火墙
    echo -e "\n==== 配置防火墙 ===="
    # 先保存当前开放端口列表
    OPEN_PORTS=$(netstat -tulpn | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq)
    
    # 基本规则
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # 允许已建立的连接
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # 允许本地回环
    iptables -A INPUT -i lo -j ACCEPT
    
    # 允许SSH
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # 允许HTTP/HTTPS
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # 允许WireGuard
    iptables -A INPUT -p udp --dport 51820 -j ACCEPT
    iptables -A INPUT -p udp --dport 51821 -j ACCEPT
    
    # 允许Xray服务端口
    for PORT in 8443 8444 8445 8446 8448; do
      iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
    done
    
    # 允许监控端口
    iptables -A INPUT -p tcp --dport 9100 -j ACCEPT
    
    # 拒绝其他所有入站流量
    iptables -A INPUT -j DROP
    
    # 保存规则
    if command -v iptables-save &> /dev/null; then
      iptables-save > /etc/iptables/rules.v4
    else
      mkdir -p /etc/iptables
      iptables-save > /etc/iptables/rules.v4
      echo "#!/bin/sh
iptables-restore < /etc/iptables/rules.v4
exit 0" > /etc/network/if-pre-up.d/iptables
      chmod +x /etc/network/if-pre-up.d/iptables
    fi
    
    # 更新系统
    echo -e "\n==== 更新系统 ===="
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    
    # 清理定时任务（保留关键任务）
    echo -e "\n==== 清理定时任务 ===="
    crontab -l > /tmp/cron_bkp
    grep -E 'check_system|report_status|node_exporter|acme.sh' /tmp/cron_bkp > /tmp/cron_new
    crontab /tmp/cron_new
    rm /tmp/cron_bkp /tmp/cron_new
    
    # 移除未使用的包
    echo -e "\n==== 清理未使用的包 ===="
    apt-get autoremove -y
    
    echo -e "\n==== 安全加固完成 ===="
EOL
}

# 主程序
echo -e "${BLUE}开始节点安全审计...${NC}"

# 处理所有节点
for node in $(get_nodes); do
  # 执行审计
  audit_result=$(audit_node $node)
  echo "$audit_result"
  
  # 提取安全问题数量
  issues=$(echo "$audit_result" | grep "SECURITY_ISSUES=" | cut -d= -f2)
  
  # 如果处于修复模式且有安全问题，执行修复
  if [ "$FIX_MODE" = true ] && [ -n "$issues" ] && [ "$issues" -gt 0 ]; then
    echo -e "${YELLOW}检测到 $issues 个安全问题，开始修复...${NC}"
    fix_node $node
  fi
done

echo -e "${GREEN}安全审计完成!${NC}"
if [ "$FIX_MODE" = false ] && [ -n "$issues" ] && [ "$issues" -gt 0 ]; then
  echo -e "${YELLOW}建议: 使用 --fix 参数运行此脚本以修复发现的安全问题${NC}"
fi
