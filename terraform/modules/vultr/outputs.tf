output "nodes" {
  description = "已创建的Vultr节点列表"
  value = [
    for instance in vultr_instance.node : {
      id        = instance.id
      name      = instance.hostname
      region    = instance.region
      ip        = instance.main_ip
      ipv6      = instance.v6_main_ip
      status    = instance.status
      provider  = "vultr"
    }
  ]
}
