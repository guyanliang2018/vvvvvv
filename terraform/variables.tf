variable "vultr_api_key" {
  description = "Vultr API密钥"
  type        = string
  sensitive   = true
}

variable "do_token" {
  description = "DigitalOcean API令牌"
  type        = string
  sensitive   = true
}

variable "linode_token" {
  description = "Linode API令牌"
  type        = string
  sensitive   = true
}

variable "aws_access_key" {
  description = "AWS访问密钥"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS密钥"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS主区域"
  type        = string
  default     = "ap-northeast-1"
}

# Vultr配置
variable "vultr_node_count" {
  description = "Vultr节点数量"
  type        = number
  default     = 10
}

variable "vultr_regions" {
  description = "Vultr区域分布"
  type        = map(number)
  default = {
    "nrt" = 3   # Tokyo
    "sgp" = 2   # Singapore
    "fra" = 2   # Frankfurt
    "ams" = 1   # Amsterdam
    "lhr" = 1   # London
    "sea" = 1   # Seattle
  }
}

variable "vultr_plan" {
  description = "Vultr实例计划"
  type        = string
  default     = "vc2-1c-1gb"
}

variable "vultr_os_id" {
  description = "Vultr操作系统ID"
  type        = number
  default     = 1743  # Ubuntu 22.04 x64
}

variable "vultr_ssh_key_ids" {
  description = "Vultr SSH密钥ID列表"
  type        = list(string)
  default     = []
}

# DigitalOcean配置
variable "do_node_count" {
  description = "DigitalOcean节点数量"
  type        = number
  default     = 10
}

variable "do_regions" {
  description = "DigitalOcean区域分布"
  type        = map(number)
  default = {
    "sgp1" = 3  # Singapore
    "fra1" = 2  # Frankfurt
    "nyc1" = 2  # New York
    "lon1" = 1  # London
    "tor1" = 1  # Toronto
    "sfo3" = 1  # San Francisco
  }
}

variable "do_droplet_size" {
  description = "DigitalOcean实例大小"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "do_image" {
  description = "DigitalOcean镜像"
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "do_ssh_key_ids" {
  description = "DigitalOcean SSH密钥ID列表"
  type        = list(string)
  default     = []
}

# Linode配置
variable "linode_node_count" {
  description = "Linode节点数量"
  type        = number
  default     = 10
}

variable "linode_regions" {
  description = "Linode区域分布"
  type        = map(number)
  default = {
    "ap-northeast" = 3  # Tokyo
    "ap-south"     = 2  # Singapore
    "eu-west"      = 2  # London
    "eu-central"   = 1  # Frankfurt
    "us-east"      = 1  # Newark
    "us-west"      = 1  # Fremont
  }
}

variable "linode_instance_type" {
  description = "Linode实例类型"
  type        = string
  default     = "g6-nanode-1"
}

variable "linode_image" {
  description = "Linode镜像"
  type        = string
  default     = "linode/ubuntu22.04"
}

variable "linode_authorized_keys" {
  description = "Linode授权SSH密钥列表"
  type        = list(string)
  default     = []
}

# AWS配置
variable "aws_node_count" {
  description = "AWS节点数量"
  type        = number
  default     = 10
}

variable "aws_regions" {
  description = "AWS区域分布"
  type        = map(number)
  default = {
    "ap-northeast-1" = 3  # Tokyo
    "ap-southeast-1" = 2  # Singapore
    "eu-central-1"   = 2  # Frankfurt
    "eu-west-2"      = 1  # London
    "us-east-1"      = 1  # N. Virginia
    "us-west-2"      = 1  # Oregon
  }
}

variable "aws_instance_type" {
  description = "AWS实例类型"
  type        = string
  default     = "t3.micro"
}

variable "aws_ami_id" {
  description = "AWS AMI ID (默认值将根据区域自动查找)"
  type        = map(string)
  default = {
    "ap-northeast-1" = "ami-0d52744d6551d851e"  # Tokyo - Ubuntu 22.04
    "ap-southeast-1" = "ami-0df7a207adb9748c7"  # Singapore - Ubuntu 22.04
    "eu-central-1"   = "ami-0caef02b518350c8b"  # Frankfurt - Ubuntu 22.04
    "eu-west-2"      = "ami-0505148b3591e4c07"  # London - Ubuntu 22.04
    "us-east-1"      = "ami-052efd3df9dad4825"  # N. Virginia - Ubuntu 22.04
    "us-west-2"      = "ami-0fcf52bcf5db7b003"  # Oregon - Ubuntu 22.04
  }
}

variable "aws_key_name" {
  description = "SSH密钥名称"
  type        = string
  default     = "marzban-node-key"
}

# 通用杂牌VPS节点配置
variable "generic_nodes" {
  description = "杂牌VPS节点列表配置"
  type = list(object({
    name       = string
    ip_address = string
    provider   = string
    region     = string
    ssh_user   = string
    ssh_port   = number
  }))
  default = []
}

variable "ssh_private_key_path" {
  description = "用于连接杂牌VPS的SSH私钥路径"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "netmaker_network_name" {
  description = "Netmaker网络名称"
  type        = string
  default     = "vpn"
}

# 通用配置
variable "cloudinit_file" {
  description = "Cloud-init配置文件路径"
  type        = string
  default     = "../cloud-init/base-cloudinit.yml"
}

variable "netmaker_token" {
  description = "Netmaker接入令牌"
  type        = string
  sensitive   = true
}

variable "marzban_token" {
  description = "Marzban API令牌"
  type        = string
  sensitive   = true
}

variable "netmaker_server" {
  description = "Netmaker服务器地址"
  type        = string
  default     = "netmaker.your-domain.com"
}

variable "marzban_server" {
  description = "Marzban服务器地址"
  type        = string
  default     = "panel.your-domain.com"
}
