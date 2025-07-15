# Installs IIS and WMI Exporter

# Install IIS
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Download and install WMI Exporter
Invoke-WebRequest -Uri "https://github.com/prometheus-community/windows_exporter/releases/download/v0.24.0/windows_exporter-0.24.0-amd64.msi" -OutFile "C:\windows_exporter.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/I C:\windows_exporter.msi /quiet'

# Enable and start the service
Start-Service windows_exporter
Set-Service windows_exporter -StartupType Automatic

Write-Host "✅ IIS + WMI Exporter installed."
