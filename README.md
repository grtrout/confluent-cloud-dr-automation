# Confluent Cloud Disaster Recovery Automation

This repository automates the setup and management of a multi-region Kafka disaster recovery (DR) environment on Confluent Cloud. Using Terraform to provision clusters, Schema Registries, service accounts, API keys, and more, it provides automated scripts for failover, failback, status checking, and outage simulation.

## Key Features

- **Fully Automated DR Setup:**  
  Deploy a multi-region disaster recovery environment with a single `terraform apply`.

- **Modular Terraform Configurations:**  
  Organized Terraform files (e.g., `providers.tf`, `environments.tf`, `clusters.tf`, etc.) that separate concerns and simplify maintenance.

- **Automated DR Operations:**  
  - **Failover:** Switch the primary cluster from East to West using `dr_failover.sh`.  
  - **Failback:** Revert the primary cluster from West back to East using `dr_failback.sh`.  
  - **Status Check:** Use `dr_status.sh` to display mirror topic statuses and simulated outages.  
  - **Outage Simulation & Restoration:** Simulate cluster outages via DENY ACLs with `simulate_outage.sh` and restore normal access with `restore_access.sh`.

- **Dynamic Client Configuration:**  
  Example Python applications (producer and consumer) load region-specific configuration from environment files (`east.env` and `west.env`), which can be generated via `generate_env.sh`.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html)
- Confluent Cloud API credentials with OrganizationAdmin permissions.
- [Confluent CLI](https://docs.confluent.io/confluent-cli/current/install.html) (logged in via `confluent login`).
- Python 3 and required packages:
  ```bash
  pip install "confluent-kafka[avro]" "python-dotenv"
  ```

## Setup & Deployment

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/grtrout/confluent-cloud-dr-automation.git
   cd confluent-cloud-dr-automation
   ```

2. **Configure Terraform:**
   - Copy and update the example variables file:
     ```bash
     cp terraform/terraform.tfvars.example terraform/terraform.tfvars
     ```
   - Edit the file with your Confluent Cloud details (API keys, regions, cluster settings).

3. **Deploy the Environment:**
   - Initialize Terraform:
     ```bash
     terraform init
     ```
   - Review the plan:
     ```bash
     terraform plan
     ```
   - Apply the configuration:
     ```bash
     terraform apply
     ```
   - To tear down later:
     ```bash
     terraform destroy
     ```

4. **Generate Environment Files:**
   - Create `east.env` and `west.env` with:
     ```bash
     ./generate_env.sh
     ```
   - Optionally, activate one environment as the default `.env` when prompted.

## Disaster Recovery Operations

Use the provided scripts to manage DR activities:

- **Failover to West:**
  ```bash
  ./dr_failover.sh
  ```
- **Failback to East:**
  ```bash
  ./dr_failback.sh
  ```
- **Check DR Status:**
  ```bash
  ./dr_status.sh
  ```
- **Simulate Outage:**
  ```bash
  ./simulate_outage.sh
  ```
- **Restore Access:**
  ```bash
  ./restore_access.sh
  ```

Each script includes interactive prompts and clear instructions for execution.

## Python Example Applications

In the `python/` directory, you’ll find sample apps:

- **Producer:** `avro_producer_app.py`
- **Consumer:** `avro_consumer_app.py`

Run them with no arguments (to use the default `.env`) or with an argument (`east` or `west`) to explicitly load that environment:
```bash
python avro_producer_app.py east
python avro_consumer_app.py east
```

## Notes

- **Security:** Ensure sensitive files (like `.tfvars` and environment files) are not committed to version control.
- **Extensibility:** The project structure is designed to be easily extended with additional Terraform modules or application integrations.

