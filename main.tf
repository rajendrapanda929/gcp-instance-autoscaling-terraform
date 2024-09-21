provider "google" {
  project = "assignment-4-project-435017"
  region  = "us-central1"
}

# Define the instance template
resource "google_compute_instance_template" "app_template" {
  name           = "app-instance-template"
  machine_type   = "e2-medium"
  region         = "us-central1"
  tags           = ["http-server"]
  
  # Define the source image for your instances
  disk {
    auto_delete  = true
    boot         = true
    source_image = "debian-cloud/debian-11"
  }

  network_interface {
    network = "default"
    access_config {}
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create a Managed Instance Group
resource "google_compute_instance_group_manager" "app_group" {
  name               = "app-instance-group"
  base_instance_name = "app-instance"
  zone               = "us-central1-a"
  version {
    instance_template = google_compute_instance_template.app_template.id
  }
  target_size = 2
  named_port {
    name = "http"
    port = 80
  }
}

# Add Autoscaler to Instance Group
resource "google_compute_autoscaler" "app_autoscaler" {
  name    = "app-instance-autoscaler"
  zone    = "us-central1-a"
  target  = google_compute_instance_group_manager.app_group.self_link

  autoscaling_policy {
    max_replicas = 5
    min_replicas = 2

    cpu_utilization {
      target = 0.1 # Target CPU utilization, 10%
    }
  }
}

# Firewall to allow HTTP traffic
resource "google_compute_firewall" "default" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  
  source_tags = ["web"]
  target_tags = ["http-server"]
}

# Global HTTP Load Balancer Backend Service
resource "google_compute_backend_service" "default" {
  name        = "app-backend-service"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 10
  health_checks = [google_compute_health_check.default.self_link]
  backend {
    group = google_compute_instance_group_manager.app_group.instance_group
  }
}

# Health Check for Load Balancer
resource "google_compute_health_check" "default" {
  name               = "http-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3
  http_health_check {
    port = 80
    request_path = "/"
  }
}

# URL Map for Load Balancer
resource "google_compute_url_map" "default" {
  name            = "app-url-map"
  default_service = google_compute_backend_service.default.self_link
}

# Target HTTP Proxy for Load Balancer
resource "google_compute_target_http_proxy" "default" {
  name   = "app-http-proxy"
  url_map = google_compute_url_map.default.self_link
}

# Global Forwarding Rule to route traffic to Load Balancer
resource "google_compute_global_forwarding_rule" "default" {
  name       = "app-forwarding-rule"
  target     = google_compute_target_http_proxy.default.self_link
  port_range = "80"
}
