output "load_balancer_ip" {
  description = "The external IP of the Load Balancer"
  value       = google_compute_global_forwarding_rule.default.ip_address
}
