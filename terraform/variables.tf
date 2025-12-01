variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-gitops-demo"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "uksouth"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-gitops-cluster"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "VM size for nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}
