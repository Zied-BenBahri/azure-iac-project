# 🌐 Azure Hybrid Infrastructure – IaC with Terraform

This project implements a **hybrid cloud infrastructure** on **Microsoft Azure**, fully automated with **Terraform (Infrastructure as Code)**.  
It hosts a **.NET Blazor web application** on **IIS servers** while maintaining a secure connection to an **on-premises SQL Server** via **VPN Gateway**.  
The infrastructure also includes a **monitoring stack** based on **Prometheus** and **Grafana**.

---

## 🧱 Project Overview

The solution was developed as part of my summer internship.

- Replicate an on-premises architecture in Azure using **Terraform**
- Deploy two **Windows IIS VMs** behind a **Standard Load Balancer**
- Connect them securely to an **on-prem SQL Server** using **VPN Gateway**
- Implement **monitoring and observability** using Prometheus and Grafana
- Follow **DevOps and IaC principles** for scalability, reusability, and automation

---

## Architecture Diagram

## ![Azure Infrastructure Architecture](docs/internship-rg.jpg)

## 🧩 Architecture Overview

This deployment follows a **two-phase automation model**:

1. **Infrastructure Provisioning** – Automated creation of all Azure resources using Terraform.
2. **Configuration Management** – Automated configuration of VMs and application deployment through Custom Script Extensions.

### Components

- **Resource Group:** `rg-internship`
- **Virtual Network:** `vnet01` (`10.0.0.0/16`)
- **Subnets:**
  - `backend-subnet` (`10.0.2.0/24`) – IIS servers
  - `monitoring-subnet` (`10.0.3.0/24`) – Prometheus + Grafana
  - `GatewaySubnet` (`10.0.254.0/27`) – VPN Gateway

---

## ⚙️ Project Structure

| File / Folder                       | Description                                                          |
| ----------------------------------- | -------------------------------------------------------------------- |
| **main.tf**                         | Resource group, virtual network, and subnets                         |
| **nsg.tf**                          | Network Security Groups and inbound/outbound rules                   |
| **nsg-association.tf**              | NSG associations with subnets                                        |
| **lb.tf**                           | Load balancer configuration (frontend, backend, health probe, rules) |
| **public-ip.tf**                    | Public IPs for VMs, load balancer, and monitoring VM                 |
| **vms.tf**                          | Virtual machines (Windows IIS + Linux monitoring)                    |
| **extensions.tf**                   | VM extensions for automatic configuration (scripts)                  |
| **vpn.tf**                          | VPN Gateway for hybrid connectivity with on-prem server              |
| **variables.tf / terraform.tfvars** | Input variables and credentials                                      |
| **outputs.tf**                      | Terraform outputs after deployment                                   |
| **scripts/**                        | PowerShell and Bash scripts for automation                           |
| **docs/**                           | Diagrams and supporting visuals                                      |

---

## 🔐 Network Security Groups (NSGs)

| NSG                | Allowed Ports                                                       | Description                |
| ------------------ | ------------------------------------------------------------------- | -------------------------- |
| **Backend NSG**    | 80 (HTTP), 443 (HTTPS), 3389 (RDP), 9182 (WMI), 1433 (SQL outbound) | Web and monitoring traffic |
| **Monitoring NSG** | 22 (SSH), 3000 (Grafana), 9090 (Prometheus)                         | Linux monitoring access    |

---

## ⚖️ Load Balancer Configuration

- **Name:** `web-load-balancer`
- **Type:** Standard (Layer 4)
- **Frontend:** Static public IP
- **Backend Pool:** `vm-iis-01`, `vm-iis-02`
- **Health Probe:** HTTP on port 80
- **Load Balancing Rule:** Port 80 → HTTP traffic distribution

---

## 🖥️ Virtual Machines

| VM             | OS                  | Role       | Description          |
| -------------- | ------------------- | ---------- | -------------------- |
| **vm-iis-01**  | Windows Server 2022 | IIS Host   | Blazor Web App       |
| **vm-iis-02**  | Windows Server 2022 | IIS Host   | Blazor Web App       |
| **vm-monitor** | Ubuntu 22.04 LTS    | Monitoring | Prometheus + Grafana |

---

## 🔗 VPN Gateway

- **Purpose:** Secure communication between Azure and on-prem SQL Server
- **Type:** Route-based (VpnGw1 SKU)
- **Configuration:** Supports both Site-to-Site and Point-to-Site connections
- **Client Pool:** `172.16.0.0/24`

---

## 🧭 Deployment Workflow

### Phase 1 – Infrastructure Deployment (Terraform)

```bash
az login
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Phase 2 – VM Configuration and Application Deployment

Executed automatically via **Custom Script Extensions**:

- Install IIS + ASP.NET Core Hosting Bundle
- Deploy Blazor application
- Configure WMI Exporter (for Prometheus)
- Set connection to on-prem SQL Server
- Apply NSG and firewall rules

---

## 📊 Monitoring and Observability

- **Prometheus:** Scrapes metrics from Windows VMs via WMI Exporter
- **Grafana:** Visualizes metrics (CPU, memory, disk, HTTP uptime, etc.)
- **Dashboard Example:**  
  ![Grafana Dashboard](docs/grafana-dashboard.png)

---

## 🧰 Tools and Technologies

| Category           | Tools / Technologies              |
| ------------------ | --------------------------------- |
| **Cloud Provider** | Microsoft Azure                   |
| **IaC Tool**       | Terraform                         |
| **Automation**     | PowerShell & Bash                 |
| **Web Hosting**    | IIS + ASP.NET Core                |
| **Database**       | Microsoft SQL Server (on-prem)    |
| **Monitoring**     | Prometheus, Grafana, WMI Exporter |
| **VPN**            | Azure VPN Gateway                 |
| **DevOps**         | Azure DevOps Pipelines (planned)  |

---

## 🚀 Key Achievements

- Built a **fully automated hybrid Azure environment**
- Successfully deployed and load-balanced a **.NET web application**
- Established secure **VPN connectivity** with on-prem SQL Server
- Implemented **real-time monitoring dashboards**
- Debugged critical issues such as:
  - IIS `500.30` runtime error (runtime mismatch)
  - VPN certificate validation and connection setup
  - Terraform state conflicts (resolved using `--target` flag)

---

## 🔒 Security Highlights

- Restricted public access via NSGs
- Private communication via VPN tunnel
- SQL Authentication secured with encryption
- Admin credentials handled via `terraform.tfvars` (recommend using Azure Key Vault in production)

---

## 🧠 Future Improvements

- Implement full CI/CD using **Azure DevOps Pipelines**
- Add HTTPS with Azure-managed certificates
- Enable remote Terraform backend (Azure Blob)
- Automate backup and alerting in Grafana

---
