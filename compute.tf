resource "google_compute_instance" "private-vm" {
  name = "private-vm"
  zone = "europe-west2-b"
  machine_type = "e2-medium"


  allow_stopping_for_update = true


  network_interface {
    #network = "custom_vpc_network"
    subnetwork = google_compute_subnetwork.nw1-subnet2.id
    #access_config {}
  }


    boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20230606"
      size = 20
      
    }


    }


    service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
      email  = "1071111711761-compute@developer.gserviceaccount.com"
      scopes = ["cloud-platform"]
  }


    } 


  resource "google_compute_project_metadata" "my_ssh_key" {
  metadata = {
    ssh-keys = <<EOF
      gcp-user:ssh-rsa AAAAB3NzaC1yc2ggjgjjssiureekFuKAwRR8shshssaB9ehT27MQiTRwK5uBuX4oAT6mggDfFwxC86AmLoS20vuUpFtacw0rc2U8bRLxKlxzIZIo9+8MI5D7RW35vXdKM3AvUBVdFrbnLYmQwi9wiY5fpTj6QPh2YUp1FycbOpAkG4C6OhATRM0pIbD2zE/qNRwR1SkL9a6UCr1ihuZZgf03RV5GP7/dXf4J1yevd6JlMC3jIYs529wyS+7FOecSteCEulzf8JB8AyiqsFo4hJIfpsnhK3Ruf3xTBcaPfnQDJtCUEryXQyorW9HTq2Y6LrCRC7u708er94wgvmgCXcOsVhy2/fhZsqcWxy2DPETjlHV+ZY5P5C9o/Fbu5cvmbd44Q/3nzYjkqMFBTrouDA5Tb72kx6CTLkl/qf7SzR+WcVGjikVtVxUFnn5dJHmcn785W2Af/LacWxtZ4veWWe00ccfv/FC0HiD0xUeHGxGGQJOeaC+oJaOj/h6EsznASx5cn7VI90rtEdUSkvMTQLSkiRN06Y/fg5HyeHIjNTojbRgwuOYLxkZUGVDzkuwlaxCkporVoLuiR4XupBdBcKwyiIkM4UhTwcgMhm8trmAT6A9hMhEn4N7bz68ShOUVjwnAXCE6TWOVN7rjrInUPxyS1HTSTF33ZxLL9MSPPs1D291pxvJ6QvPJQ== gcp-user
    EOF
  }
}   


