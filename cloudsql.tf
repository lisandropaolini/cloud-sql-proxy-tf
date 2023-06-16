resource "google_sql_database_instance" "mysql-from-tf"{
  name = "cloud-mysql"
  region = "us-central1"
  deletion_protection = false
  database_version = "MYSQL_8_0"
  depends_on       = [google_service_networking_connection.private_vpc_connection]
  
  settings {
    tier = "db-n1-standard-1"
    availability_type = "REGIONAL"
    #tier = "db-custom-2-6144"
    disk_size = 20
    disk_type = "PD_SSD"


     backup_configuration {


      binary_log_enabled = true
                 enabled = true
        
    } 



    ip_configuration {


      ipv4_enabled    = false
      private_network = google_compute_network.nw1-vpc.self_link
       
    } 
   
  }


}


resource "google_sql_database" "database" {
name = "quickstart_db"
instance = "${google_sql_database_instance.mysql-from-tf.name}"
charset = "utf8"
collation = "utf8_general_ci"
}


resource "google_sql_user" "users" {
  name = "root"
  password = "Abcd1234"
  host = "%"
  instance = "${google_sql_database_instance.mysql-from-tf.name}"
}  
