# Azure Infrastructure as Code Project

This project provisions a basic Azure infrastructure using Terraform. It includes a resource group, virtual network, multiple subnets, network security groups (NSGs), public IP, and several virtual machines for frontend, backend, proxy, and monitoring purposes.

## Project Structure

- **main.tf**: Core resources (resource group, virtual network, subnets)
- **nsg.tf**: Network Security Groups and their rules
- **nsg-association.tf**: Associates NSGs with subnets
- **public-ip.tf**: Public IP resource for the proxy VM
- **vms.tf**: Network interfaces and virtual machines (Windows and Linux)
- **variables.tf**: Input variables for customization
- **outputs.tf**: Useful outputs after deployment
- **terraform.tfvars**: Variable values (e.g., admin password)
- **provider.tf**: Provider configuration
- **backend.tf**: (Reserved for remote state configuration)

## Resources Deployed

- **Resource Group**: `rg-internship`
- **Virtual Network**: `vnet01` (`10.0.0.0/16`)
- **Subnets**:
  - `frontend-subnet` (`10.0.1.0/24`)
  - `backend-subnet` (`10.0.2.0/24`)
  - `monitoring-subnet` (`10.0.3.0/24`)
  - `gateway-subnet` (`10.0.254.0/27`)
- **Network Security Groups**:
  - Frontend: Allows HTTP (80) and RDP (3389)
  - Backend: Allows HTTP (80)
  - Monitoring: Allows SSH (22)
- **Virtual Machines**:
  - Proxy VM (Windows)
  - Monitoring VM (Linux)
  - Two IIS VMs (Windows)
- **Public IP**: For proxy VM

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- Azure subscription and credentials (e.g., via `az login`)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (optional, for authentication)

## Usage

1. **Authenticate with Azure**

   ```sh
   az login
   ```

2. **Initialize Terraform**

   ```sh
   terraform init
   ```

3. **Review and customize variables**  
   Edit [`terraform.tfvars`](terraform.tfvars) or override variables via CLI.

4. **Plan the deployment**

   ```sh
   terraform plan
   ```

5. **Apply the configuration**

   ```sh
   terraform apply
   ```

6. **Destroy the resources (when done)**
   ```sh
   terraform destroy
   ```

## Security

- **Passwords**: The admin password is stored in [`terraform.tfvars`](terraform.tfvars). For production, use [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/) or environment variables.
- **NSG Rules**: Review and restrict NSG rules as needed for your security requirements.

## Outputs

After deployment, Terraform will output resource names, subnet prefixes, public IP, and VM details as defined in [`outputs.tf`](outputs.tf).

## Notes

- The backend for remote state is not configured. Edit [`backend.tf`](backend.tf) to enable remote state storage (e.g., Azure Storage Account).
- The project uses AzureRM provider version `~> 3.0` (see [`provider.tf`](provider.tf)).

## License

This project is licensed
