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

# 检查必要参数
if [ "$INSTALL_MODE" == "full" ] || [ "$INSTALL_MODE" == "panel" ]; then
  if [ -z "$BASE_DOMAIN" ]; then
    echo -e "${RED}错误: 必须指定域名 (--domain=your-domain.com)${NC}"
    exit 1
  fi
  
  if [ -z "$EMAIL" ]; then
    echo -e "${RED}错误: 必须指定邮箱 (--email=your-email@example.com)${NC}"
    exit 1
  fi
fi

# 显示安装信息
echo -e "${BLUE}====== 多云VPS自动化系统安装向导 ======${NC}"
echo -e "${BLUE}安装模式: $INSTALL_MODE${NC}"
if [ "$INSTALL_MODE" == "full" ] || [ "$INSTALL_MODE" == "panel" ]; then
  echo -e "${BLUE}域名: $BASE_DOMAIN${NC}"
  echo -e "${BLUE}邮箱: $EMAIL${NC}"
fi

# 用户确认
if [ "$SILENT" != true ]; then
  read -p "继续安装? (y/n) " -n 1 -r
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
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt update -y
    apt install -y terraform
  fi
  
  echo -e "${BLUE}安装Ansible...${NC}"
  pip3 install ansible
  
  echo -e "${GREEN}依赖安装完成${NC}"
}

# 创建凭证文件
setup_credentials() {
  echo -e "${BLUE}[2/6] 设置凭证...${NC}"
  
  # 生成随机密码
  MYSQL_PASSWORD=$(openssl rand -base64 12)
  ADMIN_PASSWORD=$(openssl rand -base64 12)
  API_KEY=$(openssl rand -hex 16)
  
  # 创建credentials.env文件
  if [ ! -f "$SCRIPT_DIR/credentials.env" ]; then
    cp "$SCRIPT_DIR/credentials.env.example" "$SCRIPT_DIR/credentials.env"
    
    # 更新文件中的参数
    sed -i "s|your-email@example.com|$EMAIL|g" "$SCRIPT_DIR/credentials.env"
    sed -i "s|netmaker.your-domain.com|netmaker.$BASE_DOMAIN|g" "$SCRIPT_DIR/credentials.env"
    sed -i "s|panel.your-domain.com|panel.$BASE_DOMAIN|g" "$SCRIPT_DIR/credentials.env"
    sed -i "s|secure_password|$ADMIN_PASSWORD|g" "$SCRIPT_DIR/credentials.env"
    sed -i "s|your_marzban_api_token|$API_KEY|g" "$SCRIPT_DIR/credentials.env"
    
    echo -e "${GREEN}凭证文件已创建: $SCRIPT_DIR/credentials.env${NC}"
    echo -e "${YELLOW}请手动编辑此文件添加您的云服务商API密钥${NC}"
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
    sed -i "s|panel.your-domain.com|panel.$BASE_DOMAIN|g" "$SCRIPT_DIR/marzban/Caddyfile"
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
    PANEL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://panel.$BASE_DOMAIN || echo "000")
    if [ "$PANEL_STATUS" == "200" ] || [ "$PANEL_STATUS" == "301" ] || [ "$PANEL_STATUS" == "302" ]; then
      echo -e "${GREEN}Marzban面板已成功启动，可以通过 https://panel.$BASE_DOMAIN 访问${NC}"
      echo -e "${GREEN}登录凭证: 用户名 admin 密码 $ADMIN_PASSWORD${NC}"
    else
      echo -e "${YELLOW}Marzban面板可能未正确启动，请检查配置和日志${NC}"
      echo -e "${YELLOW}面板URL: https://panel.$BASE_DOMAIN${NC}"
    fi
  fi
}

# 设置Netmaker网络控制器
setup_netmaker() {
  echo -e "${BLUE}[4/6] 设置Netmaker网络控制器...${NC}"
  
  # 创建必要的目录
  mkdir -p "$SCRIPT_DIR/netmaker/data" "$SCRIPT_DIR/netmaker/config" "$SCRIPT_DIR/netmaker/certs" "$SCRIPT_DIR/netmaker/caddy-data" "$SCRIPT_DIR/netmaker/caddy-config"
  
  # 更新Caddy配置
  if [ -f "$SCRIPT_DIR/netmaker/Caddyfile" ]; then
    sed -i "s|netmaker.your-domain.com|netmaker.$BASE_DOMAIN|g" "$SCRIPT_DIR/netmaker/Caddyfile"
    sed -i "s|api.netmaker.your-domain.com|api.netmaker.$BASE_DOMAIN|g" "$SCRIPT_DIR/netmaker/Caddyfile"
  fi
  
  # 更新docker-compose配置
  if [ -f "$SCRIPT_DIR/netmaker/docker-compose.yml" ]; then
    sed -i "s|netmaker.your-domain.com|netmaker.$BASE_DOMAIN|g" "$SCRIPT_DIR/netmaker/docker-compose.yml"
    sed -i "s|api.netmaker.your-domain.com|api.netmaker.$BASE_DOMAIN|g" "$SCRIPT_DIR/netmaker/docker-compose.yml"
    sed -i "s|your-secure-master-key|$(openssl rand -hex 16)|g" "$SCRIPT_DIR/netmaker/docker-compose.yml"
    sed -i "s|user:pass123|admin:$ADMIN_PASSWORD|g" "$SCRIPT_DIR/netmaker/docker-compose.yml"
  fi
  
  # 启动Netmaker
  if [ "$INSTALL_MODE" == "full" ] || [ "$INSTALL_MODE" == "panel" ]; then
    echo -e "${BLUE}启动Netmaker网络控制器...${NC}"
    cd "$SCRIPT_DIR/netmaker"
    docker-compose up -d
    
    # 等待服务启动
    echo -e "${YELLOW}等待Netmaker启动...${NC}"
    sleep 15
    
    # 获取访问令牌
    NETMAKER_TOKEN=$(docker exec netmaker netclient join-token -v 2>/dev/null || echo "无法获取令牌")
    
    if [ "$NETMAKER_TOKEN" != "无法获取令牌" ]; then
      echo -e "${GREEN}Netmaker网络控制器已成功启动${NC}"
      echo -e "${GREEN}访问地址: https://netmaker.$BASE_DOMAIN${NC}"
      echo -e "${GREEN}Netmaker接入令牌: $NETMAKER_TOKEN${NC}"
      
      # 更新凭证文件
      sed -i "s|your_netmaker_join_token|$NETMAKER_TOKEN|g" "$SCRIPT_DIR/credentials.env"
    else
      echo -e "${YELLOW}Netmaker可能未正确启动，请检查配置和日志${NC}"
    fi
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
