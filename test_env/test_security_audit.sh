#!/bin/bash
# 测试节点安全审计功能

echo "===== 节点安全审计功能测试 ====="
echo "模拟security-audit.sh的核心功能"
echo

echo "1. 测试节点1 (192.168.100.101) 安全审计"
echo "SSH配置检查:"
docker exec test-node-1 grep "PermitRootLogin" /etc/ssh/sshd_config
docker exec test-node-1 grep "PasswordAuthentication" /etc/ssh/sshd_config

echo "防火墙状态检查:"
docker exec test-node-1 which ufw >/dev/null && docker exec test-node-1 ufw status || echo "防火墙未安装"

echo "已安装软件包审计:"
docker exec test-node-1 dpkg -l | grep -E 'ssh|ufw|fail2ban' | wc -l

echo "开放端口扫描:"
docker exec test-node-1 netstat -tulpn 2>/dev/null | grep LISTEN || echo "netstat未安装"

echo
echo "2. 安全风险评估"
echo "测试节点1安全评分: 65/100 (模拟数据)"
echo "发现的风险:"
echo "  - [高危] SSH允许root密码登录"
echo "  - [中危] 未安装防火墙"
echo "  - [低危] 未安装fail2ban防暴力破解"

echo
echo "3. 自动修复建议"
echo "推荐修复措施:"
echo "  - 禁用SSH密码认证，仅允许密钥认证"
echo "  - 配置UFW防火墙，仅开放必要端口"
echo "  - 安装并配置fail2ban"
echo "  - 更新系统补丁"

echo
echo "4. 模拟自动修复过程"
echo "执行SSH安全加固:"
echo "  - 修改SSH配置禁用root登录"
echo "  - 设置仅允许密钥认证"

echo "安装并配置防火墙:"
echo "  - apt-get install -y ufw"
echo "  - ufw allow 22/tcp"
echo "  - ufw allow 443/tcp"
echo "  - ufw enable"

echo "安装fail2ban防暴力破解:"
echo "  - apt-get install -y fail2ban"
echo "  - 配置SSH防护规则"

echo
echo "5. 修复后验证"
echo "测试节点1安全评分: 90/100 (模拟数据)"
echo "剩余风险:"
echo "  - [低危] 系统日志监控未配置"

echo
echo "===== 测试完成 ====="
