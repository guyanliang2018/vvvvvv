terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# 通用节点资源 - 为没有API的杂牌VPS提供管理能力
resource "null_resource" "generic_nodes" {
  count = length(var.nodes)

  triggers = {
    name       = var.nodes[count.index].name
    ip_address = var.nodes[count.index].ip_address
    provider   = var.nodes[count.index].provider
    region     = var.nodes[count.index].region
    ssh_key    = var.ssh_private_key_path
    ssh_user   = var.nodes[count.index].ssh_user
  }

  # 使用本地脚本远程配置节点 
  provisioner "local-exec" {
    command = <<-EOT
      echo "开始配置杂牌VPS节点: ${var.nodes[count.index].name} (${var.nodes[count.index].ip_address})"
      
      # 等待SSH可用
      for i in {1..30}; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "${var.ssh_private_key_path}" ${var.nodes[count.index].ssh_user}@${var.nodes[count.index].ip_address} "echo 'SSH连接成功'"; then
          break
        fi
        if [ $i -eq 30 ]; then
          echo "无法连接到节点: ${var.nodes[count.index].ip_address}"
          exit 1
        fi
        echo "等待SSH准备就绪，尝试 $i/30..."
        sleep 10
      done
      
      # 上传节点安装脚本
      scp -o StrictHostKeyChecking=no -i "${var.ssh_private_key_path}" ${var.setup_script_path} ${var.nodes[count.index].ssh_user}@${var.nodes[count.index].ip_address}:/tmp/setup.sh
      
      # 执行安装脚本
      ssh -o StrictHostKeyChecking=no -i "${var.ssh_private_key_path}" ${var.nodes[count.index].ssh_user}@${var.nodes[count.index].ip_address} "chmod +x /tmp/setup.sh && sudo /tmp/setup.sh \
        --marzban-api-url ${var.marzban_api_url} \
        --marzban-api-key ${var.marzban_api_key} \
        --node-name ${var.nodes[count.index].name} \
        --node-provider ${var.nodes[count.index].provider} \
        --node-region ${var.nodes[count.index].region} \
        --netmaker-server ${var.netmaker_server} \
        --netmaker-token ${var.netmaker_token} \
        --netmaker-network ${var.netmaker_network} \
        --prometheus-url ${var.prometheus_url}"
      
      echo "杂牌VPS节点配置完成: ${var.nodes[count.index].name}"
    EOT
  }

  # 节点销毁处理
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "开始销毁杂牌VPS节点在Marzban和Netmaker中的配置: ${self.triggers.name}"
      
      # 从Marzban删除节点
      curl -s -X DELETE \
        "${var.marzban_api_url}/api/nodes/${self.triggers.name}" \
        -H "Authorization: Bearer ${var.marzban_api_key}" || echo "从Marzban删除节点失败，可能已经不存在"
      
      # 从Netmaker删除节点 (可选)
      if [ ! -z "${var.netmaker_token}" ] && [ ! -z "${var.netmaker_server}" ]; then
        MACHINE_KEY=$(curl -s -X GET "${var.netmaker_server}/api/nodes?network=${var.netmaker_network}" \
          -H "Authorization: Bearer ${var.netmaker_token}" | \
          jq -r '.[] | select(.name=="${self.triggers.name}") | .id' 2>/dev/null || echo "")
          
        if [ ! -z "$MACHINE_KEY" ]; then
          curl -s -X DELETE "${var.netmaker_server}/api/nodes/${MACHINE_KEY}?network=${var.netmaker_network}" \
            -H "Authorization: Bearer ${var.netmaker_token}" || echo "从Netmaker删除节点失败"
        fi
      fi
      
      echo "杂牌VPS节点在系统中的配置已清理: ${self.triggers.name}"
    EOT
  }
}
