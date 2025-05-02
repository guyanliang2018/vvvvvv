output "nodes" {
  description = "已创建的Linode节点列表"
  value = [
    for instance in linode_instance.node : {
      id        = instance.id
      name      = instance.label
      region    = instance.region
      ip        = instance.ip_address
      ipv6      = instance.ipv6
      status    = instance.status
      provider  = "linode"
    }
  ]
}
