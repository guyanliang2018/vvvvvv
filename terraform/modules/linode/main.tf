locals {
  # 基于区域分布创建节点列表
  nodes = flatten([
    for region, count in var.region_distribution : [
      for i in range(count) : {
        name   = "vpn-linode-${region}-${i + 1}"
        region = region
      }
    ]
  ])
}

# 创建Linode实例
resource "linode_instance" "node" {
  count = var.node_count

  label           = local.nodes[count.index].name
  region          = local.nodes[count.index].region
  type            = var.instance_type
  image           = var.image
  authorized_keys = var.authorized_keys
  tags            = ["vpn", "xray", "marzban"]
  
  # 读取并处理cloud-init文件
  stackscript_id = linode_stackscript.init_script.id
  stackscript_data = {
    node_name      = local.nodes[count.index].name
    netmaker_token = var.netmaker_token
    marzban_token  = var.marzban_token
    netmaker_server = var.netmaker_server
    marzban_server = var.marzban_server
  }
  
  # 用于处理创建/销毁特定节点的资源
  lifecycle {
    ignore_changes = [
      stackscript_data
    ]
  }
}

# 创建StackScript来处理cloud-init
resource "linode_stackscript" "init_script" {
  label       = "vpn-node-init"
  description = "VPN节点初始化脚本"
  script      = templatefile("${path.module}/templates/init_script.sh.tpl", {
    cloudinit_content = file(var.cloudinit_file)
  })
  images      = ["linode/ubuntu22.04"]
  is_public   = false
}

# 为替换节点操作定义null_resource
resource "null_resource" "destroy_node" {
  for_each = var.action == "destroy" ? toset([var.node_id]) : toset([])

  provisioner "local-exec" {
    command = "linode-cli linodes delete ${each.key} --text"
    environment = {
      LINODE_CLI_TOKEN = var.linode_token
    }
  }
}

resource "null_resource" "create_node" {
  count = var.action == "create" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      linode-cli linodes create \
        --label ${var.node_name} \
        --region ${var.region} \
        --type ${var.instance_type} \
        --image ${var.image} \
        --authorized_keys ${join(",", var.authorized_keys)} \
        --stackscript_id ${linode_stackscript.init_script.id} \
        --stackscript_data '{"node_name":"${var.node_name}","netmaker_token":"${var.netmaker_token}","marzban_token":"${var.marzban_token}","netmaker_server":"${var.netmaker_server}","marzban_server":"${var.marzban_server}"}' \
        --tags vpn,xray,marzban \
        --text
    EOT
    environment = {
      LINODE_CLI_TOKEN = var.linode_token
    }
  }
  
  # 添加依赖关系，确保创建节点前先销毁旧节点
  depends_on = [null_resource.destroy_node]
}
