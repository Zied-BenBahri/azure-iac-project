# Installs ARR (reverse proxy) using Web Platform Installer

# Install IIS
Install-WindowsFeature -Name Web-Server, Web-WebSockets, Web-Mgmt-Tools -IncludeAllSubFeature

# Install WebPI
Invoke-WebRequest -Uri "https://aka.ms/webpicmd" -OutFile "WebPI.msi"
Start-Process msiexec.exe -Wait -ArgumentList '/I WebPI.msi /quiet'

# Install ARR via WebPI
& "$Env:ProgramFiles\Microsoft\Web Platform Installer\WebpiCmd.exe" /Install /Products:ARRv3_0 /AcceptEula

Write-Host "✅ ARR Reverse Proxy installed."