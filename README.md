# 杂牌云 / VPS 多云自动化系统

一套完整的多云VPS自动化管理系统，用于搭建分布式的代理服务网络。本系统使用Marzban作为控制面板，支持VMess/VLESS/Trojan/Reality等协议，并通过Netmaker建立Mesh内网，实现集中化的用户/流量管理和自动化运维。

## 主要特性

- **多云支持**：同时管理部署在Vultr、DigitalOcean、Linode、AWS等多个云服务商的VPS，以及任何杂牌VPS
- **协议支持**：VMess/VLESS/Trojan/Shadowsocks/Reality等全协议支持
- **快速部署**：5分钟拉起新节点，10分钟完成替补
- **集中管理**：通过Marzban集中管理用户、订阅和流量
- **内网互联**：所有节点通过Netmaker组成安全的WireGuard Mesh内网
- **自动化运维**：通过Terraform实现基础设施即代码，通过Ansible实现配置管理
- **实时监控**：通过Prometheus + Grafana实现全面监控和告警

## 系统架构

```
       ┌──────────┐ ①开机+cloud-init    ┌──────────────────────────┐
多云→  │ VPS 批量 │ ──────────────────▶ │ bootstrap(setup.sh)      │
       └──────────┘                    │• 安装 Docker & Xray       │
                                        │• 加入 Netmaker Mesh      │
                                        └─────────┬───────────────┘
                                                  │
                                                  │WireGuard 内网
                                                  ▼
┌──────────────┐ Heartbeat/流量  ┌──────────────────────┐
│ Xray 节点群  │───────────────▶│ Marzban 面板         │②服务层控制
└──────────────┘                └─────────┬────────────┘
                                          │
                      Prom scrape         ▼
                   ┌────────────────────────────┐
                   │ Prometheus + Loki + Grafana │③观测
                   └────────────────────────────┘
```

## 快速开始

### 前提条件

- Linux/macOS系统（用于控制端）
- Docker和Docker Compose
- Terraform
- Ansible
- 域名（用于Marzban面板和Netmaker）
- 各云服务商的API密钥

### 1. 准备环境

1. 克隆本仓库：
   ```bash
   git clone https://github.com/yourusername/vpn3.git
   cd vpn3
   ```

2. 创建并编辑凭证文件：
   ```bash
   cp credentials.env.example credentials.env
   # 编辑凭证文件填入相关API密钥
   vim credentials.env
   ```

3. 为各环境准备Terraform变量：
   ```bash
   cp terraform/environments/prod/terraform.tfvars.example terraform/environments/prod/terraform.tfvars
   # 编辑变量文件
   vim terraform/environments/prod/terraform.tfvars
   ```

### 2. 部署控制面板

1. 首先部署Netmaker网络控制器：
   ```bash
   cd netmaker
   # 编辑docker-compose.yml和Caddyfile，替换域名
   docker-compose up -d
   ```

2. 获取Netmaker接入令牌：
   ```bash
   TOKEN=$(docker exec netmaker netclient join-token -v)
   echo $TOKEN
   # 将此令牌保存到credentials.env文件的NETMAKER_TOKEN变量中
   ```

3. 部署Marzban面板：
   ```bash
   cd ../marzban
   # 编辑env文件，替换域名和数据库密码
   docker-compose up -d
   ```

4. 获取Marzban API令牌：
   ```bash
   # 登录Marzban Web界面，创建API密钥
   # 将此API密钥保存到credentials.env文件的MARZBAN_TOKEN变量中
   ```

### 3. 部署节点

1. 使用Terraform创建VPS：
   ```bash
   cd ../terraform
   terraform init
   terraform apply
   ```

   对于杂牌VPS节点，使用专用添加工具：
   ```bash
   ./scripts/add-generic-node.sh -n jp-vps-01 -i 123.456.789.10 -r jp -u root
   cd ../terraform
   terraform apply -target=module.generic_nodes
   ```

2. 使用Ansible配置节点：
   ```bash
   cd ../ansible
   ansible-playbook -i inventory/hosts.yml playbooks/site.yml
   ```

### 4. 管理节点

- 检查节点状态：
  ```bash
  ./scripts/check-nodes.sh
  ```

- 替换故障节点：
  ```bash
  ./scripts/replace-node.sh vultr node-id-123
  ```

## 详细文档

### 组件说明

| 组件 | 说明 |
|------|------|
| Marzban | 强大的Xray管理面板，支持多协议和用户管理 |
| Netmaker | 基于WireGuard的Mesh网络，实现节点互联 |
| Terraform | 基础设施即代码，自动化创建/销毁VPS |
| Ansible | 配置管理工具，自动化节点配置 |
| Prometheus/Grafana | 监控和可视化系统 |
| GitHub Actions | CI/CD自动化流程 |

### 杂牌VPS支持

本系统特别添加了对任何杂牌VPS的支持，只要具有SSH访问权限，无论是哪家小众VPS提供商，都可以轻松集成到系统中：

1. **简单添加流程**：
   ```bash
   # 添加单个节点
   ./scripts/add-generic-node.sh -n jp-vps-01 -i 123.456.789.10 -r jp -u root
   
   # 批量添加节点
   ./scripts/add-generic-node.sh -n hk-vps-01 -i 1.2.3.4 -r hk -u root -b
   ./scripts/add-generic-node.sh -n sg-vps-01 -i 2.3.4.5 -r sg -u admin -p 2222 -b
   ```

2. **支持任何Linux发行版**：Ubuntu, Debian, CentOS等常见发行版均可

3. **自动配置**：系统会自动配置SSH连接、安装必要组件、注册到Marzban控制面板并加入Netmaker网络

4. **统一管理**：添加后的杂牌VPS节点与其他云服务商节点一样，享有完全相同的管理、监控和运维功能

### 脚本说明

- `scripts/setup.sh`: 节点初始化脚本
- `scripts/replace-node.sh`: 节点替换脚本
- `scripts/check-nodes.sh`: 节点状态检查脚本
- `scripts/add-generic-node.sh`: 杂牌VPS节点添加工具
- `scripts/node-stats.sh`: 节点性能统计与优化建议脚本
- `scripts/backup.sh`: 系统备份与恢复脚本
- `scripts/security-audit.sh`: 节点安全审计与自动加固脚本

### 故障排除

1. **节点无法连接到Netmaker**:
   - 检查Netmaker服务器是否正常运行
   - 验证防火墙是否允许UDP 51820-51830端口
   - 检查节点的netclient日志: `journalctl -u netclient`

2. **Xray服务无法启动**:
   - 检查配置文件: `docker exec xray cat /etc/xray/config.json`
   - 查看Xray日志: `docker logs xray`

3. **TLS证书问题**:
   - 检查acme.sh日志: `cat ~/.acme.sh/acme.sh.log`
   - 手动续期证书: `acme.sh --renew -d yourdomain.com`

## 安全注意事项

- 所有API密钥都存储在不会提交到Git的credentials.env文件中
- 访问控制面板时使用强密码
- 定期更新系统和组件
- 监控异常流量

## 贡献

欢迎贡献代码或报告问题！使用Pull Request或Issue参与项目改进。

## 许可证

MIT
