resource "google_service_account" "cloudsql-sa"{ 
  account_id   = "cloudsql-sa"
  display_name = "Service Account for Cloud SQL"
}


resource "google_project_iam_member" "member-role" {
  for_each = toset([
     "roles/cloudsql.client",
     "roles/cloudsql.editor",
     "roles/cloudsql.admin",
     "roles/resourcemanager.projectIamAdmin"
  ]) 
  role = each.key
  project = "terraform-project-2277166"
  member = "serviceAccount:${google_service_account.cloudsql-sa.email}"
}


resource "google_service_account_key" "mykey" {
  service_account_id = google_service_account.cloudsql-sa.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}


resource "local_file" "sa_json_file" {
  content  = base64decode(google_service_account_key.mykey.private_key)
  filename = "${path.module}/cloudsql-sa-key.json"


}
