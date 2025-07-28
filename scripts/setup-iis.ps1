# Installs IIS and WMI Exporter
Write-Host "Installing IIS..."
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Detect hostname
$hostname = $env:COMPUTERNAME
$htmlContent = @"
<!DOCTYPE html>
<html>
<head><title>$hostname</title></head>
<body><h1>This is $hostname</h1></body>
</html>
"@

# Overwrite default IIS homepage
$htmlContent | Out-File -Encoding UTF8 -FilePath "C:\inetpub\wwwroot\index.html"

# Download and install WMI Exporter
Write-Host "Installing WMI Exporter..."
Invoke-WebRequest -Uri "https://github.com/prometheus-community/windows_exporter/releases/download/v0.24.0/windows_exporter-0.24.0-amd64.msi" -OutFile "C:\windows_exporter.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/I C:\windows_exporter.msi /quiet'

# Enable and start the service 
Start-Service windows_exporter
Set-Service windows_exporter -StartupType Automatic

# Enable and configure WinRM
#Write-Host "Configuring WinRM..."
#winrm quickconfig -force
#winrm set winrm/config/service/auth '@{Basic="true"}'
#winrm set winrm/config/service '@{AllowUnencrypted="true"}'

Write-Host "✅ IIS, HTML homepage, and WMI Exporter setup complete."
