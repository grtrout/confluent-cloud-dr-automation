# Confluent Cloud Disaster Recovery Automation

This repository contains **Terraform configurations** that automate the setup of a **Disaster Recovery (DR)** environment in **Confluent Cloud**. It provisions all necessary components including environments, Kafka clusters, Schema Registries, service accounts, API keys, and cluster links across multiple regions, ensuring a complete DR solution from scratch.

## Key Features

- **Modular Configuration**: Terraform code is organized into separate `.tf` files (`providers.tf`, `environments.tf`, `clusters.tf`, etc.) to keep each concern (e.g., Kafka clusters, service accounts, role bindings) logically separated and more maintainable.
- **From-Scratch Deployment**: Running `terraform apply` spins up a fully functional Confluent Cloud DR setup. A subsequent `terraform destroy` removes all resources cleanly.
- **Multi-Region Support**: The configuration provisions resources in two regions to facilitate disaster recovery scenarios.
- **Schema Registry Readiness**: Includes a short delay to ensure Schema Registry instances are fully online before subsequent resources depend on them.
- **Flexible Environment Selection for Python Apps**: Producer/Consumer Python scripts can run with no arguments (default `.env`) or a single argument (`east` or `west`) to load the respective environment configuration.

## Usage

### Prerequisites

1. **Terraform** installed on your local machine or CI environment.  
   Download it from: https://www.terraform.io/downloads.html  
2. **Confluent Cloud API credentials** (API Key and Secret) with appropriate `OrganizationAdmin` permissions.
3. **Python dependencies**  
   Install the required Python packages using the following command:  
   ```bash
   pip install "confluent-kafka[avro]" "python-dotenv"
   ```

### Steps

1. **Clone this repository**:
   ```bash
   git clone https://github.com/grtrout/confluent-cloud-dr-automation confluent-cloud-dr-automation
   cd confluent-cloud-dr-automation
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Configure Variables**:
   Copy the example variable file and update it with your Confluent Cloud details:
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```
   Edit `terraform/terraform.tfvars` to set your API keys, regions, and cluster settings. Ensure that the provided API key has **OrganizationAdmin** permissions to allow Terraform to create and manage all required resources.

4. **Review the execution plan**:
   ```bash
   terraform plan
   ```
   This command generates and displays a detailed plan of all the resources that Terraform will create, modify, or destroy. Review the plan to ensure accuracy before proceeding.

5. **Apply the Configuration**:
   ```bash
   terraform apply
   ```
   Terraform will display the execution plan again and prompt you to confirm. Type `yes` to proceed with the creation of resources.

6. **Destroy the Infrastructure (when no longer needed)**:
   ```bash
   terraform destroy
   ```
   This removes all Confluent Cloud resources previously created.

### Generate Environment Files

After Terraform completes, you can run an **optional script** (e.g., `generate_envs.sh`) to create `east.env` and `west.env` from Terraform outputs. These files contain the Kafka/SR credentials for each region.

1. **Run Script** (example):
   ```bash
   ./generate_envs.sh
   # Follow the prompts to select an environment (1 for East, 2 for West, or exit)
   ```
2. **Review Generated Files**:
   ```bash
   cat python/east.env
   cat python/west.env
   ```
Ensure that the values for `BOOTSTRAP_SERVER`, `SASL_USERNAME`, `SASL_PASSWORD`, and other required variables are correctly populated.

### Running the Producer & Consumer

Inside the `python/` directory, you have two example scripts:

1. `avro_producer_app.py`  
2. `avro_consumer_app.py`

**Each script can be run** in one of two ways:

- **No argument** → Defaults to `.env`
- **Single argument** (`east` or `west`) → Loads `east.env` or `west.env`

```bash
# 1) Default usage (reads .env)
python avro_producer_app.py
python avro_consumer_app.py

# 2) East usage (explicitly load east.env)
python avro_producer_app.py east
python avro_consumer_app.py east

# 3) West usage (explicitly load west.env)
python avro_producer_app.py west
python avro_consumer_app.py west
```

Alternatively, you can manually copy:
```bash
cp python/east.env python/.env
python avro_producer_app.py
```
Both methods are valid.

### Notes

- Sensitive information (like API secrets) should be placed in `.tfvars` or environment variables and never committed to version control.
- The directory structure is designed to be easily extended with additional `.tf` files or modules for networking, Kafka applications, or other integrations.
- If you modify `avro_producer_app.py` or `avro_consumer_app.py` to be executable (`chmod +x`), ensure they have a proper shebang (`#!/usr/bin/env python3`) at the top.

## Planned Enhancements

- **Advanced DR Demonstration**: Develop scripts to simulate regional outages and demonstrate automated failover and failback processes.

