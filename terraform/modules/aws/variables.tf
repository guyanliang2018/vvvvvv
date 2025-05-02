variable "node_count" {
  description = "要创建的节点数量"
  type        = number
  default     = 10
}

variable "region_distribution" {
  description = "每个区域的节点分布"
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

variable "instance_type" {
  description = "AWS实例类型"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AWS AMI ID (根据区域)"
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

variable "key_name" {
  description = "AWS密钥对名称"
  type        = string
  default     = ""
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

variable "aws_access_key" {
  description = "AWS访问密钥，用于节点替换"
  type        = string
  default     = ""
}

variable "aws_secret_key" {
  description = "AWS访问密钥，用于节点替换"
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
  default     = "ap-northeast-1"  # Tokyo
}
