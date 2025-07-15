# Installs ARR (reverse proxy) using Web Platform Installer

# Install IIS
Install-WindowsFeature -Name Web-Server, Web-WebSockets, Web-Mgmt-Tools -IncludeAllSubFeature

# Download and install WMI Exporter
Invoke-WebRequest -Uri "https://github.com/prometheus-community/windows_exporter/releases/download/v0.24.0/windows_exporter-0.24.0-amd64.msi" -OutFile "C:\windows_exporter.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/I C:\windows_exporter.msi /quiet'

# Enable and start the service
Start-Service windows_exporter
Set-Service windows_exporter -StartupType Automatic

# Install WebPI
Invoke-WebRequest -Uri "https://aka.ms/webpicmd" -OutFile "WebPI.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/I WebPI.msi /quiet'

# Install ARR via WebPI
& "$Env:ProgramFiles\Microsoft\Web Platform Installer\WebpiCmd.exe" /Install /Products:ARRv3_0 /AcceptEula

Write-Host "✅ ARR Reverse Proxy installed."