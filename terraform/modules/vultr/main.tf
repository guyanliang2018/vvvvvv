locals {
  # 基于区域分布创建节点列表
  nodes = flatten([
    for region, count in var.region_distribution : [
      for i in range(count) : {
        name   = "vpn-vultr-${region}-${i + 1}"
        region = region
      }
    ]
  ])
}

# 创建Vultr实例
resource "vultr_instance" "node" {
  count = var.node_count

  plan              = var.plan
  region            = local.nodes[count.index].region
  os_id             = var.os_id
  label             = local.nodes[count.index].name
  hostname          = local.nodes[count.index].name
  enable_ipv6       = true
  backups           = "disabled"
  ddos_protection   = false
  activation_email  = false
  ssh_key_ids       = var.ssh_key_ids

  # 读取并处理cloud-init文件
  user_data = replace(
    replace(
      replace(
        replace(
          file(var.cloudinit_file),
          "%node_name%", local.nodes[count.index].name
        ),
        "%netmaker_token%", var.netmaker_token
      ),
      "%marzban_token%", var.marzban_token
    ),
    "%netmaker_server%", var.netmaker_server
  )
  
  # 确保用户数据配置完整
  user_data = replace(
    var.user_data,
    "%marzban_server%", 
    var.marzban_server
  )

  # 用于处理创建/销毁特定节点的资源 
  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
}

# 为替换节点操作定义null_resource
resource "null_resource" "destroy_node" {
  for_each = var.action == "destroy" ? toset([var.node_id]) : toset([])

  provisioner "local-exec" {
    command = "vultr-cli instance delete ${each.key}"
    environment = {
      VULTR_API_KEY = var.vultr_api_key
    }
  }
}

resource "null_resource" "create_node" {
  count = var.action == "create" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      vultr-cli instance create \
        --region ${var.region} \
        --plan ${var.plan} \
        --os ${var.os_id} \
        --hostname ${var.node_name} \
        --label ${var.node_name} \
        --ssh-keys ${join(",", var.ssh_key_ids)} \
        --user-data "$(cat ${var.cloudinit_file} | sed -e 's/%node_name%/${var.node_name}/g' -e 's/%netmaker_token%/${var.netmaker_token}/g' -e 's/%marzban_token%/${var.marzban_token}/g' -e 's/%netmaker_server%/${var.netmaker_server}/g' -e 's/%marzban_server%/${var.marzban_server}/g')"
    EOT
    environment = {
      VULTR_API_KEY = var.vultr_api_key
    }
  }
  
  # 添加依赖关系，确保创建节点前先销毁旧节点
  depends_on = [null_resource.destroy_node]
}
