#!/bin/bash

# VPS系统诊断脚本 - 全面检查网络、服务和配置问题
# 用法: bash diagnostics.sh [域名]
# 示例: bash diagnostics.sh vpn.mytelcc.xyz

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 检测sudo权限
HAS_SUDO=0
if command -v sudo &> /dev/null && sudo -n true 2>/dev/null; then
    HAS_SUDO=1
fi

# 导入环境变量
if [ -f ".env" ]; then
    source .env
    echo -e "${GREEN}成功加载 .env 文件${NC}"
else
    echo -e "${YELLOW}警告: .env 文件不存在, 使用默认值${NC}"
fi

# 设置域名
if [ -z "$1" ]; then
    if [ -n "$BASE_DOMAIN" ]; then
        DOMAIN="$BASE_DOMAIN"
        echo -e "${BLUE}使用 .env 中的域名: $DOMAIN${NC}"
    else
        DOMAIN="vpn.mytelcc.xyz"
        echo -e "${YELLOW}未提供域名参数，使用默认值: $DOMAIN${NC}"
    fi
else
    DOMAIN="$1"
    echo -e "${GREEN}使用提供的域名: $DOMAIN${NC}"
fi

# 定义检查标题函数
print_section() {
    echo -e "\n${PURPLE}===== $1 =====${NC}"
}

# 定义状态检查函数
check_status() {
    if [ "$1" -eq 0 ]; then
        echo -e "[${GREEN}✓${NC}] $2"
    else
        echo -e "[${RED}✗${NC}] $3"
    fi
}

# 创建诊断结果目录
DIAG_DIR="diagnostics_results"
mkdir -p "$DIAG_DIR"
DIAG_FILE="$DIAG_DIR/diagnostic_$(date +%Y%m%d_%H%M%S).log"
echo "VPS诊断结果 - $(date)" > "$DIAG_FILE"
echo "域名: $DOMAIN" >> "$DIAG_FILE"

# 获取服务器基本信息
print_section "系统基本信息"
echo -e "${CYAN}主机名:${NC} $(hostname)"
echo -e "${CYAN}系统版本:${NC} $(cat /etc/os-release | grep "PRETTY_NAME" | cut -d= -f2 | tr -d '"')"
echo -e "${CYAN}内核版本:${NC} $(uname -r)"
echo -e "${CYAN}IP地址:${NC} $(hostname -I | awk '{print $1}')"
echo -e "${CYAN}时间:${NC} $(date)"
echo -e "${CYAN}运行时间:${NC} $(uptime -p)"

# 检查系统资源
print_section "系统资源检查"
echo -e "${CYAN}CPU使用率:${NC}"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F. '{print $1"%"}'

echo -e "${CYAN}内存使用情况:${NC}"
free -h | grep "Mem:" | awk '{print "总计: " $2 " | 已用: " $3 " | 可用: " $4}'

echo -e "${CYAN}磁盘使用情况:${NC}"
df -h / | awk 'NR==2 {print "总计: " $2 " | 已用: " $3 " | 可用: " $4 " | 使用率: " $5}'

# 检查DNS解析
print_section "DNS解析检查"
echo -e "${CYAN}DNS服务器配置:${NC}"
cat /etc/resolv.conf | grep "nameserver"

echo -e "\n${CYAN}域名解析测试:${NC}"
# 测试主要域名解析
SERVER_IP=$(hostname -I | awk '{print $1}')
dig +short $DOMAIN > /dev/null 2>&1
check_status $? "主域名解析正常: $DOMAIN" "主域名解析失败: $DOMAIN"

# 测试面板子域名解析
PANEL_DOMAIN="panel.$DOMAIN"
IP_PANEL=$(dig +short $PANEL_DOMAIN)
if [ -n "$IP_PANEL" ]; then
    if [ "$IP_PANEL" = "$SERVER_IP" ]; then
        echo -e "[${GREEN}✓${NC}] 面板域名解析正确: $PANEL_DOMAIN -> $IP_PANEL"
    else
        echo -e "[${YELLOW}!${NC}] 面板域名解析到错误IP: $PANEL_DOMAIN -> $IP_PANEL (服务器IP: $SERVER_IP)"
    fi
else
    echo -e "[${RED}✗${NC}] 面板域名解析失败: $PANEL_DOMAIN"
