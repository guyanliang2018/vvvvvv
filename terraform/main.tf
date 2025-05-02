terraform {
  required_version = ">= 1.0.0"
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.15.1"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.28.0"
    }
    linode = {
      source  = "linode/linode"
      version = "~> 2.5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# 提供商配置
provider "vultr" {
  api_key = var.vultr_api_key
}

provider "digitalocean" {
  token = var.do_token
}

provider "linode" {
  token = var.linode_token
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# 云服务商模块
module "vultr_nodes" {
  source = "./modules/vultr"
  
  node_count          = var.vultr_node_count
  region_distribution = var.vultr_regions
  plan                = var.vultr_plan
  os_id               = var.vultr_os_id
  ssh_key_ids         = var.vultr_ssh_key_ids
  cloudinit_file      = var.cloudinit_file
  netmaker_token      = var.netmaker_token
  marzban_token       = var.marzban_token
  netmaker_server     = var.netmaker_server
  marzban_server      = var.marzban_server
}

module "digitalocean_nodes" {
  source = "./modules/digitalocean"
  
  node_count          = var.do_node_count
  region_distribution = var.do_regions
  droplet_size        = var.do_droplet_size
  image               = var.do_image
  ssh_key_ids         = var.do_ssh_key_ids
  cloudinit_file      = var.cloudinit_file
  netmaker_token      = var.netmaker_token
  marzban_token       = var.marzban_token
  netmaker_server     = var.netmaker_server
  marzban_server      = var.marzban_server
}

module "linode_nodes" {
  source = "./modules/linode"
  
  node_count          = var.linode_node_count
  region_distribution = var.linode_regions
  instance_type       = var.linode_instance_type
  image               = var.linode_image
  authorized_keys     = var.linode_authorized_keys
  cloudinit_file      = var.cloudinit_file
  netmaker_token      = var.netmaker_token
  marzban_token       = var.marzban_token
  netmaker_server     = var.netmaker_server
  marzban_server      = var.marzban_server
}

module "aws_nodes" {
  source = "./modules/aws"
  
  node_count          = var.aws_node_count
  region_distribution = var.aws_regions
  instance_type       = var.aws_instance_type
  ami_id              = var.aws_ami_id
  key_name            = var.aws_key_name
  cloudinit_file      = var.cloudinit_file
  netmaker_token      = var.netmaker_token
  marzban_token       = var.marzban_token
  netmaker_server     = var.netmaker_server
  marzban_server      = var.marzban_server
}

module "generic_nodes" {
  source = "./modules/generic"
  
  nodes                = var.generic_nodes
  ssh_private_key_path = var.ssh_private_key_path
  marzban_api_url      = "${var.marzban_server}/api"
  marzban_api_key      = var.marzban_token
  netmaker_server      = var.netmaker_server
  netmaker_token       = var.netmaker_token
  netmaker_network     = var.netmaker_network_name
  prometheus_url       = "${var.marzban_server}:9090"
  setup_script_path    = "${path.root}/../scripts/setup.sh"
  
  depends_on = [module.vultr_nodes, module.digitalocean_nodes, module.linode_nodes, module.aws_nodes]
}

# 输出配置
output "vultr_nodes" {
  value = module.vultr_nodes.nodes
}

output "digitalocean_nodes" {
  value = module.digitalocean_nodes.nodes
}

output "linode_nodes" {
  value = module.linode_nodes.nodes
}

output "aws_nodes" {
  value = module.aws_nodes.nodes
}

output "generic_nodes" {
  value = module.generic_nodes.nodes
}

output "all_nodes" {
  value = concat(
    module.vultr_nodes.nodes,
    module.digitalocean_nodes.nodes,
    module.linode_nodes.nodes,
    module.aws_nodes.nodes,
    module.generic_nodes.nodes
  )
}
