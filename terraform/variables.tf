variable "project" {}

# low cost region
variable "region" {
  default = "us-central1"
}

# low cost location
variable "location" {
  default = "us-central1-a"
}

variable "cluster_name" {
  default = "es-cluster"
}

variable "network" {
  default = "default"
}

# primary_nodes settings
variable "primary_node_count" {
  default = "1"
}

variable "machine_type" {
  default = "e2-small"
}


# primary_preemptible_nodes settings
variable "primary_preemptible_nodes" {
  default = "3"
}

variable "machine_type_preemptible" {
  default = "e2-medium"
}

variable "disk_size" {
  default = "15"
}

data "google_compute_default_service_account" "default" {
}
