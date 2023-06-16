# cloud-sql-proxy-tf

### **Introduction**

While relational databases still offer basic authentication, many of our clients are realizing that this isn’t sufficient or secure enough in today’s complex cloud environments. Some of the commonly stated complaints are lack of two-factor authentication, easier susceptibility to leaked passwords, as well as missing credential rotation capabilities. In order to simplify and secure authorization and authentication into database instances, Google Cloud has developed IAM Database Authentication that supports basic and IAM authentication. Along with this capability, Google released Cloud SQL Auth proxy to provide a secure path for clients to log into their database while eliminating other hurdles.

### **What is Cloud SQL Auth proxy?**

Cloud SQL Auth proxy is used to create secure connections to Cloud SQL database instances. With Cloud SQL Auth proxy, you can specify a database instance connection string and it will handle secure connectivity to the instance for you. The proxy will use automatically-managed short-lived SSL certificates that will ensure that your connectivity is authorized and encrypted. The proxy will then allow you to use Identity and Access Management (IAM) authentication to log into the database by generating an OAuth 2.0 token for your Cloud Identity.

  

With Cloud SQL Auth proxy, you do not have to worry much about setting up authorized networks, managing certificates, and in some cases, worrying about rotating user credentials. Think of it as a secure way to access your Cloud SQL database instances.

### **How the proxy works**

Cloud SQL Auth proxy is a binary that you run on your local client machine. The proxy initiates a connection using a secure tunnel (TLS with 128-bit cipher) to the proxy service running in Cloud SQL. This server-side proxy service then connects to your SQL instance on the outgoing port tcp/3307. If your resource is behind an outgoing firewall rule, ensure that this rule allows tcp/3307 to your Cloud SQL instance.