fi

# 测试Netmaker子域名解析
NETMAKER_DOMAIN="netmaker.$DOMAIN"
IP_NETMAKER=$(dig +short $NETMAKER_DOMAIN)
if [ -n "$IP_NETMAKER" ]; then
    if [ "$IP_NETMAKER" = "$SERVER_IP" ]; then
        echo -e "[${GREEN}✓${NC}] Netmaker域名解析正确: $NETMAKER_DOMAIN -> $IP_NETMAKER"
    else
        echo -e "[${YELLOW}!${NC}] Netmaker域名解析到错误IP: $NETMAKER_DOMAIN -> $IP_NETMAKER (服务器IP: $SERVER_IP)"
    fi
else
    echo -e "[${RED}✗${NC}] Netmaker域名解析失败: $NETMAKER_DOMAIN"
fi

# 检查端口监听状态
print_section "端口监听检查"
echo -e "${CYAN}关键端口监听状态:${NC}"

# 定义需要检查的端口列表
PORTS_TCP=(4443 8080 5443 8095 8884)
PORTS_UDP=(3485 51821)

# 获取端口对应的服务名称的辅助函数
get_service_by_port() {
    local PORT=$1
    local SERVICE=""
    
    case $PORT in
        4443)
            SERVICE="Marzban HTTPS"
            ;;
        8080)
            SERVICE="Marzban HTTP"
            ;;
        5443)
            SERVICE="Netmaker HTTPS"
            ;;
        8095)
            SERVICE="Netmaker API"
            ;;
        8884)
            SERVICE="Netmaker MQTT"
            ;;
        3485)
            SERVICE="Netmaker STUN (UDP)"
            ;;
        51821)
            SERVICE="WireGuard (UDP)"
            ;;
        *)
            SERVICE="未知服务"
            ;;
    esac
    
    echo $SERVICE
}

# 检查TCP端口
echo -e "\n${CYAN}TCP端口状态:${NC}"
for PORT in "${PORTS_TCP[@]}"; do
    if [ $HAS_SUDO -eq 1 ]; then
        LISTENING=$(sudo ss -tlnp | grep ":$PORT " | wc -l)
    else
        LISTENING=$(ss -tlnp 2>/dev/null | grep ":$PORT " | wc -l)
    fi
    
    if [ "$LISTENING" -gt 0 ]; then
        echo -e "[${GREEN}✓${NC}] TCP端口 $PORT 已在监听"
        if [ $HAS_SUDO -eq 1 ]; then
            echo "    进程信息: $(sudo ss -tlnp | grep ":$PORT " | awk '{print $6}')"
        fi
        echo "    $PORT -> $(get_service_by_port $PORT)" >> "$DIAG_FILE"
    else
        echo -e "[${RED}✗${NC}] TCP端口 $PORT 未在监听"
        echo "    $PORT 未监听" >> "$DIAG_FILE"
    fi
done

# 检查UDP端口
echo -e "\n${CYAN}UDP端口状态:${NC}"
for PORT in "${PORTS_UDP[@]}"; do
    if [ $HAS_SUDO -eq 1 ]; then
        LISTENING=$(sudo ss -ulnp | grep ":$PORT " | wc -l)
    else
        LISTENING=$(ss -ulnp 2>/dev/null | grep ":$PORT " | wc -l)
    fi
    
    if [ "$LISTENING" -gt 0 ]; then
        echo -e "[${GREEN}✓${NC}] UDP端口 $PORT 已在监听"
        if [ $HAS_SUDO -eq 1 ]; then
            echo "    进程信息: $(sudo ss -ulnp | grep ":$PORT " | awk '{print $6}')"
        fi
    else
        echo -e "[${RED}✗${NC}] UDP端口 $PORT 未在监听"
    fi
done

# 检查防火墙状态
print_section "防火墙检查"
echo -e "${CYAN}防火墙状态:${NC}"

