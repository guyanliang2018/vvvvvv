locals {
  # 基于区域分布创建节点列表
  nodes = flatten([
    for region, count in var.region_distribution : [
      for i in range(count) : {
        name   = "vpn-aws-${replace(region, "-", "")}-${i + 1}"
        region = region
        ami    = lookup(var.ami_id, region, "")
      }
    ]
  ])
}

# 为每个区域创建必要的AWS网络资源
resource "aws_vpc" "vpc" {
  for_each = var.region_distribution

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "vpn-vpc-${each.key}"
  }
  
  provider = aws.region
}

resource "aws_subnet" "subnet" {
  for_each = var.region_distribution

  vpc_id                  = aws_vpc.vpc[each.key].id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${each.key}a"
  
  tags = {
    Name = "vpn-subnet-${each.key}"
  }
  
  provider = aws.region
}

resource "aws_internet_gateway" "igw" {
  for_each = var.region_distribution

  vpc_id = aws_vpc.vpc[each.key].id
  
  tags = {
    Name = "vpn-igw-${each.key}"
  }
  
  provider = aws.region
}

resource "aws_route_table" "rt" {
  for_each = var.region_distribution

  vpc_id = aws_vpc.vpc[each.key].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[each.key].id
  }
  
  tags = {
    Name = "vpn-rt-${each.key}"
  }
  
  provider = aws.region
}

resource "aws_route_table_association" "rta" {
  for_each = var.region_distribution

  subnet_id      = aws_subnet.subnet[each.key].id
  route_table_id = aws_route_table.rt[each.key].id
  
  provider = aws.region
}

resource "aws_security_group" "sg" {
  for_each = var.region_distribution

  name        = "vpn-sg-${each.key}"
  description = "VPN节点安全组"
  vpc_id      = aws_vpc.vpc[each.key].id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }
  
  ingress {
    from_port   = 8443
    to_port     = 8449
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Xray服务"
  }
  
  ingress {
    from_port   = 51820
    to_port     = 51830
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WireGuard"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "允许所有出站流量"
  }
  
  tags = {
    Name = "vpn-sg-${each.key}"
  }
  
  provider = aws.region
}

# 创建AWS EC2实例
resource "aws_instance" "node" {
  count = var.node_count

  ami                    = local.nodes[count.index].ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnet[local.nodes[count.index].region].id
  vpc_security_group_ids = [aws_security_group.sg[local.nodes[count.index].region].id]
  key_name               = var.key_name
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  
  # 读取并处理cloud-init文件
  user_data = templatefile("${path.module}/templates/user-data.tpl", {
    node_name       = local.nodes[count.index].name,
    netmaker_token  = var.netmaker_token,
    marzban_token   = var.marzban_token,
    netmaker_server = var.netmaker_server,
    marzban_server  = var.marzban_server,
    cloudinit       = file(var.cloudinit_file)
  })
  
  tags = {
    Name = local.nodes[count.index].name
    Type = "vpn-node"
  }
  
  # 用于处理创建/销毁特定节点的资源
  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
  
  provider = aws.region
}

# 为替换节点操作定义null_resource
resource "null_resource" "destroy_node" {
  for_each = var.action == "destroy" ? toset([var.node_id]) : toset([])

  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --region ${var.region} --instance-ids ${each.key}"
    environment = {
      AWS_ACCESS_KEY_ID     = var.aws_access_key
      AWS_SECRET_ACCESS_KEY = var.aws_secret_key
    }
  }
}

resource "null_resource" "create_node" {
  count = var.action == "create" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 run-instances \
        --region ${var.region} \
        --image-id ${lookup(var.ami_id, var.region, "")} \
        --instance-type ${var.instance_type} \
        --key-name ${var.key_name} \
        --security-group-ids ${aws_security_group.sg[var.region].id} \
        --subnet-id ${aws_subnet.subnet[var.region].id} \
        --user-data file://<(cat ${path.module}/templates/user-data-cli.sh | \
          sed -e 's/%node_name%/${var.node_name}/g' \
              -e 's/%netmaker_token%/${var.netmaker_token}/g' \
              -e 's/%marzban_token%/${var.marzban_token}/g' \
              -e 's/%netmaker_server%/${var.netmaker_server}/g' \
              -e 's/%marzban_server%/${var.marzban_server}/g') \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=${var.node_name}},{Key=Type,Value=vpn-node}]' \
        --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=20,VolumeType=gp3}'
    EOT
    environment = {
      AWS_ACCESS_KEY_ID     = var.aws_access_key
      AWS_SECRET_ACCESS_KEY = var.aws_secret_key
    }
  }
  
  # 添加依赖关系，确保创建节点前先销毁旧节点
  depends_on = [null_resource.destroy_node]
}
