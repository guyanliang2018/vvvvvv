#!/bin/bash
# 多云VPS自动化测试环境启动脚本
# 作者: Cascade
# 日期: 2023-05-02

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

echo -e "${BLUE}多云VPS自动化系统测试环境${NC}"
echo -e "将启动以下组件:"
echo -e "1. ${YELLOW}Marzban面板${NC} - 用于管理代理节点"
echo -e "2. ${YELLOW}Netmaker网络${NC} - 用于建立Mesh内网"
echo -e "3. ${YELLOW}测试节点${NC} - 模拟杂牌VPS节点"
echo

# 检查Docker是否可用
if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}错误: 需要Docker和Docker Compose来运行测试环境${NC}"
    echo "请安装Docker和Docker Compose后重试"
    exit 1
fi

# 创建必要的数据目录
echo -e "${YELLOW}创建必要的数据目录...${NC}"
mkdir -p ./marzban/data ./marzban/mysql ./marzban/prometheus/data ./marzban/grafana ./marzban/alertmanager
mkdir -p ./netmaker/data
mkdir -p ./test_nodes/node1 ./test_nodes/node2

# 生成SSH密钥对(仅用于测试)
echo -e "${YELLOW}生成测试用SSH密钥对...${NC}"
mkdir -p ./ssh_keys
if [ ! -f "./ssh_keys/id_rsa" ]; then
    ssh-keygen -t rsa -b 2048 -f ./ssh_keys/id_rsa -N "" -C "test@example.com"
fi

# 启动Marzban面板
echo -e "${YELLOW}启动Marzban面板...${NC}"
cd ./marzban
docker-compose -f docker-compose.test.yml down
docker-compose -f docker-compose.test.yml up -d
cd ..

# 等待Marzban就绪
echo -e "${YELLOW}等待Marzban服务启动...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:8000/api/system &> /dev/null; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Marzban服务未能在预期时间内启动${NC}"
        echo "请检查docker日志: docker logs marzban_marzban_1"
        exit 1
    fi
    echo "等待Marzban就绪, 尝试 $i/30..."
    sleep 5
done

# 启动Netmaker
echo -e "${YELLOW}启动Netmaker网络控制器...${NC}"
cd ./netmaker
docker-compose -f docker-compose.test.yml down
docker-compose -f docker-compose.test.yml up -d
cd ..

# 等待Netmaker就绪
echo -e "${YELLOW}等待Netmaker服务启动...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:8081/api/status &> /dev/null; then
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}Netmaker服务未能在预期时间内启动${NC}"
        echo "请检查docker日志: docker logs netmaker_netmaker_1"
        exit 1
    fi
    echo "等待Netmaker就绪, 尝试 $i/30..."
    sleep 5
done

# 启动测试节点
echo -e "${YELLOW}启动测试节点...${NC}"
cd ./test_nodes
docker-compose down
docker-compose up -d
cd ..

# 复制SSH公钥到测试节点
echo -e "${YELLOW}复制SSH公钥到测试节点...${NC}"
docker cp ./ssh_keys/id_rsa.pub test-node-1:/tmp/
docker cp ./ssh_keys/id_rsa.pub test-node-2:/tmp/

docker exec test-node-1 bash -c "mkdir -p /root/.ssh && cat /tmp/id_rsa.pub >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
docker exec test-node-2 bash -c "mkdir -p /root/.ssh && cat /tmp/id_rsa.pub >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"

# 获取测试节点IP
TEST_NODE1_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' test-node-1)
TEST_NODE2_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' test-node-2)

# 创建测试配置
echo -e "${YELLOW}创建测试配置文件...${NC}"
cat > ./terraform.tfvars.test <<EOF
# 测试配置
marzban_server   = "http://localhost:8000"
marzban_token    = "marzban_api_key_for_test"
netmaker_server  = "http://localhost:8081"
netmaker_token   = "test-master-key"
netmaker_network_name = "vpn"

# SSH密钥配置
ssh_private_key_path = "$(pwd)/ssh_keys/id_rsa"

# 通用杂牌VPS节点配置
generic_nodes = [
  {
    name       = "test-node-1"
    ip_address = "${TEST_NODE1_IP}"
    provider   = "test"
    region     = "local"
    ssh_user   = "root"
    ssh_port   = 22
  },
  {
    name       = "test-node-2"
    ip_address = "${TEST_NODE2_IP}"
    provider   = "test"
    region     = "local"
    ssh_user   = "root"
    ssh_port   = 22
  }
]
EOF

# 创建测试节点添加脚本
echo -e "${YELLOW}创建测试节点添加帮助脚本...${NC}"
cat > ./add_test_node.sh <<EOF
#!/bin/bash
# 测试环境添加节点脚本

echo -e "${BLUE}添加测试节点到Marzban${NC}"
echo "使用以下API和节点配置:"
echo "Marzban API: http://localhost:8000/api"
echo "API密钥: marzban_api_key_for_test"
echo "节点1: ${TEST_NODE1_IP}"
echo "节点2: ${TEST_NODE2_IP}"
echo
echo "可以通过以下方式添加节点:"
echo "1. 使用generic_nodes模块 (模拟): "
echo "   cp terraform.tfvars.test /path/to/terraform/terraform.tfvars"
echo
echo "2. 使用add-generic-node.sh脚本 (实际测试):"
echo "   cd /path/to/vpn3"
echo "   ./scripts/add-generic-node.sh -n test-node-1 -i ${TEST_NODE1_IP} -r local -u root -k $(pwd)/ssh_keys/id_rsa"
echo
EOF
chmod +x ./add_test_node.sh

echo -e "${GREEN}测试环境已成功启动!${NC}"
echo -e "Marzban面板: ${BLUE}http://localhost:8443${NC}"
echo -e "Marzban API: ${BLUE}http://localhost:8000${NC}"
echo -e "Netmaker管理界面: ${BLUE}http://localhost:8082${NC}"
echo -e "Netmaker API: ${BLUE}http://localhost:8081${NC}"
echo -e "Grafana监控: ${BLUE}http://localhost:3000${NC}"
echo -e "Prometheus: ${BLUE}http://localhost:9090${NC}"
echo
echo -e "${YELLOW}测试节点信息:${NC}"
echo -e "节点1: SSH端口 = 2201, 用户 = root, 密码 = testpassword"
echo -e "节点2: SSH端口 = 2202, 用户 = root, 密码 = testpassword"
echo
echo -e "${YELLOW}测试步骤:${NC}"
echo "1. 登录Marzban面板 (admin/admin): http://localhost:8443"
echo "2. 登录Netmaker管理界面: http://localhost:8082"
echo "3. 运行 ./add_test_node.sh 查看如何添加测试节点"
echo
echo -e "${YELLOW}清理测试环境:${NC}"
echo "运行以下命令停止所有容器:"
echo "cd ./marzban && docker-compose -f docker-compose.test.yml down"
echo "cd ./netmaker && docker-compose -f docker-compose.test.yml down"
echo "cd ./test_nodes && docker-compose down"

exit 0
