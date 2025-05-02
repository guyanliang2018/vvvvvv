variable "node_count" {
  description = "要创建的节点数量"
  type        = number
  default     = 10
}

variable "region_distribution" {
  description = "每个区域的节点分布"
  type        = map(number)
  default = {
    "nrt" = 3  # Tokyo
    "sgp" = 2  # Singapore
    "fra" = 2  # Frankfurt
    "ams" = 1  # Amsterdam
    "lhr" = 1  # London
    "sea" = 1  # Seattle
  }
}

variable "plan" {
  description = "Vultr实例计划"
  type        = string
  default     = "vc2-1c-1gb"
}

variable "os_id" {
  description = "Vultr操作系统ID"
  type        = number
  default     = 1743  # Ubuntu 22.04 x64
}

variable "ssh_key_ids" {
  description = "Vultr SSH密钥ID列表"
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

variable "vultr_api_key" {
  description = "Vultr API密钥，用于节点替换"
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
  default     = "nrt"  # Tokyo
}

variable "user_data" {
  description = "用户数据，替换占位符后传递给实例"
  type        = string
  default     = ""
}
