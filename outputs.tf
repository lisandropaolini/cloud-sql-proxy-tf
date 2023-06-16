output "private_vm_ip"{
  value = google_compute_instance.private-vm.network_interface.0.network_ip
}


output "private_ip_address_cloudsql" {
    value       = google_sql_database_instance.mysql-from-tf.private_ip_address
    description = "The private IP address of the newly created My SQL"
} 


output "natgw_public_ip_address" {
    value       = google_compute_address.natpip.address
    description = "The public IP address of the newly created Nat Gateway"
}