if [ $HAS_SUDO -eq 1 ]; then
    if command -v ufw &> /dev/null; then
        echo -e "${CYAN}UFW防火墙:${NC}"
        sudo ufw status verbose
        echo -e "\n${CYAN}检查关键端口是否在UFW中开放:${NC}"
        
        for PORT in "${PORTS_TCP[@]}"; do
            UFW_RULE=$(sudo ufw status | grep "$PORT/tcp" | wc -l)
            if [ "$UFW_RULE" -gt 0 ]; then
                echo -e "[${GREEN}✓${NC}] TCP端口 $PORT 在UFW中已开放"
                echo "    UFW: TCP $PORT open" >> "$DIAG_FILE"
            else
                echo -e "[${YELLOW}!${NC}] TCP端口 $PORT 在UFW中可能未开放"
                echo "    UFW: TCP $PORT may be blocked" >> "$DIAG_FILE"
            fi
        done
        
        for PORT in "${PORTS_UDP[@]}"; do
            UFW_RULE=$(sudo ufw status | grep "$PORT/udp" | wc -l)
            if [ "$UFW_RULE" -gt 0 ]; then
                echo -e "[${GREEN}✓${NC}] UDP端口 $PORT 在UFW中已开放"
                echo "    UFW: UDP $PORT open" >> "$DIAG_FILE"
            else
                echo -e "[${YELLOW}!${NC}] UDP端口 $PORT 在UFW中可能未开放"
                echo "    UFW: UDP $PORT may be blocked" >> "$DIAG_FILE"
            fi
        done
    else
        echo -e "${YELLOW}UFW未安装${NC}"
    fi
    
    if command -v iptables &> /dev/null; then
        echo -e "\n${CYAN}IPTables规则:${NC}"
        sudo iptables -L -n | grep -E "ACCEPT|DROP|REJECT"
    fi
else
    echo -e "${YELLOW}无sudo权限，无法检查防火墙规则${NC}"
    echo "No sudo permission to check firewall" >> "$DIAG_FILE"
fi

# 检查Docker服务
print_section "Docker服务检查"
echo -e "${CYAN}Docker状态:${NC}"

if command -v docker &> /dev/null; then
    DOCKER_RUNNING=$(systemctl is-active docker 2>/dev/null || echo "unknown")
    if [ "$DOCKER_RUNNING" = "active" ]; then
        echo -e "[${GREEN}✓${NC}] Docker服务正在运行"
        echo "Docker service is running" >> "$DIAG_FILE"
        
        echo -e "\n${CYAN}运行中的容器:${NC}"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
        
        # 将容器信息保存到诊断文件
        echo -e "\nDocker Containers:" >> "$DIAG_FILE"
        docker ps --format "{{.Names}} - {{.Status}} - {{.Ports}}" >> "$DIAG_FILE"
        
        echo -e "\n${CYAN}检查关键Docker容器:${NC}"
        
        # 检查Marzban容器
        if docker ps 2>/dev/null | grep -q "marzban"; then
            echo -e "[${GREEN}✓${NC}] Marzban容器正在运行"
            echo "Marzban container is running" >> "$DIAG_FILE"
        else
            echo -e "[${RED}✗${NC}] Marzban容器未运行"
            echo "Marzban container is NOT running" >> "$DIAG_FILE"
        fi
        
        # 检查Netmaker容器
        if docker ps 2>/dev/null | grep -q "netmaker"; then
            echo -e "[${GREEN}✓${NC}] Netmaker容器正在运行"
            echo "Netmaker container is running" >> "$DIAG_FILE"
        else
            echo -e "[${RED}✗${NC}] Netmaker容器未运行"
            echo "Netmaker container is NOT running" >> "$DIAG_FILE"
        fi
        
        echo -e "\n${CYAN}检查Docker网络:${NC}"
        docker network ls 2>/dev/null
    else
        echo -e "[${RED}✗${NC}] Docker服务未运行"
        echo "Docker service is NOT running" >> "$DIAG_FILE"
    fi
else
    echo -e "[${RED}✗${NC}] Docker未安装"
    echo "Docker is NOT installed" >> "$DIAG_FILE"
fi

# 检查SSL证书
print_section "SSL证书检查"
echo -e "${CYAN}检查SSL证书状态:${NC}"

