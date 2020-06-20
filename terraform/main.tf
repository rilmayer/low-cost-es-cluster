terraform {
  required_version = "~>0.12.14"
}

provider "google" {
  project = "${var.project}"
  region  = "${var.region}"
}
