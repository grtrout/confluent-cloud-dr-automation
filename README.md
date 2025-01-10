# Confluent Cloud Disaster Recovery Automation

This repository contains Terraform configurations to automate the setup of a **Disaster Recovery (DR)** environment in **Confluent Cloud** from scratch. The project is designed to provision all necessary resources, including environments, Kafka clusters, Schema Registry instances, service accounts, API keys, and cluster links, ensuring a complete DR solution.

## Key Features

- **From-Scratch Deployment**: All resources are created from the ground up. Running `terraform apply` provisions a fully functional Confluent Cloud DR setup. Similarly, `terraform destroy` removes all resources, leaving no residual configurations.
- **Multi-Region Support**: The setup spans multiple regions to provide a robust DR strategy.
- **Schema Registry Readiness**: Includes a 30-second delay to ensure Schema Registry instances are fully provisioned before dependent configurations are applied.

## Usage

### Prerequisites

1. Ensure you have Terraform installed.
2. Set up Confluent Cloud credentials with appropriate privileges:
   - API Key and Secret with organization-level permissions.

### Steps

1. Clone this repository:
   ```bash
   git clone <repository-url> confluent-cloud-dr-automation
   cd confluent-cloud-dr-automation
   ```
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Review and edit `variables.tf` and/or `terraform.tfvars` as needed for your setup.
4. Apply the configuration to create all resources:
   ```bash
   terraform apply
   ```
5. To destroy all resources:
   ```bash
   terraform destroy
   ```

### Notes

- This project currently only includes Terraform configurations.
- Sensitive variables such as API keys should be provided via `.tfvars` files or environment variables and are excluded from version control using `.gitignore`.

## Planned Enhancements

- Integration of Python applications to demonstrate client failover, failback, and other critical DR workflows as part of the disaster recovery strategy.
