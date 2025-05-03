#!/bin/bash
# 继续安装脚本 - 用于手动继续interrupted的install.sh

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

echo -e "${BLUE}===== 继续Marzban安装脚本 =====${NC}"

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载环境变量
if [ -f "$SCRIPT_DIR/.env" ]; then
  echo -e "${GREEN}加载.env文件...${NC}"
  source "$SCRIPT_DIR/.env"
else
  echo -e "${RED}错误：.env文件不存在，需要先运行install.sh${NC}"
  exit 1
fi

# 域名设置
if [ -z "$BASE_DOMAIN" ]; then
  read -p "请输入您的主域名: " BASE_DOMAIN
  echo -e "${GREEN}设置BASE_DOMAIN=$BASE_DOMAIN${NC}"
  echo "BASE_DOMAIN=$BASE_DOMAIN" >> "$SCRIPT_DIR/.env"
fi

# 1. 创建必要的目录
echo -e "${YELLOW}创建必要目录...${NC}"
mkdir -p "$SCRIPT_DIR/marzban/data" "$SCRIPT_DIR/marzban/certs" "$SCRIPT_DIR/marzban/mysql" 
mkdir -p "$SCRIPT_DIR/marzban/caddy-data" "$SCRIPT_DIR/marzban/caddy-config" 
mkdir -p "$SCRIPT_DIR/marzban/prometheus/rules" "$SCRIPT_DIR/marzban/prometheus-data" 
mkdir -p "$SCRIPT_DIR/marzban/grafana" "$SCRIPT_DIR/marzban/alertmanager"

# 2. 创建必要的配置文件
# 2.1 创建xray_config.json文件
if [ ! -f "$SCRIPT_DIR/marzban/data/xray_config.json" ]; then
  echo -e "${YELLOW}创建 Xray 配置文件...${NC}"
  cat > "$SCRIPT_DIR/marzban/data/xray_config.json" << 'EOF'
{
    "log": {
        "loglevel": "warning"
    },
    "api": {
        "tag": "api",
        "services": ["HandlerService", "StatsService"]
    },
    "inbounds": [],
    "outbounds": [
        {
            "tag": "direct",
            "protocol": "freedom",
            "settings": {}
        },
        {
            "tag": "blocked",
            "protocol": "blackhole",
            "settings": {}
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "inboundTag": ["api"],
                "outboundTag": "api"
            }
        ],
        "domainStrategy": "AsIs"
    },
    "policy": {
        "levels": {
            "0": {
                "statsUserUplink": true,
                "statsUserDownlink": true
            }
        },
        "system": {
            "statsInboundUplink": true,
            "statsInboundDownlink": true,
            "statsOutboundUplink": true,
            "statsOutboundDownlink": true
        }
    }
}
EOF
  echo -e "${GREEN}Xray配置文件创建成功${NC}"
fi

# 2.2 创建Prometheus配置文件
if [ ! -f "$SCRIPT_DIR/marzban/prometheus/prometheus.yml" ]; then
  echo -e "${YELLOW}创建 Prometheus 配置文件...${NC}"
  cat > "$SCRIPT_DIR/marzban/prometheus/prometheus.yml" << EOF
global:
  scrape_interval:     15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
  - static_configs:
    - targets:
      - alertmanager:9093

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
EOF
  echo -e "${GREEN}Prometheus配置文件创建成功${NC}"
fi

# 2.3 创建Alertmanager配置文件
if [ ! -f "$SCRIPT_DIR/marzban/alertmanager/config.yml" ]; then
  echo -e "${YELLOW}创建 Alertmanager 配置文件...${NC}"
  cat > "$SCRIPT_DIR/marzban/alertmanager/config.yml" << EOF
route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: 'web.hook'
receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://127.0.0.1:5001/'
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF
  echo -e "${GREEN}Alertmanager配置文件创建成功${NC}"
fi

# 3. 强化目录权限修复
echo -e "${YELLOW}设置正确的目录权限...${NC}"

# 先停止所有容器
cd "$SCRIPT_DIR/marzban"
docker-compose down 2>/dev/null || true

