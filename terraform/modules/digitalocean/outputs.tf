output "nodes" {
  description = "已创建的DigitalOcean节点列表"
  value = [
    for instance in digitalocean_droplet.node : {
      id        = instance.id
      name      = instance.name
      region    = instance.region
      ip        = instance.ipv4_address
      ipv6      = instance.ipv6_address
      status    = instance.status
      provider  = "digitalocean"
    }
  ]
}
