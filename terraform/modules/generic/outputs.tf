output "nodes" {
  description = "已配置的杂牌VPS节点信息"
  value = [
    for i, node in var.nodes : {
      name        = node.name
      ip_address  = node.ip_address
      provider    = node.provider
      region      = node.region
      ssh_user    = node.ssh_user
      ssh_port    = node.ssh_port
    }
  ]
}

output "node_count" {
  description = "成功配置的杂牌VPS节点数量"
  value       = length(var.nodes)
}
