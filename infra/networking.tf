# Includes all networking-related resources:
# - google_compute_network
# - google_compute_global_address
# - google_service_networking_connection
# - google_vpc_access_connector

# Creates a Virtual Private Cloud (VPC) network, serves as the foundational networking layer for the project. All other networking components, like subnets, access connectors, and service connections, will be associated with this VPC.
resource "google_compute_network" "main" {
  provider                = google-beta
  name                    = "${var.deployment_name}-private-network"
  auto_create_subnetworks = true
  project                 = var.project_id
}

# Reserves an internal global IP address range for VPC peering, facilitating communication between Google Cloud services and the VPC network.
resource "google_compute_global_address" "main" {
  name          = "${var.deployment_name}-vpc-address"
  provider      = google-beta
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.name
  project       = var.project_id
}

# Establishes a VPC peering connection between the VPC network and Google managed services, enabling secure internal traffic flow to services like Cloud SQL and Redis.
resource "google_service_networking_connection" "main" {
  network                 = google_compute_network.main.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.main.name]
}

# Provides serverless VPC access, enabling Cloud Run services to connect securely to resources within the VPC, such as internal databases or services.
resource "google_vpc_access_connector" "main" {
  provider       = google-beta
  project        = var.project_id
  name           = "${var.deployment_name}-vpc-cx"
  ip_cidr_range  = "10.8.0.0/28"
  network        = google_compute_network.main.name
  region         = var.region
  max_throughput = 300
}
