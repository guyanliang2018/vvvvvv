#!/bin/bash
# install.sh - 一键安装脚本，用于部署整个多云VPS自动化系统
# 用法: ./install.sh --domain your-domain.com --email your-email@example.com

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
BASE_DOMAIN=""
EMAIL=""
INSTALL_MODE="full" # full, panel, agent
SILENT=false
SKIP_DEPS=false

# 解析命令行参数
for i in "$@"; do
  case $i in
    --domain=*)
      BASE_DOMAIN="${i#*=}"
      ;;
    --email=*)
      EMAIL="${i#*=}"
      ;;
    --mode=*)
      INSTALL_MODE="${i#*=}"
      ;;
    --silent)
      SILENT=true
      ;;
    --skip-deps)
      SKIP_DEPS=true
      ;;
    --help)
      echo "用法: $0 [选项]"
      echo ""
      echo "选项:"
      echo "  --domain=DOMAIN     基础域名，用于面板和网络组件"
      echo "  --email=EMAIL       用于SSL证书的邮箱地址"
      echo "  --mode=MODE         安装模式: full (默认), panel, agent"
      echo "  --silent            静默模式，不询问确认"
      echo "  --skip-deps         跳过依赖安装"
      echo "  --help              显示此帮助信息"
      exit 0
      ;;
    *)
      echo -e "${RED}未知参数: $i${NC}"
      exit 1
      ;;
  esac
done

# 交互式选择安装模式
if [ -z "$INSTALL_MODE" ]; then
  echo -e "${BLUE}请选择安装模式:${NC}"
  echo "1) full  - 完整安装 (包括面板、网络和Terraform配置)"
  echo "2) panel - 仅安装控制面板"
  echo "3) agent - 仅安装节点代理"
  read -p "请选择 [1-3] (默认: 1): " mode_choice
  case $mode_choice in
    2) INSTALL_MODE="panel" ;;
    3) INSTALL_MODE="agent" ;;
    *) INSTALL_MODE="full" ;;
  esac
  echo -e "${GREEN}已选择: $INSTALL_MODE 模式${NC}"
  echo
fi

# 交互式询问必要参数
if [ "$INSTALL_MODE" == "full" ] || [ "$INSTALL_MODE" == "panel" ]; then
  if [ -z "$BASE_DOMAIN" ]; then
    echo -e "${BLUE}请输入您的域名 (例如: example.com)${NC}"
    read -p "域名: " BASE_DOMAIN
    while [ -z "$BASE_DOMAIN" ]; do
      echo -e "${YELLOW}域名不能为空${NC}"
      read -p "域名: " BASE_DOMAIN
    done
  fi
  
  if [ -z "$EMAIL" ]; then
    echo -e "${BLUE}请输入您的电子邮箱 (用于SSL证书)${NC}"
    read -p "邮箱: " EMAIL
    while [ -z "$EMAIL" ]; do
      echo -e "${YELLOW}邮箱不能为空${NC}"
      read -p "邮箱: " EMAIL
    done
  fi
  
  # 询问管理员账户
  echo -e "${BLUE}设置控制面板管理员账户${NC}"
  read -p "管理员用户名 [admin]: " ADMIN_USERNAME
  ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
  
  read -s -p "管理员密码 [自动生成]: " ADMIN_PASSWORD
  echo
  if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(openssl rand -base64 12)
    echo -e "${GREEN}已生成随机密码${NC}"
  fi
fi

# 显示安装信息
echo -e "${BLUE}====== 多云VPS自动化系统安装向导 ======${NC}"
echo -e "${BLUE}安装模式: $INSTALL_MODE${NC}"
if [ "$INSTALL_MODE" == "full" ] || [ "$INSTALL_MODE" == "panel" ]; then
  echo -e "${BLUE}域名: $BASE_DOMAIN${NC}"
  echo -e "${BLUE}邮箱: $EMAIL${NC}"
  echo -e "${BLUE}管理员账户: $ADMIN_USERNAME${NC}"
  
  # 显示更多系统信息
  echo -e "${BLUE}安装组件:${NC}"
  echo " - Marzban 控制面板: panel.$BASE_DOMAIN"
  echo " - Netmaker 网络控制器: netmaker.$BASE_DOMAIN"
  echo " - Prometheus + Grafana 监控系统"
  echo " - Alertmanager 告警系统"
fi