![No alt text provided for this image](https://media.licdn.com/dms/image/D5612AQF_YdQENe0bJw/article-inline_image-shrink_1500_2232/0/1686585247907?e=1692230400&v=beta&t=N8o97VZ43FkzJ2Jj8n8t5wy9HqgwD_wUEacWhFj1KhQ)

[Cloud SQL service](https://cloud.google.com/sql), the managed database service on Google Cloud, allows you to:

*   Set a [private IP on your instance](https://cloud.google.com/sql/docs/mysql/private-ip) and to connect it directly to the VPC of your choice
*   Remove the [public IP from your instance](https://cloud.google.com/sql/docs/mysql/configure-ip#disable-public)

Thanks to these features, **you can enforce the security team requirements**.

> But, is it a problem when we work day-to-day to not have public IP on Cloud SQL instances?

  

Let’s check this over 3 use cases:

1.  **Compute Engine** connectivity
2.  **Serverless services** connectivity
3.  **Local environment** connectivity

### **Cloud SQL proxy binary**

Before going deeper into the use cases, I would like to perform a quick focus on the main feature of [Cloud SQL proxy](https://cloud.google.com/sql/docs/mysql/sql-proxy)

  

*   This binary opens a **secure and end-to-end encrypted tunnel**. In summary, even if your database don’t have SSL certificate, the data are encrypted in transit.
*   Before opening the tunnel, the binary **checks against the IAM service API if the current credential is authorized to access the Cloud SQL instance**. This is an additional layer of security, in addition to the standard database authentication by user/password.
*   The tunnel can be open on a local port (TCP connection mode) or to a Unix socket (not possible on Windows environment)

### Preparation:

### Step 1 — Install Terraform

wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

$ echo "deb \[signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg\] https://apt.releases.hashicorp.com $(lsb\_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

$ sudo apt update && sudo apt install terraform

**Link:**

https://developer.hashicorp.com/terraform/downloads?ajs\_aid=1938538f-202c-4b2c-9d6c-40ba776ebaab&product\_intent=terraform

### Step 2 — Create terraform .tf Files for Project

**c1-versions.tf**

terraform {
  required\_providers {
    google = {
      source = "hashicorp/google"
      version = "4.68.0"
    }
  }
}


provider "google" {
  # Configuration options
  project = "terraform-project"
  region  = "us-central1"
  zone    = "us-central1-b" 
}

**c2-serviceaccount.tf**

resource "google\_service\_account" "cloudsql-sa"{ 
  account\_id   = "cloudsql-sa"
  display\_name = "Service Account for Cloud SQL"
}


resource "google\_project\_iam\_member" "member-role" {
  for\_each = toset(\[
     "roles/cloudsql.client",
     "roles/cloudsql.editor",
     "roles/cloudsql.admin",
     "roles/resourcemanager.projectIamAdmin"
  \]) 
  role = each.key
  project = "terraform-project-2277166"
  member = "serviceAccount:${google\_service\_account.cloudsql-sa.email}"
}


resource "google\_service\_account\_key" "mykey" {
  service\_account\_id = google\_service\_account.cloudsql-sa.name
  public\_key\_type    = "TYPE\_X509\_PEM\_FILE"
}


resource "local\_file" "sa\_json\_file" {
  content  = base64decode(google\_service\_account\_key.mykey.private\_key)
  filename = "${path.module}/cloudsql-sa-key.json"


}

**c3-network.tf**

resource "google\_compute\_network" "nw1-vpc"{ 
  name                    = "nw1-vpc"
  auto\_create\_subnetworks = false
  mtu                     = 1460
}


resource "google\_compute\_subnetwork" "nw1-subnet1" {
  name = "nw1-vpc-sub1-us-central1"
  network = google\_compute\_network.nw1-vpc.id
  ip\_cidr\_range = "10.10.1.0/24"
  region = "us-central1"
  private\_ip\_google\_access = true


}


resource "google\_compute\_subnetwork" "nw1-subnet2" {
  name = "nw2-vpc-sub3-euro-west2"
  network = google\_compute\_network.nw1-vpc.id
  ip\_cidr\_range = "10.10.2.0/24"
  region = "europe-west2"
  private\_ip\_google\_access = true


}


resource "google\_compute\_firewall" "nw1-ssh-icmp-allow" {
  name = "nw1-vpc-ssh-allow"
  network = google\_compute\_network.nw1-vpc.id
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = \["22"\]
  }
  source\_ranges = \["39.33.11.48/32"\]
  target\_tags = \["nw1-vpc-ssh-allow"\]
  priority = 1000
}



resource "google\_compute\_firewall" "nw1-internal-allow" {
  name = "nw1-vpc-internal-allow"
  network = google\_compute\_network.nw1-vpc.id
  
  allow {
    protocol = "icmp"
  }


  allow {
    protocol = "udp"
    ports    = \["0-65535"\]


  }
  allow {
    protocol = "tcp"
    ports    = \["0-65535"\]
  }
  source\_ranges = \["10.10.0.0/16"\]
  priority = 1100
}


resource "google\_compute\_firewall" "nw1-iap-allow" {
  name = "nw1-vpc-iap-allow"
  network = google\_compute\_network.nw1-vpc.id
  
  allow {
    protocol = "icmp"
  }


  allow {
    protocol = "tcp"
    ports    = \["0-65535"\]
  }
  source\_ranges = \["35.235.240.0/20"\]
  priority = 1200
}



resource "google\_compute\_address" "natpip" {
  name = "ipv4-address"
  region  = "europe-west2"
}


resource "google\_compute\_router" "router1" {
  name    = "nat-router1"
  region  = "europe-west2"
  network = google\_compute\_network.nw1-vpc.id


  bgp {
    asn = 64514
  }
}


resource "google\_compute\_router\_nat" "nat1" {
  name                               = "natgw1"
  router                             = google\_compute\_router.router1.name
  region                             = "europe-west2"
  nat\_ip\_allocate\_option             = "MANUAL\_ONLY"
  nat\_ips                       = \[google\_compute\_address.natpip.self\_link\]
  source\_subnetwork\_ip\_ranges\_to\_nat = "ALL\_SUBNETWORKS\_ALL\_IP\_RANGES"
  min\_ports\_per\_vm                   = 256
  max\_ports\_per\_vm                   = 512


  log\_config {
    enable = true
    filter = "ERRORS\_ONLY"
  }
}



resource "google\_compute\_global\_address" "private\_ip\_address" {
  name          = google\_compute\_network.nw1-vpc.name
  purpose       = "VPC\_PEERING"
  address\_type  = "INTERNAL"
  prefix\_length = 16
  network       = google\_compute\_network.nw1-vpc.name
  
}


resource "google\_service\_networking\_connection" "private\_vpc\_connection" {


  network                 = google\_compute\_network.nw1-vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved\_peering\_ranges = \[google\_compute\_global\_address.private\_ip\_address.name\]


}

**c4-compute.tf**

resource "google\_compute\_instance" "private-vm" {
  name = "private-vm"
  zone = "europe-west2-b"
  machine\_type = "e2-medium"


  allow\_stopping\_for\_update = true


  network\_interface {
    #network = "custom\_vpc\_network"
    subnetwork = google\_compute\_subnetwork.nw1-subnet2.id
    #access\_config {}
  }


    boot\_disk {
    initialize\_params {
      image = "ubuntu-2204-jammy-v20230606"
      size = 20
      
    }


    }


    service\_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
      email  = "1071111711761-compute@developer.gserviceaccount.com"
      scopes = \["cloud-platform"\]
  }


    } 


  resource "google\_compute\_project\_metadata" "my\_ssh\_key" {
  metadata = {
    ssh-keys = <<EOF
      gcp-user:ssh-rsa AAAAB3NzaC1yc2ggjgjjssiureekFuKAwRR8shshssaB9ehT27MQiTRwK5uBuX4oAT6mggDfFwxC86AmLoS20vuUpFtacw0rc2U8bRLxKlxzIZIo9+8MI5D7RW35vXdKM3AvUBVdFrbnLYmQwi9wiY5fpTj6QPh2YUp1FycbOpAkG4C6OhATRM0pIbD2zE/qNRwR1SkL9a6UCr1ihuZZgf03RV5GP7/dXf4J1yevd6JlMC3jIYs529wyS+7FOecSteCEulzf8JB8AyiqsFo4hJIfpsnhK3Ruf3xTBcaPfnQDJtCUEryXQyorW9HTq2Y6LrCRC7u708er94wgvmgCXcOsVhy2/fhZsqcWxy2DPETjlHV+ZY5P5C9o/Fbu5cvmbd44Q/3nzYjkqMFBTrouDA5Tb72kx6CTLkl/qf7SzR+WcVGjikVtVxUFnn5dJHmcn785W2Af/LacWxtZ4veWWe00ccfv/FC0HiD0xUeHGxGGQJOeaC+oJaOj/h6EsznASx5cn7VI90rtEdUSkvMTQLSkiRN06Y/fg5HyeHIjNTojbRgwuOYLxkZUGVDzkuwlaxCkporVoLuiR4XupBdBcKwyiIkM4UhTwcgMhm8trmAT6A9hMhEn4N7bz68ShOUVjwnAXCE6TWOVN7rjrInUPxyS1HTSTF33ZxLL9MSPPs1D291pxvJ6QvPJQ== gcp-user
    EOF
  }
}   


 

**c5-cloudsql.tf**

resource "google\_sql\_database\_instance" "mysql-from-tf"{
  name = "cloud-mysql"
  region = "us-central1"
  deletion\_protection = false
  database\_version = "MYSQL\_8\_0"
  depends\_on       = \[google\_service\_networking\_connection.private\_vpc\_connection\]
  
  settings {
    tier = "db-n1-standard-1"
    availability\_type = "REGIONAL"
    #tier = "db-custom-2-6144"
    disk\_size = 20
    disk\_type = "PD\_SSD"


     backup\_configuration {


      binary\_log\_enabled = true
                 enabled = true
        
    } 



    ip\_configuration {


      ipv4\_enabled    = false
      private\_network = google\_compute\_network.nw1-vpc.self\_link
       
    } 
   
  }


}


resource "google\_sql\_database" "database" {
name = "quickstart\_db"
instance = "${google\_sql\_database\_instance.mysql-from-tf.name}"
charset = "utf8"
collation = "utf8\_general\_ci"
}


resource "google\_sql\_user" "users" {
  name = "root"
  password = "Abcd1234"
  host = "%"
  instance = "${google\_sql\_database\_instance.mysql-from-tf.name}"
}  

**c6-outputs.tf**

output "private\_vm\_ip"{
  value = google\_compute\_instance.private-vm.network\_interface.0.network\_ip
}


output "private\_ip\_address\_cloudsql" {
    value       = google\_sql\_database\_instance.mysql-from-tf.private\_ip\_address
    description = "The private IP address of the newly created My SQL"
} 


output "natgw\_public\_ip\_address" {
    value       = google\_compute\_address.natpip.address
    description = "The public IP address of the newly created Nat Gateway"
}

### Step 3 — Run These Commands

terraform init
terraform validate
terraform plan
terraform apply or terraform apply -auto-approve

### output:

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQH2pw3jWPZd9g/article-inline_image-shrink_1500_2232/0/1686588554204?e=1692230400&v=beta&t=SHAwFNr1zTemwreS5pzlelwJPa8CHtCSnugKzUpK2VE)

### Step 4 — See Resources in Google Cloud

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQEL4c73OQd3XA/article-inline_image-shrink_1500_2232/0/1686586653796?e=1692230400&v=beta&t=WU9KkN7aVtfRwgLVEQWBdCrwS7h1rYBX33Ym6hJlWyw)

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQGEw9L7_HGi-g/article-inline_image-shrink_1500_2232/0/1686587167263?e=1692230400&v=beta&t=oIEmUU_a96T0NQDAhraG81qpZ5cczcuKwH90WmzUdTE)

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQHigVbVn-Ukww/article-inline_image-shrink_1500_2232/0/1686587243181?e=1692230400&v=beta&t=McM1cZA95OuuxsCxlo6Z2t-hjbrMs3GwF3jeRAIVwqY)

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQHjTRgq0dxraQ/article-inline_image-shrink_1500_2232/0/1686587289706?e=1692230400&v=beta&t=a3wqm66JKIaIloZX3bdFDoEERmB_GELk16Cn2vh6tyA)

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQEIdd-L2O-J9w/article-inline_image-shrink_1500_2232/0/1686587342776?e=1692230400&v=beta&t=dZui8PdW3vfIBKSud-5nqs7yH595Av1LisH2o23E6N4)

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQFcLXgN6eK8aw/article-inline_image-shrink_1500_2232/0/1686587691273?e=1692230400&v=beta&t=aEv--MvW7523Q_wT6em5ANRmIePt7qvgQHr7_lOe9cA)

