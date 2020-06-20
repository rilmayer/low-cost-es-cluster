variable "project" {}

variable "region" {
  default = "asia-northeast1"
}

variable "location" {
  default = "asia-northeast1-a"
}

variable "cluster_name" {
  default = "es-cluster"
}

variable "network" {
  default = "default"
}

variable "primary_node_count" {
  default = "1"
}

variable "primary_preemptible_nodes" {
  default = "2"
}

variable "machine_type" {
  default = "e2-small"
}

variable "disk_size" {
  default = "20"
}
