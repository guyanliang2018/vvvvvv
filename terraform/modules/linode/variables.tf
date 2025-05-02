variable "node_count" {
  description = "要创建的节点数量"
  type        = number
  default     = 10
}

variable "region_distribution" {
  description = "每个区域的节点分布"
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

variable "instance_type" {
  description = "Linode实例类型"
  type        = string
  default     = "g6-nanode-1"
}

variable "image" {
  description = "Linode镜像"
  type        = string
  default     = "linode/ubuntu22.04"
}

variable "authorized_keys" {
  description = "Linode授权SSH密钥列表"
  type        = list(string)
  default     = []
}

variable "cloudinit_file" {
  description = "Cloud-init配置文件路径"
  type        = string
}

variable "netmaker_token" {
  description = "Netmaker接入令牌"
  type        = string
}

variable "marzban_token" {
  description = "Marzban API令牌"
  type        = string
}

variable "netmaker_server" {
  description = "Netmaker服务器地址"
  type        = string
}

variable "marzban_server" {
  description = "Marzban服务器地址"
  type        = string
}

variable "linode_token" {
  description = "Linode API令牌，用于节点替换"
  type        = string
  default     = ""
}

variable "action" {
  description = "对节点执行的操作 (create/destroy)"
  type        = string
  default     = ""
}

variable "node_id" {
  description = "节点ID，用于销毁特定节点"
  type        = string
  default     = ""
}

variable "node_name" {
  description = "新节点的名称，用于创建节点"
  type        = string
  default     = ""
}

variable "region" {
  description = "新节点的区域，用于创建节点"
  type        = string
  default     = "ap-northeast"  # Tokyo
}