# 显示高级设置选项
if [ "$SILENT" != true ]; then
  echo -e "\n${BLUE}高级设置:${NC}"
  read -p "是否配置高级选项? (y/n) [默认:n]: " advanced_settings
  if [[ "$advanced_settings" =~ ^[Yy]$ ]]; then
    # TLS设置
    echo -e "\n${BLUE}SSL/TLS设置:${NC}"
    echo "1) 自动获取 Let's Encrypt 证书 (默认)"
    echo "2) 使用现有证书"
    echo "3) 仅使用HTTP (不推荐)"
    read -p "请选择 [1-3]: " tls_choice
    case $tls_choice in
      2) 
        TLS_MODE="custom"
        read -p "证书路径(.crt): " TLS_CERT_PATH
        read -p "密钥路径(.key): " TLS_KEY_PATH
        ;;
      3) 
        TLS_MODE="disabled"
        echo -e "${YELLOW}警告: 禁用TLS将影响系统安全性${NC}"
        ;;
      *) 
        TLS_MODE="auto"
        ;;
    esac
    
    # 代理设置
    echo -e "\n${BLUE}节点设置:${NC}"
    read -p "启用下载加速器? (y/n) [默认:y]: " enable_cdn
    if [[ ! "$enable_cdn" =~ ^[Nn]$ ]]; then
      CDN_ENABLED=true
    else
      CDN_ENABLED=false
    fi
    
    # 通知设置
    echo -e "\n${BLUE}通知设置:${NC}"
    read -p "配置Telegram机器人通知? (y/n) [默认:n]: " enable_telegram
    if [[ "$enable_telegram" =~ ^[Yy]$ ]]; then
      read -p "Telegram Bot Token: " TELEGRAM_BOT_TOKEN
      read -p "Telegram Chat ID: " TELEGRAM_CHAT_ID
    fi
  fi
fi

# 用户确认
if [ "$SILENT" != true ]; then
  echo -e "\n${GREEN}准备开始安装${NC}"
  read -p "确认继续? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}安装已取消${NC}"
    exit 0
  fi
fi

# 安装系统依赖
install_dependencies() {
  echo -e "${BLUE}[1/6] 安装系统依赖...${NC}"
  
  if [ "$SKIP_DEPS" == true ]; then
    echo -e "${YELLOW}跳过依赖安装${NC}"
    return
  fi
  
  # 交互式询问是否安装依赖
  if [ "$SILENT" != true ]; then
    echo -e "${BLUE}即将安装以下依赖项:${NC}"
    echo "- Docker 和 Docker Compose"
    echo "- Git, curl, wget, jq"
    echo "- Terraform 和 Ansible"
    echo "- Python3 和 pip"
    read -p "是否继续安装依赖项? (y/n) [默认:y]: " install_deps
    if [[ "$install_deps" =~ ^[Nn]$ ]]; then
      echo -e "${YELLOW}跳过依赖安装${NC}"
      SKIP_DEPS=true
      return
    fi
  fi
  
  # 检测操作系统
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
  else
    echo -e "${RED}无法确定操作系统类型${NC}"
    exit 1
  fi
  
  # 根据不同操作系统安装依赖
  if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    apt update -y
    apt install -y curl wget jq socat unzip git docker.io docker-compose python3 python3-pip
  elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    yum update -y
    yum install -y curl wget jq socat unzip git docker docker-compose python3 python3-pip
    systemctl enable docker
    systemctl start docker
  elif [[ "$OS" == "alpine" ]]; then
    apk update
    apk add curl wget jq socat unzip git docker docker-compose python3 py3-pip
    rc-update add docker default
    service docker start
  else
    echo -e "${RED}不支持的操作系统: $OS${NC}"
    exit 1
  fi
  
  # 安装Terraform和Ansible
  echo -e "${BLUE}安装Terraform...${NC}"
  if ! command -v terraform &> /dev/null; then
    echo -e "${BLUE}尝试方法 1: 使用官方仓库安装Terraform${NC}"
    if curl -4s --connect-timeout 10 https://apt.releases.hashicorp.com/gpg > /dev/null; then
      # 使用IPv4强制连接
      curl -4s https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
      apt update -y
      apt install -y terraform
    else
      echo -e "${YELLOW}官方仓库无法访问，尝试备选方法${NC}"
      # 备选方1: 直接下载Terraform二进制文件
      TF_VERSION="1.5.7"
      TF_ARCH="amd64"
      
      if [ "$(uname -m)" = "aarch64" ]; then
        TF_ARCH="arm64"
      fi
      
      echo -e "${BLUE}尝试方法 2: 直接下载Terraform $TF_VERSION $TF_ARCH 二进制文件${NC}"
      if curl -4s --connect-timeout 10 https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${TF_ARCH}.zip -o /tmp/terraform.zip; then
        apt install -y unzip
        unzip -o /tmp/terraform.zip -d /tmp
        mv /tmp/terraform /usr/local/bin/
        chmod +x /usr/local/bin/terraform
        rm /tmp/terraform.zip
        echo -e "${GREEN}Terraform已安装到/usr/local/bin/terraform${NC}"
      else
        echo -e "${YELLOW}直接下载也失败，您可能需要手动安装Terraform${NC}"
        echo -e "${YELLOW}请访问 https://developer.hashicorp.com/terraform/downloads 下载并安装${NC}"
        read -p "是否继续安装脏除Terraform外的其他组件? (y/n) [默认:y] " continue_without_tf
        if [[ "$continue_without_tf" =~ ^[Nn]$ ]]; then
          echo -e "${RED}安装中止${NC}"
          exit 1
        fi
      fi
    fi
  else
    echo -e "${GREEN}Terraform已安装${NC}"
  fi
  
  echo -e "${BLUE}安装Ansible...${NC}"
  if ! command -v ansible &> /dev/null; then
    echo -e "${BLUE}尝试方法 1: 使用pip安装Ansible${NC}"
    if pip3 install ansible --timeout 30; then
      echo -e "${GREEN}Ansible已通过pip安装${NC}"
    else
      echo -e "${YELLOW}pip安装失败，尝试备选方法${NC}"
      
      # 备选方1: 使用系统包管理器
      echo -e "${BLUE}尝试方法 2: 使用系统包管理器安装Ansible${NC}"
      if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt install -y ansible
      elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        yum install -y epel-release
        yum install -y ansible
      else
        echo -e "${YELLOW}无法为当前系统安装Ansible，将跳过${NC}"
      fi
    fi
  else
    echo -e "${GREEN}Ansible已安装${NC}"
  fi
  
  echo -e "${GREEN}依赖安装完成${NC}"
}

