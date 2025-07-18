# Azure Infrastructure as Code Project

This project provisions a robust Azure infrastructure using Terraform. It includes a resource group, virtual network, multiple subnets, network security groups (NSGs), a load balancer, public IPs, and several virtual machines for backend, monitoring, and IIS web servers.

## Project Structure

- **main.tf**: Core resources (resource group, virtual network, subnets)
- **nsg.tf**: Network Security Groups and their rules
- **nsg-association.tf**: Associates NSGs with subnets and backend address pools with NICs
- **lb.tf**: Load balancer configuration (frontend, backend pool, probes, and rules)
- **public-ip.tf**: Public IP resources for the load balancer and monitoring VM
- **vms.tf**: Network interfaces and virtual machines (Windows and Linux)
- **extensions.tf**: VM extensions for IIS setup and monitoring
- **variables.tf**: Input variables for customization
- **outputs.tf**: Useful outputs after deployment
- **terraform.tfvars**: Variable values (e.g., admin password)
- **provider.tf**: Provider configuration
- **backend.tf**: (Reserved for remote state configuration)
- **scripts/**: Contains setup scripts for IIS and monitoring tools
- **docs/**: Contains architecture diagrams and documentation assets

## Resources Deployed

### Core Resources

- **Resource Group**: `rg-internship`
- **Virtual Network**: `vnet01` (`10.0.0.0/16`)

### Subnets

- `backend-subnet` (`10.0.2.0/24`)
- `monitoring-subnet` (`10.0.3.0/24`)
- `gateway-subnet` (`10.0.254.0/27`)

### Network Security Groups (NSGs)

- **Backend NSG**: Allows HTTP (80), RDP (3389), and WMI Exporter (9182)
- **Monitoring NSG**: Allows SSH (22) and Grafana (3000)

### Load Balancer

- **Name**: `web-load-balancer`
- **Frontend Configuration**: Static public IP
- **Backend Pool**: Includes IIS VMs
- **Health Probe**: HTTP probe on port 80
- **Rule**: HTTP traffic on port 80

### Virtual Machines

- **Monitoring VM**: Linux VM with Prometheus and Grafana
- **IIS VMs**: Two Windows VMs with IIS and WMI Exporter installed

### Public IPs

- **Load Balancer Public IP**: Static IP for the load balancer
- **Monitoring Public IP**: Dynamic IP for the monitoring VM

## Architecture Diagram

![Azure Infrastructure Architecture](docs/rg-internship.png)

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
   terraform apply -var-file="terraform.tfvars"
   ```

6. **Destroy the resources (when done)**

   ```sh
   terraform destroy -var-file="terraform.tfvars"
   ```

## Security

- **Passwords**: The admin password is stored in [`terraform.tfvars`](terraform.tfvars). For production, use [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/) or environment variables.
- **NSG Rules**: Review and restrict NSG rules as needed for your security requirements.

## Outputs

After deployment, Terraform will output resource names, subnet prefixes, public IPs, and VM details as defined in [`outputs.tf`](outputs.tf).

## Notes

- The backend for remote state is not configured. Edit [`backend.tf`](backend.tf) to enable remote state storage (e.g., Azure Storage Account).
- The project uses AzureRM provider version `~> 3.0` (see [`provider.tf`](provider.tf)).

## License

This project is licensed under the [MIT License](LICENSE).
