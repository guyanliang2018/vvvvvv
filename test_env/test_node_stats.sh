#!/bin/bash
# 测试节点性能统计功能

echo "===== 节点性能统计功能测试 ====="
echo "模拟node-stats.sh的核心功能"
echo

echo "1. 收集测试节点性能数据"
echo "测试节点1 (192.168.100.101):"
echo "CPU 统计:"
docker exec test-node-1 grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage "%"}'
echo "内存统计:"
docker exec test-node-1 free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }'
echo "磁盘使用:"
docker exec test-node-1 df -h / | awk 'NR==2{print $5}'
echo "节点负载:"
docker exec test-node-1 cat /proc/loadavg

echo
echo "测试节点2 (192.168.100.102):"
echo "CPU 统计:"
docker exec test-node-2 grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage "%"}'
echo "内存统计:"
docker exec test-node-2 free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }'
echo "磁盘使用:"
docker exec test-node-2 df -h / | awk 'NR==2{print $5}'
echo "节点负载:"
docker exec test-node-2 cat /proc/loadavg

echo
echo "2. 模拟网络性能测试"
echo "测试节点1带宽测试 (模拟数据):"
echo "  - 下行: 120 Mbps"
echo "  - 上行: 20 Mbps"
echo "  - 延迟: 150 ms"

echo "测试节点2带宽测试 (模拟数据):"
echo "  - 下行: 140 Mbps"
echo "  - 上行: 25 Mbps"
echo "  - 延迟: 130 ms"

echo
echo "3. 生成性能排名"
echo "节点性能排名 (模拟):"
echo "1. 测试节点2 - 总分: 85/100"
echo "2. 测试节点1 - 总分: 78/100"

echo
echo "4. 优化建议"
echo "测试节点1优化建议:"
echo "  - 考虑清理磁盘空间"
echo "  - 检查是否存在异常CPU负载进程"

echo "测试节点2优化建议:"
echo "  - 网络连接稳定性有波动，建议监控"

echo
echo "===== 测试完成 ====="