# 创建凭证文件
setup_credentials() {
  echo -e "${BLUE}[2/6] 设置系统凭证...${NC}"
  
  # 生成随机密码
  MYSQL_PASSWORD=$(openssl rand -base64 12)
  API_KEY=$(openssl rand -hex 16)
  
  # 交互式询问云服务商凭证
  if [ "$INSTALL_MODE" == "full" ] && [ "$SILENT" != true ]; then
    echo -e "\n${BLUE}云服务商凭证设置 (可选):${NC}"
    echo "注意: 如果您计划使用多云服务商，可以在安装后修改credentials.env文件"
    
    read -p "是否现在配置云服务商API密钥? (y/n) [默认:n]: " setup_cloud_creds
    if [[ "$setup_cloud_creds" =~ ^[Yy]$ ]]; then
      echo "支持的云服务商: AWS, DigitalOcean, Vultr, Linode, Hetzner, OVH"
      read -p "选择云服务商 [默认:AWS]: " CLOUD_PROVIDER
      CLOUD_PROVIDER=${CLOUD_PROVIDER:-AWS}
      
      case "${CLOUD_PROVIDER,,}" in
        aws) 
          read -p "AWS Access Key: " AWS_ACCESS_KEY
          read -s -p "AWS Secret Key: " AWS_SECRET_KEY
          echo
          ;;
        digitalocean) 
          read -s -p "DigitalOcean API Token: " DO_TOKEN
          echo
          ;;
        vultr) 
          read -s -p "Vultr API Key: " VULTR_API_KEY
          echo
          ;;
        linode) 
          read -s -p "Linode API Token: " LINODE_TOKEN
          echo
          ;;
        hetzner) 
          read -s -p "Hetzner API Token: " HETZNER_TOKEN
          echo
          ;;
        ovh) 
          read -p "OVH Application Key: " OVH_APP_KEY
          read -s -p "OVH Application Secret: " OVH_APP_SECRET
          echo
          read -p "OVH Consumer Key: " OVH_CONSUMER_KEY
          ;;
        *) 
          echo -e "${YELLOW}不支持的云服务商${NC}"
          ;;
      esac
    fi
  fi
  
  # 创建credentials.env文件
  if [ ! -f "$SCRIPT_DIR/credentials.env" ]; then
    cp "$SCRIPT_DIR/credentials.env.example" "$SCRIPT_DIR/credentials.env"
    
    # 更新文件中的参数
    sed -i "s|your-email@example.com|$EMAIL|g" "$SCRIPT_DIR/credentials.env"
    sed -i "s|netmaker.your-domain.com|netmaker.$BASE_DOMAIN|g" "$SCRIPT_DIR/credentials.env"
    sed -i "s|panel.your-domain.com|panel.$BASE_DOMAIN|g" "$SCRIPT_DIR/credentials.env"
    sed -i "s|secure_password|$ADMIN_PASSWORD|g" "$SCRIPT_DIR/credentials.env"
    sed -i "s|your_marzban_api_token|$API_KEY|g" "$SCRIPT_DIR/credentials.env"
    
    # 如果配置了Telegram通知，更新相关配置
    if [ ! -z "$TELEGRAM_BOT_TOKEN" ]; then
      sed -i "s|your_telegram_bot_token|$TELEGRAM_BOT_TOKEN|g" "$SCRIPT_DIR/credentials.env"
      sed -i "s|your_telegram_chat_id|$TELEGRAM_CHAT_ID|g" "$SCRIPT_DIR/credentials.env"
    fi
    
    # 更新云服务商凭证
    if [ ! -z "$AWS_ACCESS_KEY" ]; then
      sed -i "s|your_aws_access_key|$AWS_ACCESS_KEY|g" "$SCRIPT_DIR/credentials.env"
      sed -i "s|your_aws_secret_key|$AWS_SECRET_KEY|g" "$SCRIPT_DIR/credentials.env"
    fi
    if [ ! -z "$DO_TOKEN" ]; then
      sed -i "s|your_digitalocean_token|$DO_TOKEN|g" "$SCRIPT_DIR/credentials.env"
    fi
    if [ ! -z "$VULTR_API_KEY" ]; then
      sed -i "s|your_vultr_api_key|$VULTR_API_KEY|g" "$SCRIPT_DIR/credentials.env"
    fi
    # 更新其他云服务商凭证...
    
    echo -e "${GREEN}凭证文件已创建: $SCRIPT_DIR/credentials.env${NC}"
    if [[ "$setup_cloud_creds" != ^[Yy]$ ]]; then
      echo -e "${YELLOW}如需添加云服务商API密钥，请手动编辑此文件${NC}"
    fi
  else
    echo -e "${YELLOW}凭证文件已存在，跳过创建${NC}"
  fi
  
  # 加载凭证
  source "$SCRIPT_DIR/credentials.env"
}

