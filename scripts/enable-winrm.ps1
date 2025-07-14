# enable-winrm.ps1

# Enable PowerShell remoting
Enable-PSRemoting -Force

# Allow Basic authentication
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true

# Allow unencrypted messages (only for dev/test!)
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true

# Create HTTP listener if it doesn't exist
$listener = Get-ChildItem -Path WSMan:\Localhost\Listener | Where-Object { $_.Keys -contains "Transport=HTTP" }
if (-not $listener) {
    New-Item -Path WSMan:\Localhost\Listener -Transport HTTP -Address * -Force
}

# Open port 5985 in firewall
New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "WinRM over HTTP" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow

Write-Host "✅ WinRM setup over HTTP complete!"