### Step 5 — Install SQL Auth Proxy on Private VM

curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.3.0/cloud-sql-proxy.linux.amd6
chmod +x cloud-sql-proxy4

### Step 6 — Execute Script on Private VM

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQE5qCDBAmd6dA/article-inline_image-shrink_1500_2232/0/1686587533141?e=1692230400&v=beta&t=MspCbLeyP7yENfO0hnw9-mRzffVJMpei_lmL2CQRYqI)

./cloud-sql-proxy --address 0.0.0.0  --port 3306  terraform-project-227766:us-central1:cloud-mysql --private-ip --credentials-file cloudsql-sa-key.json

### Step 7 — Execute IAP on Personal Laptop

You have to configure credentials using gcloud**(gcloud init)** on personal laptop

  

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQHPHzJWBx_Wqg/article-inline_image-shrink_1500_2232/0/1686587795467?e=1692230400&v=beta&t=JzGAVRqH9crBF-PvwD49fIsv8sf9q_ZaVDu4LXcUf10)

gcloud compute start-iap-tunnel private-vm 3306 --zone=europe-west2-b --local-host-port=localhost:3306

authproxy-client = VM name **(private-vm)**

vm location --zone=**europe-west2-b**

### Step 8 — Connect Private Cloud SQL from Local machine

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQEKtxCZ9OyxXw/article-inline_image-shrink_1500_2232/0/1686588036921?e=1692230400&v=beta&t=DLXZcQYMZxU7F_VSJJrrEm8xNqSLCOODl9vYlsdieaw)

Connect from MySQL Workbench

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQGXT9fHMVtR3g/article-inline_image-shrink_1500_2232/0/1686588217042?e=1692230400&v=beta&t=SeEzlOyIAJI17IltyphfUvbcWcbDWKq36YL5ocE7bkI)

![No alt text provided for this image](https://media.licdn.com/dms/image/D4D12AQE09eaRsZHd_A/article-inline_image-shrink_1500_2232/0/1686588297753?e=1692230400&v=beta&t=YGG9OvX9mcWSgHSgP92LoIdti0Kfu58PKDaZlnCPLGc)