# 设置目录权限 - 使用root权限确保成功
if command -v sudo &> /dev/null; then
  # 如果有sudo权限
  sudo mkdir -p "$SCRIPT_DIR/marzban/grafana"
  sudo mkdir -p "$SCRIPT_DIR/marzban/prometheus" "$SCRIPT_DIR/marzban/prometheus-data"
  sudo mkdir -p "$SCRIPT_DIR/marzban/alertmanager"
  
  # 强化权限设置
  sudo chown -R 472:472 "$SCRIPT_DIR/marzban/grafana" || true # Grafana需要472用户
  sudo chown -R 65534:65534 "$SCRIPT_DIR/marzban/prometheus" || true # Prometheus需要nobody用户
  sudo chown -R 65534:65534 "$SCRIPT_DIR/marzban/prometheus-data" || true
  sudo chown -R 65534:65534 "$SCRIPT_DIR/marzban/alertmanager" || true
  
  # 提供足够的权限
  sudo chmod -R 777 "$SCRIPT_DIR/marzban/grafana"
  sudo chmod -R 777 "$SCRIPT_DIR/marzban/prometheus"
  sudo chmod -R 777 "$SCRIPT_DIR/marzban/prometheus-data"
  sudo chmod -R 777 "$SCRIPT_DIR/marzban/alertmanager"
  
  echo -e "${GREEN}目录权限设置成功${NC}"
else
  # 如果没有sudo，尝试直接设置
  mkdir -p "$SCRIPT_DIR/marzban/grafana"
  mkdir -p "$SCRIPT_DIR/marzban/prometheus" "$SCRIPT_DIR/marzban/prometheus-data"
  mkdir -p "$SCRIPT_DIR/marzban/alertmanager"
  
  # 尝试设置权限
  chown -R 472:472 "$SCRIPT_DIR/marzban/grafana" 2>/dev/null || echo -e "${YELLOW}注意: 无法设置 grafana 目录权限${NC}"
  chown -R 65534:65534 "$SCRIPT_DIR/marzban/prometheus" 2>/dev/null || echo -e "${YELLOW}注意: 无法设置 prometheus 目录权限${NC}"
  chown -R 65534:65534 "$SCRIPT_DIR/marzban/prometheus-data" 2>/dev/null || echo -e "${YELLOW}注意: 无法设置 prometheus-data 目录权限${NC}"
  chown -R 65534:65534 "$SCRIPT_DIR/marzban/alertmanager" 2>/dev/null || echo -e "${YELLOW}注意: 无法设置 alertmanager 目录权限${NC}"
  
  # 提供最大权限
  chmod -R 777 "$SCRIPT_DIR/marzban/grafana" 2>/dev/null || true
  chmod -R 777 "$SCRIPT_DIR/marzban/prometheus" 2>/dev/null || true
  chmod -R 777 "$SCRIPT_DIR/marzban/prometheus-data" 2>/dev/null || true
  chmod -R 777 "$SCRIPT_DIR/marzban/alertmanager" 2>/dev/null || true
fi

# 4. 创建Caddy配置
echo -e "${YELLOW}# 4. 创建或更新 Caddy 配置文件...${NC}"

# 重命名授权目录确保可写
if [ -d "$SCRIPT_DIR/marzban/caddy-data" ]; then
  chmod -R 777 "$SCRIPT_DIR/marzban/caddy-data" 2>/dev/null || true
fi
if [ -d "$SCRIPT_DIR/marzban/caddy-config" ]; then
  chmod -R 777 "$SCRIPT_DIR/marzban/caddy-config" 2>/dev/null || true
fi

# 使用更简单的Caddy配置，自动申请Let's Encrypt证书
cat > "$SCRIPT_DIR/marzban/Caddyfile" << EOF
{
    # 全局设置
    admin off
    email admin@${BASE_DOMAIN}
    log {
        level INFO
    }
    # Let's Encrypt将自动申请证书
}

