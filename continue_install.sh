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

# 3. 设置目录权限
echo -e "${YELLOW}设置正确的目录权限...${NC}"
if command -v sudo &> /dev/null; then
  # 如果有sudo权限
  sudo chown -R 1000:1000 "$SCRIPT_DIR/marzban/grafana" || true
  sudo chown -R 1000:1000 "$SCRIPT_DIR/marzban/prometheus" || true
  sudo chown -R 1000:1000 "$SCRIPT_DIR/marzban/prometheus-data" || true
  sudo chown -R 1000:1000 "$SCRIPT_DIR/marzban/alertmanager" || true
  sudo chmod -R 755 "$SCRIPT_DIR/marzban/grafana" "$SCRIPT_DIR/marzban/prometheus" "$SCRIPT_DIR/marzban/prometheus-data" "$SCRIPT_DIR/marzban/alertmanager" || true
else
  # 如果没有sudo，尝试直接设置
  chown -R 1000:1000 "$SCRIPT_DIR/marzban/grafana" 2>/dev/null || echo -e "${YELLOW}注意: 无法设置 grafana 目录权限${NC}"
  chown -R 1000:1000 "$SCRIPT_DIR/marzban/prometheus" 2>/dev/null || echo -e "${YELLOW}注意: 无法设置 prometheus 目录权限${NC}"
  chown -R 1000:1000 "$SCRIPT_DIR/marzban/prometheus-data" 2>/dev/null || echo -e "${YELLOW}注意: 无法设置 prometheus-data 目录权限${NC}"
  chown -R 1000:1000 "$SCRIPT_DIR/marzban/alertmanager" 2>/dev/null || echo -e "${YELLOW}注意: 无法设置 alertmanager 目录权限${NC}"
  chmod -R 755 "$SCRIPT_DIR/marzban/grafana" "$SCRIPT_DIR/marzban/prometheus" "$SCRIPT_DIR/marzban/prometheus-data" "$SCRIPT_DIR/marzban/alertmanager" 2>/dev/null || true
fi

# 4. 创建Caddy配置
if [ ! -f "$SCRIPT_DIR/marzban/Caddyfile" ]; then
  echo -e "${YELLOW}创建 Caddy 配置文件...${NC}"
  cat > "$SCRIPT_DIR/marzban/Caddyfile" << EOF
$BASE_DOMAIN {
    reverse_proxy /panel/* marzban:8000 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
    }
    
    reverse_proxy /monitor/* grafana:3000 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
    }
    
    reverse_proxy /netmaker/* netmaker:8080 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
    }
    
    log {
        output file /var/log/caddy/access.log
    }
}
EOF
  echo -e "${GREEN}Caddy配置文件创建成功${NC}"
fi

# 5. 启动容器
echo -e "${BLUE}启动Marzban面板...${NC}"

# 清理旧容器
echo -e "${YELLOW}清理可能的残留容器...${NC}"
cd "$SCRIPT_DIR/marzban"
docker-compose down 2>/dev/null || true

# 启动容器
echo -e "${GREEN}启动所有服务...${NC}"
docker-compose up -d

# 6. 验证服务
echo -e "${BLUE}验证服务状态...${NC}"
sleep 5
docker-compose ps

echo -e "${GREEN}安装完成！${NC}"
echo -e "您可以通过以下地址访问："
echo -e "Marzban面板: https://$BASE_DOMAIN/panel"
echo -e "监控面板: https://$BASE_DOMAIN/monitor"
echo -e "Netmaker控制台: https://$BASE_DOMAIN/netmaker"