check_ssl_cert() {
    local DOMAIN=$1
    local PORT=$2
    local RESULT

    echo -e "\n${CYAN}域名: $DOMAIN:$PORT${NC}"
    
    # 使用openssl检查证书
    RESULT=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:$PORT 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [ -n "$RESULT" ]; then
        NOTBEFORE=$(echo "$RESULT" | grep "notBefore" | cut -d= -f2)
        NOTAFTER=$(echo "$RESULT" | grep "notAfter" | cut -d= -f2)
        
        echo -e "[${GREEN}✓${NC}] SSL证书有效"
        echo -e "    证书生效时间: $NOTBEFORE"
        echo -e "    证书过期时间: $NOTAFTER"
        
        # 检查是否接近过期
        EXPIRE_DATE=$(date -d "${NOTAFTER}" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "${NOTAFTER}" +%s 2>/dev/null)
        CURRENT_DATE=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRE_DATE - $CURRENT_DATE) / 86400 ))
        
        if [ $DAYS_LEFT -lt 30 ]; then
            echo -e "[${YELLOW}!${NC}] 警告: 证书将在 $DAYS_LEFT 天后过期"
        else
            echo -e "[${GREEN}✓${NC}] 证书有效期还有 $DAYS_LEFT 天"
        fi
        
        echo "$DOMAIN:$PORT - Certificate valid, expires in $DAYS_LEFT days" >> "$DIAG_FILE"
    else
        echo -e "[${RED}✗${NC}] 无法获取SSL证书信息"
        echo "$DOMAIN:$PORT - Cannot get certificate info" >> "$DIAG_FILE"
    fi
}

# 检查Marzban面板证书
check_ssl_cert "panel.$DOMAIN" "4443"

# 检查Netmaker控制台证书
check_ssl_cert "netmaker.$DOMAIN" "5443"

# 外部访问测试
print_section "外部连接测试"
echo -e "${CYAN}从服务器测试面板连接:${NC}"

# 测试Marzban面板连接
echo -e "\n${CYAN}测试Marzban面板 (https://panel.$DOMAIN:4443):${NC}"
PANEL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k https://panel.$DOMAIN:4443 2>/dev/null || echo "000")

if [ "$PANEL_STATUS" = "000" ]; then
    echo -e "[${RED}✗${NC}] 无法连接到面板 (无响应)"
    echo "Cannot connect to Marzban panel (no response)" >> "$DIAG_FILE"
elif [ "$PANEL_STATUS" = "200" ] || [ "$PANEL_STATUS" = "302" ] || [ "$PANEL_STATUS" = "301" ]; then
    echo -e "[${GREEN}✓${NC}] 面板连接成功 (HTTP状态码: $PANEL_STATUS)"
    echo "Marzban panel connection successful (HTTP: $PANEL_STATUS)" >> "$DIAG_FILE"
else
    echo -e "[${YELLOW}!${NC}] 面板返回意外状态码: $PANEL_STATUS"
    echo "Marzban panel returned unexpected status code: $PANEL_STATUS" >> "$DIAG_FILE"
fi

# 测试Netmaker控制台连接
echo -e "\n${CYAN}测试Netmaker控制台 (https://netmaker.$DOMAIN:5443):${NC}"
NETMAKER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k https://netmaker.$DOMAIN:5443 2>/dev/null || echo "000")

if [ "$NETMAKER_STATUS" = "000" ]; then
    echo -e "[${RED}✗${NC}] 无法连接到Netmaker控制台 (无响应)"
    echo "Cannot connect to Netmaker console (no response)" >> "$DIAG_FILE"
elif [ "$NETMAKER_STATUS" = "200" ] || [ "$NETMAKER_STATUS" = "302" ] || [ "$NETMAKER_STATUS" = "301" ]; then
    echo -e "[${GREEN}✓${NC}] Netmaker控制台连接成功 (HTTP状态码: $NETMAKER_STATUS)"
    echo "Netmaker console connection successful (HTTP: $NETMAKER_STATUS)" >> "$DIAG_FILE"
else
    echo -e "[${YELLOW}!${NC}] Netmaker控制台返回意外状态码: $NETMAKER_STATUS"
    echo "Netmaker console returned unexpected status code: $NETMAKER_STATUS" >> "$DIAG_FILE"
fi

# 测试Netmaker API连接
echo -e "\n${CYAN}测试Netmaker API (http://localhost:8095):${NC}"
NETMAKER_API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k http://localhost:8095 2>/dev/null || echo "000")

if [ "$NETMAKER_API_STATUS" = "000" ]; then
    echo -e "[${RED}✗${NC}] 无法连接到Netmaker API (无响应)"
    echo "Cannot connect to Netmaker API (no response)" >> "$DIAG_FILE"