# 主域名配置
$BASE_DOMAIN {
    # 自动申请SSL证书 (默认行为)
    # tls 将自动使用Let's Encrypt申请
    
    # Marzban面板
    handle /panel/* {
        reverse_proxy marzban:8000
    }
    
    # Grafana监控面板
    handle /monitor/* {
        reverse_proxy grafana:3000
    }
    
    # Netmaker控制台
    handle /netmaker/* {
        reverse_proxy http://localhost:8095
    }
    
    # 根路径跳转到面板
    handle / {
        redir /panel 302
    }
    
    # 启用日志
    log {
        output file /var/log/caddy/access.log
    }
}
EOF
echo -e "${GREEN}Caddy配置文件更新成功${NC}"

# 4.2 修夌Marzban环境配置
echo -e "${YELLOW}创建Marzban环境配置文件...${NC}"

# 创建Marzban环境配置文件
cat > "$SCRIPT_DIR/marzban/env" << EOF
SUDO_USERNAME=admin
SUDO_PASSWORD=admin
XRAY_JSON=/var/lib/marzban/xray_config.json
SQLALCHEMY_DATABASE_URL=mysql+pymysql://root:${MYSQL_PASSWORD:-marzban}@mariadb:3306/marzban
EOF

# 创建MariaDB环境配置文件
cat > "$SCRIPT_DIR/marzban/env-db" << EOF
MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD:-marzban}
MYSQL_DATABASE=marzban
EOF

echo -e "${GREEN}Marzban环境配置文件创建成功${NC}"

# 4.5 修夌Docker Compose配置
echo -e "${YELLOW}修夌Docker Compose配置文件...${NC}"

# 只有当可以访问docker-compose.yml时才修改
if [ -f "$SCRIPT_DIR/marzban/docker-compose.yml" ]; then
  # 备份原始文件
  cp "$SCRIPT_DIR/marzban/docker-compose.yml" "$SCRIPT_DIR/marzban/docker-compose.yml.bak"
  
  # 使用sed修改用户ID的配置
  # 1. 删除grafana的user定义，让它使用默认用户
  sed -i 's/user: "1000"/user: "472"/g' "$SCRIPT_DIR/marzban/docker-compose.yml" || true
  
  # 2. 确保每个服务都使用正确的映射
  grep -q "/prometheus" "$SCRIPT_DIR/marzban/docker-compose.yml" || \
    sed -i 's|volumes:\n      - ./prometheus:/etc/prometheus|volumes:\n      - ./prometheus:/etc/prometheus\n      - ./prometheus-data:/prometheus|g' "$SCRIPT_DIR/marzban/docker-compose.yml" || true
  
  echo -e "${GREEN}Docker Compose文件修复完成${NC}"
else
  echo -e "${YELLOW}警告: 无法找到docker-compose.yml文件${NC}"
  
  # 创建或覆盖docker-compose.yml文件
  echo -e "${YELLOW}创建新的Docker Compose配置文件...${NC}"
  
  cat > "$SCRIPT_DIR/marzban/docker-compose.yml" << 'EOF'
version: '3'
services:
  marzban:
    image: gozargah/marzban:latest
    restart: always
    ports:
      - "8000:8000"  # 直接暴露Marzban端口
    env_file:
      - ./env
    volumes:
      - ./data:/var/lib/marzban
      - ./certs:/var/lib/marzban/certs
    depends_on:
      - mariadb
    networks:
      - marzban-network

  mariadb:
    image: mariadb:10.6
    restart: always
    env_file:
      - ./env-db
    volumes:
      - ./mysql:/var/lib/mysql
    networks:
      - marzban-network

  prometheus:
    image: prom/prometheus:latest
    restart: always
    volumes:
      - ./prometheus:/etc/prometheus
      - ./prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - marzban-network
  
  grafana:
    image: grafana/grafana:latest
    restart: always
    volumes:
      - ./grafana:/var/lib/grafana
    networks:
      - marzban-network
    user: "472"
  
  alertmanager:
    image: prom/alertmanager:latest
    restart: always
    volumes:
      - ./alertmanager:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/config.yml'
    networks:
      - marzban-network

  caddy:
    image: caddy:2
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy-data:/data
      - ./caddy-config:/config
    networks:
      - marzban-network
      - default

networks:
  marzban-network:
  default:
    external: false
EOF
  echo -e "${GREEN}Docker Compose文件创建成功${NC}"
fi

# 5. 启动容器
echo -e "${BLUE}启动Marzban面板...${NC}"

# 启动所有容器
echo -e "${YELLOW}启动Docker容器...${NC}"
cd "$SCRIPT_DIR/marzban"
docker-compose up -d

# 创建前端JS修复脚本
cat > "$SCRIPT_DIR/marzban/fix_js.sh" << 'EOF'
#!/bin/bash

echo "===== 开始修复 Marzban前端JavaScript错误 ====="

# 获取Marzban容器名称
MARZBAN_CONTAINER=$(docker-compose ps -q marzban)
if [ -z "$MARZBAN_CONTAINER" ]; then
  echo "错误: 找不到Marzban容器"
  exit 1
fi

# 创建临时目录
mkdir -p /tmp/js_fix

# 从容器中复制静态文件
echo "从容器中提取前端文件..."
docker cp $MARZBAN_CONTAINER:/code/app/static /tmp/js_fix/

# 查找可能包含错误的JS文件
echo "查找包含错误正则表达式的文件..."
FILES_TO_CHECK=$(find /tmp/js_fix -name "*.js" -type f)

echo "修复可能的Unicode编码问题..."
for file in $FILES_TO_CHECK; do
  # 替换可能的错误字符
  echo "处理文件: $file"
  # 替换包含特殊字符的正则表达式，首先处理您报告的错误
  sed -i 's/\/\[\'\xe2\x80\x9c\]\//\/\[\'"\]\//g' "$file" 2>/dev/null || true
  sed -i 's/\/\[\'\xe2\x80\x9d\]\//\/\[\'"\]\//g' "$file" 2>/dev/null || true
  # 处理其他可能的特殊字符
  sed -i 's/\xe2\x80\x9c/"/g' "$file" 2>/dev/null || true
  sed -i 's/\xe2\x80\x9d/"/g' "$file" 2>/dev/null || true
  sed -i 's/\xe2\x80\x98/\\\'\'/g' "$file" 2>/dev/null || true
  sed -i 's/\xe2\x80\x99/\\\'\'/g' "$file" 2>/dev/null || true
done

# 将修复后的文件复制回容器
echo "将修复后的文件复制回容器..."
docker cp /tmp/js_fix/static $MARZBAN_CONTAINER:/code/app/

# 重启Marzban容器
echo "重启 Marzban 容器..."
docker-compose restart marzban

# 清理临时文件
echo "清理临时文件..."
rm -rf /tmp/js_fix

echo "===== JavaScript文件修复完成 ====="
echo "请尝试访问 https://您的域名/panel 并清除浏览器缓存"
EOF

chmod +x "$SCRIPT_DIR/marzban/fix_js.sh"

# 创建诊断脚本
cat > "$SCRIPT_DIR/marzban/diagnose.sh" << 'EOF'
#!/bin/bash

echo "===== Marzban 诊断工具 ====="
echo "检查容器状态..."
docker-compose ps

echo "\n===== 检查网络配置 ====="
echo "Docker网络:"
docker network ls

echo "\n===== 检查端口监听 ====="
netstat -tulpn | grep -E ':(80|443|8000)'

echo "\n===== 检查防火墙状态 ====="
if command -v ufw &> /dev/null; then
    ufw status
else
    echo "未安装ufw防火墙"
fi

if command -v firewalld &> /dev/null; then
    firewall-cmd --list-all
else
    echo "未安装firewalld防火墙"
fi

echo "\n===== Marzban容器日志(最后20行) ====="
docker-compose logs --tail=20 marzban

echo "\n===== Caddy容器日志(最后20行) ====="
docker-compose logs --tail=20 caddy

echo "\n===== 提示 ====="
echo "1. 如果上述输出显示防火墙阻止了端口8000，请运行:"
echo "   sudo ufw allow 8000/tcp"
echo "   或"
echo "   sudo firewall-cmd --permanent --add-port=8000/tcp && sudo firewall-cmd --reload"

echo "2. 确保服务器提供商没有额外的防火墙规则阻止端口8000"

echo "3. 请检查容器状态，确保所有容器都在运行"
EOF

chmod +x "$SCRIPT_DIR/marzban/diagnose.sh"

# 6. 验证服务
echo -e "${BLUE}验证服务状态...${NC}"
sleep 5
docker-compose ps

echo -e "${GREEN}安装完成!${NC}"
echo -e "${YELLOW}如需诊断问题，请运行: ${NC}"
echo -e "cd ~/vvvvvv/marzban && ./diagnose.sh"

echo -e "${GREEN}安装完成！${NC}"
echo -e "您可以通过以下地址访问："
echo -e "Marzban面板: https://$BASE_DOMAIN/panel"
echo -e "监控面板: https://$BASE_DOMAIN/monitor"
echo -e "Netmaker控制台: https://$BASE_DOMAIN/netmaker"
