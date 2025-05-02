variable "nodes" {
  description = "杂牌VPS节点列表，包含节点名称、IP地址、SSH用户等信息"
  type = list(object({
    name       = string
    ip_address = string
    provider   = string
    region     = string
    ssh_user   = string
    ssh_port   = number
  }))
}

variable "ssh_private_key_path" {
  description = "SSH私钥路径，用于连接到杂牌VPS节点"
  type        = string
}

variable "marzban_api_url" {
  description = "Marzban API的URL地址"
  type        = string
}

variable "marzban_api_key" {
  description = "Marzban API的访问密钥"
  type        = string
  sensitive   = true
}

variable "netmaker_server" {
  description = "Netmaker服务器地址"
  type        = string
  default     = ""
}

variable "netmaker_token" {
  description = "Netmaker API Token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "netmaker_network" {
  description = "Netmaker网络名称"
  type        = string
  default     = "vpn"
}

variable "prometheus_url" {
  description = "Prometheus服务器地址，用于节点监控"
  type        = string
  default     = ""
}

variable "setup_script_path" {
  description = "节点安装脚本的本地路径"
  type        = string
  default     = "../scripts/setup.sh"
}

variable "common_tags" {
  description = "通用标签，应用于所有资源"
  type        = map(string)
  default     = {}
}