else
    echo -e "[${GREEN}✓${NC}] Netmaker API连接成功 (HTTP状态码: $NETMAKER_API_STATUS)"
    echo "Netmaker API connection successful (HTTP: $NETMAKER_API_STATUS)" >> "$DIAG_FILE"
fi

# 检查云服务提供商外部接口是否可访问
print_section "云服务可访问性检查"
echo -e "${CYAN}测试常见云服务接口:${NC}"

# 定义要测试的云服务商API
CLOUD_PROVIDERS=(
    "https://ec2.amazonaws.com:AWS EC2"
    "https://api.linode.com:Linode API"
    "https://api.digitalocean.com:DigitalOcean API"
    "https://api.vultr.com:Vultr API"
    "https://api.cloudflare.com:Cloudflare API"
)

for PROVIDER in "${CLOUD_PROVIDERS[@]}"; do
    API_URL=$(echo $PROVIDER | cut -d: -f1)
    API_NAME=$(echo $PROVIDER | cut -d: -f2)
    
    echo -e "\n${CYAN}测试 $API_NAME 可访问性:${NC}"
    API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -m 10 -k $API_URL 2>/dev/null || echo "000")
    
    if [ "$API_STATUS" = "000" ]; then
        echo -e "[${RED}✗${NC}] 无法连接到 $API_NAME (无响应)"
        echo "Cannot connect to $API_NAME (no response)" >> "$DIAG_FILE"
    elif [ "$API_STATUS" = "200" ] || [ "$API_STATUS" = "401" ] || [ "$API_STATUS" = "403" ]; then
        # 401/403通常表示需要认证，但API是可达的
        echo -e "[${GREEN}✓${NC}] $API_NAME 可访问 (HTTP状态码: $API_STATUS)"
        echo "$API_NAME is accessible (HTTP: $API_STATUS)" >> "$DIAG_FILE"
    else
        echo -e "[${YELLOW}!${NC}] $API_NAME 返回状态码: $API_STATUS"
        echo "$API_NAME returned status code: $API_STATUS" >> "$DIAG_FILE"
    fi
done

# 系统问题自动修复建议
print_section "问题自动诊断与修复建议"
echo -e "${CYAN}根据检测结果，以下是系统问题的修复建议:${NC}"

# 存储问题和建议
ISSUES=0

# DNS问题检查
if [ -z "$IP_PANEL" ] || [ -z "$IP_NETMAKER" ]; then
    ISSUES=$((ISSUES+1))
    echo -e "\n${RED}[$ISSUES] DNS解析问题:${NC}"
    echo -e "  • DNS解析不正确，请确保在DNS提供商处添加以下A记录:"
    echo -e "    - panel.$DOMAIN -> $SERVER_IP"
    echo -e "    - netmaker.$DOMAIN -> $SERVER_IP"
    echo -e "  • 修复命令: 无法自动修复，请手动修改DNS记录"
fi

# 防火墙端口问题
if [ $HAS_SUDO -eq 1 ] && command -v ufw &> /dev/null; then
    FIREWALL_ISSUES=0
    
    for PORT in "${PORTS_TCP[@]}"; do
        UFW_RULE=$(sudo ufw status | grep "$PORT/tcp" | wc -l)
        if [ "$UFW_RULE" -eq 0 ]; then
            FIREWALL_ISSUES=$((FIREWALL_ISSUES+1))
        fi
    done
    
    for PORT in "${PORTS_UDP[@]}"; do
        UFW_RULE=$(sudo ufw status | grep "$PORT/udp" | wc -l)
        if [ "$UFW_RULE" -eq 0 ]; then
            FIREWALL_ISSUES=$((FIREWALL_ISSUES+1))
        fi
    done
    
    if [ $FIREWALL_ISSUES -gt 0 ]; then
        ISSUES=$((ISSUES+1))
        echo -e "\n${RED}[$ISSUES] 防火墙端口问题:${NC}"
        echo -e "  • UFW防火墙可能阻止了必要端口"
        echo -e "  • 修复命令:"
        echo -e "    sudo ufw allow 4443/tcp  # Marzban HTTPS"
        echo -e "    sudo ufw allow 8080/tcp  # Marzban HTTP"
        echo -e "    sudo ufw allow 5443/tcp  # Netmaker HTTPS"
        echo -e "    sudo ufw allow 8095/tcp  # Netmaker API"
        echo -e "    sudo ufw allow 8884/tcp  # Netmaker MQTT"
        echo -e "    sudo ufw allow 3485/udp  # Netmaker STUN"
        echo -e "    sudo ufw allow 51821/udp # WireGuard"
    fi
