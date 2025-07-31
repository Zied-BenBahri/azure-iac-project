# setup-blazor.ps1

# Install IIS
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Download published app ZIP from blob
Invoke-WebRequest -Uri "https://blazordeploy.blob.core.windows.net/blazordeploy/blazorapp.zip" -OutFile "C:\blazorapp.zip"

# Extract the app to target path
Expand-Archive -Path "C:\blazorapp.zip" -DestinationPath "C:\inetpub\MyBlazorApp" -Force

# (Optional) Create a new IIS site if needed
Import-Module WebAdministration

if (-not (Test-Path "IIS:\Sites\BlazorApp")) {
    New-WebSite -Name "BlazorApp" -Port 80 -PhysicalPath "C:\inetpub\MyBlazorApp" -Force
}
else {
    Restart-WebAppPool -Name "BlazorApp"
}

Write-Host "✅ Blazor app installed and IIS site configured."