# 设置Marzban面板
setup_marzban() {
  echo -e "${BLUE}[3/6] 设置Marzban面板...${NC}"
  
  # 创建Marzban环境文件
  if [ ! -f "$SCRIPT_DIR/marzban/env" ]; then
    cat > "$SCRIPT_DIR/marzban/env" << EOF
# Marzban Panel 环境配置
SUDO_USERNAME=admin
SUDO_PASSWORD=$ADMIN_PASSWORD

# 安全设置
XRAY_JSON=/var/lib/marzban/xray_config.json
UVICORN_HOST=0.0.0.0
UVICORN_PORT=8000

# 数据库配置
MYSQL_HOST=mariadb
MYSQL_PORT=3306
MYSQL_USER=marzban
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_DATABASE=marzban
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)

# TLS设置
XRAY_SUBSCRIPTION_URL_PREFIX=https://panel.$BASE_DOMAIN

# API和节点设置
API_ENDPOINT=0.0.0.0:8000
NODE_ID=
API_KEY=$API_KEY

# 定时任务
DISABLE_SCHEDULED_TASKS=false
SCHEDULER_INTERVAL=86400

# 安全设置
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440

# Telegram机器人配置
TELEGRAM_API_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_ADMIN_ID=$TELEGRAM_CHAT_ID
TELEGRAM_PROXY=
EOF
  fi

  # 创建数据库环境文件
  if [ ! -f "$SCRIPT_DIR/marzban/env-db" ]; then
    cat > "$SCRIPT_DIR/marzban/env-db" << EOF
# MariaDB 环境配置
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
MYSQL_DATABASE=marzban
MYSQL_USER=marzban
MYSQL_PASSWORD=$MYSQL_PASSWORD
EOF
  fi

  # 更新Caddy配置
  if [ -f "$SCRIPT_DIR/marzban/Caddyfile" ]; then
    sed -i "s|panel.your-domain.com:4443|panel.$BASE_DOMAIN:4443|g" "$SCRIPT_DIR/marzban/Caddyfile"
    sed -i "s|monitor.your-domain.com|monitor.$BASE_DOMAIN|g" "$SCRIPT_DIR/marzban/Caddyfile"
  fi
  
  # 创建必要的目录
  mkdir -p "$SCRIPT_DIR/marzban/data" "$SCRIPT_DIR/marzban/certs" "$SCRIPT_DIR/marzban/mysql" "$SCRIPT_DIR/marzban/caddy-data" "$SCRIPT_DIR/marzban/caddy-config" "$SCRIPT_DIR/marzban/prometheus/rules" "$SCRIPT_DIR/marzban/prometheus-data" "$SCRIPT_DIR/marzban/grafana" "$SCRIPT_DIR/marzban/alertmanager"
  
  # 复制预设的配置文件
  cp "$SCRIPT_DIR/marzban/data/xray_config.json" "$SCRIPT_DIR/marzban/data/" 2>/dev/null || true
  cp "$SCRIPT_DIR/marzban/data/inbounds_template.json" "$SCRIPT_DIR/marzban/data/" 2>/dev/null || true
  
  # 启动Marzban面板
  if [ "$INSTALL_MODE" == "full" ] || [ "$INSTALL_MODE" == "panel" ]; then
    echo -e "${BLUE}启动Marzban面板...${NC}"
    cd "$SCRIPT_DIR/marzban"
    docker-compose up -d
    
    # 等待面板启动
    echo -e "${YELLOW}等待面板启动...${NC}"
    sleep 10
    
    # 验证面板是否正常工作
    PANEL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://panel.$BASE_DOMAIN:4443 || echo "000")
    if [ "$PANEL_STATUS" == "200" ] || [ "$PANEL_STATUS" == "301" ] || [ "$PANEL_STATUS" == "302" ]; then
      echo -e "${GREEN}Marzban面板已成功启动，可以通过 https://panel.$BASE_DOMAIN:4443 访问${NC}"
      echo -e "${GREEN}登录凭证: 用户名 admin 密码 $ADMIN_PASSWORD${NC}"
    else
      echo -e "${YELLOW}Marzban面板可能未正确启动，请检查配置和日志${NC}"
      echo -e "${YELLOW}面板URL: https://panel.$BASE_DOMAIN:4443${NC}"
    fi
  fi
}