fi

# Docker服务问题
if command -v docker &> /dev/null; then
    DOCKER_RUNNING=$(systemctl is-active docker 2>/dev/null || echo "unknown")
    if [ "$DOCKER_RUNNING" != "active" ]; then
        ISSUES=$((ISSUES+1))
        echo -e "\n${RED}[$ISSUES] Docker服务问题:${NC}"
        echo -e "  • Docker服务未运行"
        echo -e "  • 修复命令:"
        echo -e "    sudo systemctl start docker"
        echo -e "    sudo systemctl enable docker"
    fi
fi

# 端口监听问题
PORTS_ISSUES=0
for PORT in "${PORTS_TCP[@]}"; do
    if [ $HAS_SUDO -eq 1 ]; then
        LISTENING=$(sudo ss -tlnp | grep ":$PORT " | wc -l)
    else
        LISTENING=$(ss -tlnp 2>/dev/null | grep ":$PORT " | wc -l)
    fi
    
    if [ "$LISTENING" -eq 0 ]; then
        PORTS_ISSUES=$((PORTS_ISSUES+1))
    fi
done

for PORT in "${PORTS_UDP[@]}"; do
    if [ $HAS_SUDO -eq 1 ]; then
        LISTENING=$(sudo ss -ulnp | grep ":$PORT " | wc -l)
    else
        LISTENING=$(ss -ulnp 2>/dev/null | grep ":$PORT " | wc -l)
    fi
    
    if [ "$LISTENING" -eq 0 ]; then
        PORTS_ISSUES=$((PORTS_ISSUES+1))
    fi
done

if [ $PORTS_ISSUES -gt 0 ]; then
    ISSUES=$((ISSUES+1))
    echo -e "\n${RED}[$ISSUES] 端口监听问题:${NC}"
    echo -e "  • 一些必要的端口未在监听"
    echo -e "  • 修复建议:"
    echo -e "    - 重启Docker服务: sudo systemctl restart docker"
    echo -e "    - 重启容器:"
    echo -e "      cd ~/vvvvvv/marzban && docker-compose down && docker-compose up -d"
    echo -e "      cd ~/vvvvvv/netmaker && docker-compose down && docker-compose up -d"
fi

# 面板连接问题
if [ "$PANEL_STATUS" = "000" ] || [ "$NETMAKER_STATUS" = "000" ]; then
    ISSUES=$((ISSUES+1))
    echo -e "\n${RED}[$ISSUES] 面板连接问题:${NC}"
    echo -e "  • 无法连接到Web面板"
    echo -e "  • 修复建议:"
    echo -e "    - 检查面板配置和证书:"
    echo -e "      cd ~/vvvvvv"
    echo -e "      bash install.sh"
    echo -e "    - 或尝试清理后重新安装:"
    echo -e "      cd ~/vvvvvv && ./install.sh --clean"
fi

# 如果没有发现问题
if [ $ISSUES -eq 0 ]; then
    echo -e "\n${GREEN}[✓] 未发现明显问题${NC}"
    echo -e "  • 所有基本系统功能看起来正常"
    echo -e "  • 如仍有访问问题，建议检查:"
    echo -e "    - 互联网服务提供商(ISP)是否屏蔽了相关端口"
    echo -e "    - 检查云服务提供商的网络安全组/防火墙设置"
    echo -e "    - 尝试清理浏览器缓存或使用不同浏览器"
    echo -e "    - 尝试从不同的网络访问服务"
fi

echo -e "\n${PURPLE}诊断报告已保存至: ${DIAG_FILE}${NC}"
echo -e "${CYAN}如需更全面的诊断，请在问题解决后重新运行此脚本${NC}"

# 结束脚本
print_section "诊断完成"
echo -e "${GREEN}VPS系统诊断已完成${NC}"
echo -e "如有问题，请将 ${DIAG_FILE} 文件提供给技术支持人员"
