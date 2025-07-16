#!/bin/bash

set -e

echo "🔧 Updating system..."
sudo apt update -y && sudo apt upgrade -y

echo "📦 Installing dependencies..."
sudo apt install -y wget curl gnupg unzip software-properties-common

# -------- PROMETHEUS --------
echo "📥 Downloading Prometheus..."
cd /opt
sudo useradd --no-create-home --shell /bin/false prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar xvf prometheus-2.52.0.linux-amd64.tar.gz
sudo mv prometheus-2.52.0.linux-amd64 prometheus

# Create Prometheus config file
echo "⚙️ Creating Prometheus config..."
sudo tee /opt/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'windows-vms'
    static_configs:
      - targets: ['10.0.2.4:9182', '10.0.2.5:9182']
EOF

# Set permissions
sudo chown -R prometheus:prometheus /opt/prometheus

# Create Prometheus service
echo "🛠️ Creating Prometheus systemd service..."
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable --now prometheus

# -------- GRAFANA --------
echo "📥 Installing Grafana..."
sudo apt install -y apt-transport-https
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://apt.grafana.com/gpg.key | sudo tee /etc/apt/keyrings/grafana.key > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update
sudo apt install -y grafana

echo "🚀 Starting Grafana..."
sudo systemctl enable --now grafana-server

echo "✅ Monitoring setup complete! Access Grafana at http://<public-ip>:3000"
