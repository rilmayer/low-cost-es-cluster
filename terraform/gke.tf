resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.location

  remove_default_node_pool = true
  initial_node_count       = 1

  network = var.network

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

# If you want to assure least one node working
# resource "google_container_node_pool" "primary_nodes" {
#   name       = "${var.cluster_name}-nodes"
#   location   = var.location
#   cluster    = google_container_cluster.primary.name
#   node_count = var.primary_node_count
# 
#   management {
#     auto_repair = true
#   }
# 
#   node_config {
#     machine_type = var.machine_type
#     disk_type    = "pd-standard"
#     disk_size_gb = var.disk_size
#     
#     oauth_scopes = [
#       "https://www.googleapis.com/auth/devstorage.read_only",
#       "https://www.googleapis.com/auth/logging.write",
#       "https://www.googleapis.com/auth/monitoring",
#       "https://www.googleapis.com/auth/service.management.readonly",
#       "https://www.googleapis.com/auth/servicecontrol",
#       "https://www.googleapis.com/auth/trace.append",
#     ]
#   }
# }


resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "${var.cluster_name}-preemptible-nodes"
  location   = var.location
  cluster    = google_container_cluster.primary.name
  node_count = var.primary_preemptible_nodes

  management {
    auto_repair = true
  }

  node_config {
    preemptible  = true
    machine_type = var.machine_type_preemptible
    disk_type    = "pd-standard"
    disk_size_gb = var.disk_size

    # Need for connecting firewall configs
    # service_account = data.google_compute_default_service_account.default.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }
}

resource "google_compute_firewall" "default" {
  name    = "http-https-allow"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  allow {
    protocol = "udp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  # source_service_accounts = [data.google_compute_default_service_account.default.email]
}
