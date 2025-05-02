output "nodes" {
  description = "已创建的AWS EC2节点列表"
  value = [
    for instance in aws_instance.node : {
      id        = instance.id
      name      = instance.tags.Name
      region    = instance.availability_zone
      ip        = instance.public_ip
      ipv6      = instance.ipv6_address
      status    = instance.instance_state
      provider  = "aws"
    }
  ]
}