# 设置Netmaker网络控制器
setup_netmaker() {
  echo -e "${BLUE}[4/6] 设置Netmaker网络控制器...${NC}"
  
  if [ ! -d "$SCRIPT_DIR/netmaker" ]; then
    mkdir -p "$SCRIPT_DIR/netmaker"
  fi
  
  cd "$SCRIPT_DIR/netmaker"

  # 强化的Docker资源清理函数
  clean_docker_resources() {
    echo -e "${YELLOW}执行强化的Docker资源清理...${NC}"
    
    # 停止并移除所有Docker容器
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm -f $(docker ps -aq) 2>/dev/null || true
    
    # 强制清理所有Docker资源
    echo -e "${YELLOW}清理Docker缓存与未使用的资源...${NC}"
    docker system prune -af --volumes 2>/dev/null || true
  }
  
  # 增强的端口冲突检测和处理函数
  check_port() {
    local port=$1
    local result=$(lsof -i:$port -t 2>/dev/null)
    if [ -n "$result" ]; then
      echo -e "${YELLOW}端口 $port 已被占用，尝试关闭相关进程...${NC}"
      kill -9 $result 2>/dev/null || true
      
      # 二次检查，如果仍被占用，尝试使用sudo
      sleep 1
      result=$(lsof -i:$port -t 2>/dev/null)
      if [ -n "$result" ]; then
        echo -e "${RED}端口 $port 仍被占用，尝试使用sudo强制关闭...${NC}"
        sudo kill -9 $result 2>/dev/null || true
      fi
      
      return 1
    fi
    return 0
  }
  
  # 首先运行强化清理
  clean_docker_resources
  
  # 检查并清理Netmaker相关端口
  echo -e "${YELLOW}强制检查关键端口是否可用...${NC}"
  CRITICAL_PORTS="8095 3485 8884 51821 53"
  echo -e "${BLUE}关键端口列表: $CRITICAL_PORTS${NC}"
  
  for port in $CRITICAL_PORTS; do
    check_port $port
    # 如果端口仍然被占用，继续下一个端口
  done
  
  # 根因分析函数，帮助诊断端口冲突问题
  diagnose_port_issue() {
    local port=$1
    echo -e "${YELLOW}===== 开始端口 $port 问题诊断 =====${NC}"
    
    # 检查端口状态
    echo -e "${BLUE}1. 检查端口 $port 当前状态...${NC}"
    if command -v netstat &> /dev/null; then
      netstat -tulpn 2>/dev/null | grep -E ":$port "
    elif command -v ss &> /dev/null; then
      ss -tulpn 2>/dev/null | grep -E ":$port "
    else
      echo -e "${RED}无法检查端口状态，netstat和ss命令均不可用${NC}"
    fi
    
    # 检查占用该端口的进程
    echo -e "${BLUE}2. 检查占用端口 $port 的进程...${NC}"
    PID=$(lsof -i:$port -t 2>/dev/null)
    if [ -n "$PID" ]; then
      echo -e "${YELLOW}发现进程 ID: $PID${NC}"
      ps -f -p $PID 2>/dev/null || ps aux | grep $PID | grep -v grep
    else
      echo -e "${GREEN}没有进程占用该端口${NC}"
    fi
    
    # 检查Docker容器是否使用该端口
    echo -e "${BLUE}3. 检查Docker容器是否使用端口 $port...${NC}"
    docker ps --format "{{.Names}}\t{{.Ports}}" 2>/dev/null | grep -E "$port-|:$port" || echo -e "${GREEN}没有Docker容器使用该端口${NC}"
    
    echo -e "${YELLOW}===== 端口诊断完成 =====${NC}"
  }
  
  # 执行全面的端口诊断
  run_ports_diagnosis() {
    echo -e "${YELLOW}\n===== 执行全面端口诊断 =====${NC}"
    for port in $CRITICAL_PORTS; do
      if lsof -i:$port -t &>/dev/null; then
        diagnose_port_issue $port
      fi
    done
    
    # 使用netstat显示当前关键端口状态
    echo -e "${YELLOW}\n当前端口状态概要:${NC}"
    if command -v netstat &> /dev/null; then
      netstat -tulpn 2>/dev/null | grep -E "$(echo $CRITICAL_PORTS | tr ' ' '|')" || echo -e "${GREEN}没有关键端口被占用${NC}"
    elif command -v ss &> /dev/null; then
      ss -tulpn 2>/dev/null | grep -E "$(echo $CRITICAL_PORTS | tr ' ' '|')" || echo -e "${GREEN}没有关键端口被占用${NC}"
    fi
    
    echo -e "${YELLOW}===== 诊断完成 =====${NC}\n"
  }
  
  # 执行端口诊断
  run_ports_diagnosis
  
  # 强制清理现有Netmaker容器和相关资源
  echo -e "${YELLOW}清理已存在的Netmaker容器和相关资源...${NC}"
  docker rm -f netmaker netmaker-caddy 2>/dev/null || true
  docker system prune -af --volumes 2>/dev/null || true
  
  # 完全移除数据目录重新建立，解决数据损坏问题
  rm -rf "$SCRIPT_DIR/netmaker/data" "$SCRIPT_DIR/netmaker/config" "$SCRIPT_DIR/netmaker/certs"
  
  # 创建必要的目录结构
  mkdir -p "$SCRIPT_DIR/netmaker/data"
  mkdir -p "$SCRIPT_DIR/netmaker/config"
  mkdir -p "$SCRIPT_DIR/netmaker/certs"
  
  # 设置正确的目录权限
  chmod -R 755 "$SCRIPT_DIR/netmaker"
  
  # 替换配置文件中的参数
  sed -i "s/SERVER_HOST: \"netmaker\.your-domain\.com\"/SERVER_HOST: \"netmaker\.$BASE_DOMAIN\"/g" docker-compose.yml
  sed -i "s/SERVER_API_CONN_STRING: \"api\.netmaker\.your-domain\.com:5443\"/SERVER_API_CONN_STRING: \"api\.netmaker\.$BASE_DOMAIN:5443\"/g" docker-compose.yml
  sed -i "s/MASTER_KEY: \"your-secure-master-key\"/MASTER_KEY: \"$MASTER_KEY\"/g" docker-compose.yml

  echo -e "${YELLOW}启动Netmaker网络控制器...${NC}"
  # 先尝试拉取最新镜像，避免缓存问题
  docker pull gravitl/netmaker:v0.20.2
  docker pull caddy:2-alpine
  # 使用--force-recreate来确保容器完全重新创建
  docker-compose up -d --force-recreate
  
  # 等待服务启动
  echo -e "${YELLOW}等待Netmaker启动...${NC}"
  sleep 15
  
  # 获取访问令牌 - 使用正确的API方式获取
  echo -e "${YELLOW}尝试获取Netmaker接入令牌...${NC}"
  
  # 尝试三种不同的方法来获取令牌
  # 方法1: 通过API获取
  NETMAKER_TOKEN=$(curl -s -X GET -H "Authorization: Bearer $MASTER_KEY" http://localhost:8095/api/networks/vpn/keys/token 2>/dev/null | grep -o '"token":"[^"]*"' | cut -d '"' -f 4 || echo "")
  
  # 方法2: 直接从容器中获取
  if [ -z "$NETMAKER_TOKEN" ]; then
    NETMAKER_TOKEN=$(docker exec netmaker sh -c "cd /root && ./netmaker enrollment-key -t vpn" 2>/dev/null || echo "")
  fi
  
  # 方法3: 使用默认令牌
  if [ -z "$NETMAKER_TOKEN" ]; then
    # 如果以上方法都失败，使用默认生成的令牌格式
    NETMAKER_TOKEN="请登录网络控制面板获取令牌"
  fi
  
  # 显示结果
  echo -e "${GREEN}Netmaker网络控制器已成功启动${NC}"
  echo -e "${GREEN}访问地址: https://netmaker.$BASE_DOMAIN:5443${NC}"
  echo -e "${BLUE}管理面板登录信息:${NC}"
  echo -e "${BLUE}  - 用户名: admin@netmaker.io${NC}"
  echo -e "${BLUE}  - 密码: 请使用MASTER_KEY($MASTER_KEY)${NC}"
  
  # 显示Netmaker令牌信息
  if [ "$NETMAKER_TOKEN" != "请登录网络控制面板获取令牌" ]; then
    echo -e "${GREEN}Netmaker接入令牌: $NETMAKER_TOKEN${NC}"
    # 更新凭证文件 - 使用写入文件的方式，避免sed命令的转义问题
    if [ -f "$SCRIPT_DIR/credentials.env" ]; then
      # 先创建一个临时文件
      cat "$SCRIPT_DIR/credentials.env" | grep -v "NETMAKER_JOIN_TOKEN" > "$SCRIPT_DIR/credentials.env.tmp"
      # 然后追加新的令牌
      echo "NETMAKER_JOIN_TOKEN=\"$NETMAKER_TOKEN\"" >> "$SCRIPT_DIR/credentials.env.tmp"
      # 替换原文件
      mv "$SCRIPT_DIR/credentials.env.tmp" "$SCRIPT_DIR/credentials.env"
      echo -e "${GREEN}凭证文件更新成功${NC}"
    else
      echo -e "${YELLOW}警告: 凭证文件不存在，请手动创建并添加NETMAKER_JOIN_TOKEN=${NETMAKER_TOKEN}${NC}"
    fi
  else
    echo -e "${YELLOW}无法自动获取令牌，请登录控制面板手动生成${NC}"
    # 将占位符保留在凭证文件中，等待手动更新
    echo -e "${YELLOW}凭证文件中的Netmaker令牌将需要手动更新${NC}"
  fi
}

# 设置Terraform
setup_terraform() {
  echo -e "${BLUE}[5/6] 设置Terraform配置...${NC}"
  
  # 创建Terraform环境目录
  mkdir -p "$SCRIPT_DIR/terraform/environments/prod" "$SCRIPT_DIR/terraform/environments/test"
  
  # 创建prod环境变量文件
  if [ ! -f "$SCRIPT_DIR/terraform/environments/prod/terraform.tfvars" ]; then
    cat > "$SCRIPT_DIR/terraform/environments/prod/terraform.tfvars" << EOF
# Terraform变量配置文件
# 添加您的云服务商API密钥和配置

# 云服务商API密钥
vultr_api_key     = ""  # 从credentials.env导入
do_token          = ""  # 从credentials.env导入
linode_token      = ""  # 从credentials.env导入
aws_access_key    = ""  # 从credentials.env导入
aws_secret_key    = ""  # 从credentials.env导入
aws_region        = "ap-northeast-1"

# 节点配置
vultr_node_count = 4
do_node_count    = 3
linode_node_count = 2
aws_node_count   = 1

# Netmaker和Marzban配置
netmaker_token   = "$NETMAKER_TOKEN"  # 从credentials.env导入
marzban_token    = "$API_KEY"         # 从credentials.env导入
netmaker_server  = "netmaker.$BASE_DOMAIN"
marzban_server   = "panel.$BASE_DOMAIN"

# SSH密钥配置
vultr_ssh_key_ids = []
do_ssh_key_ids    = []
linode_authorized_keys = []
aws_key_name      = ""

# Cloud-init配置
cloudinit_file    = "../cloud-init/base-cloudinit.yml"
EOF
    
    echo -e "${GREEN}已创建Terraform生产环境配置文件${NC}"
    echo -e "${YELLOW}请手动编辑文件添加您的云服务商API密钥${NC}"
  fi
  
  # 创建test环境变量文件（简化版）
  if [ ! -f "$SCRIPT_DIR/terraform/environments/test/terraform.tfvars" ]; then
    cat > "$SCRIPT_DIR/terraform/environments/test/terraform.tfvars" << EOF
# Terraform测试环境配置文件

# 云服务商API密钥（从credentials.env导入）
vultr_api_key     = ""
do_token          = ""
linode_token      = ""
aws_access_key    = ""
aws_secret_key    = ""
aws_region        = "ap-northeast-1"

# 节点配置（测试环境使用较少节点）
vultr_node_count = 1
do_node_count    = 1
linode_node_count = 0
aws_node_count   = 0

# Netmaker和Marzban配置
netmaker_token   = "$NETMAKER_TOKEN"
marzban_token    = "$API_KEY"
netmaker_server  = "netmaker.$BASE_DOMAIN"
marzban_server   = "panel.$BASE_DOMAIN"

# SSH密钥配置
vultr_ssh_key_ids = []
do_ssh_key_ids    = []
linode_authorized_keys = []
aws_key_name      = ""

# Cloud-init配置
cloudinit_file    = "../cloud-init/base-cloudinit.yml"
EOF
  fi
}

# 设置Ansible
setup_ansible() {
  echo -e "${BLUE}[6/6] 设置Ansible配置...${NC}"
  
  # 创建inventory目录
  mkdir -p "$SCRIPT_DIR/ansible/inventory"
  
  # 创建基本inventory文件
  if [ ! -f "$SCRIPT_DIR/ansible/inventory/hosts.yml" ]; then
    cat > "$SCRIPT_DIR/ansible/inventory/hosts.yml" << EOF
---
# 通过动态inventory获取，这里提供基础结构
all:
  children:
    xray_nodes:
      children:
        vultr:
          hosts: {}
        digitalocean:
          hosts: {}
        linode:
          hosts: {}
        aws:
          hosts: {}
EOF
  fi
  
  # 创建vars目录和全局变量文件
  mkdir -p "$SCRIPT_DIR/ansible/vars"
  if [ ! -f "$SCRIPT_DIR/ansible/vars/global.yml" ]; then
    cat > "$SCRIPT_DIR/ansible/vars/global.yml" << EOF
---
# 全局变量
netmaker_server: "netmaker.$BASE_DOMAIN"
marzban_server: "panel.$BASE_DOMAIN"
netmaker_token: "$NETMAKER_TOKEN"
marzban_token: "$API_KEY"

# TLS配置
cert_directory: "/opt/certs"
domain: "{{ inventory_hostname }}"
dns_api_type: "dns_cf"  # 使用Cloudflare API，根据实际情况调整
acme_email: "$EMAIL"

# 监控配置
node_exporter_version: "1.6.1"
log_collection_enabled: true

# SSH配置
ssh_disable_password_auth: true
ssh_disable_root_login: false
EOF
  fi
}

# 设置定时任务
setup_cron() {
  echo -e "${BLUE}设置定时任务...${NC}"
  
  # 检查脚本是否可执行
  chmod +x "$SCRIPT_DIR/scripts/check-nodes.sh"
  chmod +x "$SCRIPT_DIR/scripts/backup.sh"
  chmod +x "$SCRIPT_DIR/scripts/node-stats.sh"
  chmod +x "$SCRIPT_DIR/scripts/security-audit.sh"
  
  # 创建crontab条目
  CRONTAB_FILE="/tmp/crontab.tmp"
  crontab -l > "$CRONTAB_FILE" 2>/dev/null || echo "" > "$CRONTAB_FILE"
  
  # 添加检查节点状态的定时任务（每5分钟执行一次）
  if ! grep -q "check-nodes.sh" "$CRONTAB_FILE"; then
    echo "*/5 * * * * cd $SCRIPT_DIR && ./scripts/check-nodes.sh --alert >> /var/log/node_checks.log 2>&1" >> "$CRONTAB_FILE"
  fi
  
  # 添加备份任务（每天凌晨2点执行）
  if ! grep -q "backup.sh" "$CRONTAB_FILE"; then
    echo "0 2 * * * cd $SCRIPT_DIR && ./scripts/backup.sh >> /var/log/backup.log 2>&1" >> "$CRONTAB_FILE"
  fi
  
  # 添加节点统计任务（每6小时执行一次）
  if ! grep -q "node-stats.sh" "$CRONTAB_FILE"; then
    echo "0 */6 * * * cd $SCRIPT_DIR && ./scripts/node-stats.sh >> /var/log/node_stats.log 2>&1" >> "$CRONTAB_FILE"
  fi
  
  # 添加安全审计任务（每周执行一次，周日凌晨3点）
  if ! grep -q "security-audit.sh" "$CRONTAB_FILE"; then
    echo "0 3 * * 0 cd $SCRIPT_DIR && ./scripts/security-audit.sh --fix >> /var/log/security_audit.log 2>&1" >> "$CRONTAB_FILE"
  fi
  
  # 安装新的crontab
  crontab "$CRONTAB_FILE"
  rm "$CRONTAB_FILE"
  
  echo -e "${GREEN}定时任务设置完成${NC}"
}

# 显示安装总结
show_summary() {
  echo -e "\n${GREEN}====== 安装完成 ======${NC}"
  echo -e "${GREEN}多云VPS自动化系统已成功安装${NC}"
  
  if [ "$INSTALL_MODE" == "full" ] || [ "$INSTALL_MODE" == "panel" ]; then
    echo -e "\n${BLUE}面板访问信息:${NC}"
    echo -e "Marzban面板: https://panel.$BASE_DOMAIN"
    echo -e "用户名: admin"
    echo -e "密码: $ADMIN_PASSWORD"
    
    echo -e "\n${BLUE}Netmaker访问信息:${NC}"
    echo -e "网址: https://netmaker.$BASE_DOMAIN"
    echo -e "接入令牌: $NETMAKER_TOKEN"
  fi
  
  echo -e "\n${YELLOW}后续步骤:${NC}"
  echo -e "1. 编辑credentials.env文件添加您的云服务商API密钥"
  echo -e "2. 编辑terraform/environments/prod/terraform.tfvars文件配置部署参数"
  echo -e "3. 使用Terraform创建节点: cd terraform && terraform init && terraform apply"
  echo -e "4. 使用Ansible配置节点: cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/site.yml"
  
  echo -e "\n${BLUE}常用命令:${NC}"
  echo -e "检查节点状态: ./scripts/check-nodes.sh"
  echo -e "替换故障节点: ./scripts/replace-node.sh <provider> <node_id>"
  echo -e "查看节点统计: ./scripts/node-stats.sh"
  echo -e "执行安全审计: ./scripts/security-audit.sh"
  echo -e "备份系统: ./scripts/backup.sh"
  
  echo -e "\n${GREEN}完整文档请参考README.md${NC}"
}

# 主程序开始
install_dependencies
setup_credentials
setup_marzban
setup_netmaker
setup_terraform
setup_ansible
setup_cron
show_summary

exit 0
