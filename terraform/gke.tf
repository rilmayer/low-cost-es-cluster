resource "google_container_cluster" "primary" {
  name     = "${var.cluster_name}"
  location = "${var.location}"

  remove_default_node_pool = true
  initial_node_count       = 1

  network = "${var.network}"

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-${var.cluster_name}-nodes"
  location   = "${var.location}"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = "${var.primary_node_count}"

  management {
    auto_repair = true
  }

  node_config {
    machine_type = "${var.machine_type}"
    disk_type    = "pd-ssd"
    disk_size_gb = "${var.disk_size}"
    
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


resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "primary-preemptible-${var.cluster_name}-nodes"
  location   = "${var.location}"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = "${var.primary_preemptible_nodes}"

  management {
    auto_repair = true
  }

  node_config {
    preemptible  = true
    machine_type = "${var.machine_type}"
    disk_type    = "pd-ssd"
    disk_size_gb = "${var.disk_size}"

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