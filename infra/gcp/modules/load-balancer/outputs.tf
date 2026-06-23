output "lb_ip_address" {
  description = "Global static IP of the load balancer — this is the hosted GCP URL"
  value       = google_compute_global_address.lb_ip.address
}

output "lb_url" {
  description = "HTTP URL of the load balancer"
  value       = "http://${google_compute_global_address.lb_ip.address}"
}
