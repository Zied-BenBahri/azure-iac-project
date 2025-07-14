# Enable WinRM over HTTPS for Ansible
Write-Host "Enabling PSRemoting..."
Enable-PSRemoting -Force

# Create a self-signed cert
Write-Host "Creating self-signed cert..."
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My

# Configure HTTPS listener
Write-Host "Configuring WinRM HTTPS listener..."
$thumb = $cert.Thumbprint
New-Item -Path WSMan:\Localhost\Listener -Transport HTTPS -Address * -CertificateThumbprint $thumb -Force

# Allow basic auth and unencrypted for testing
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true

# Open firewall port for WinRM
Write-Host "Opening firewall..."
New-NetFirewallRule -Name "WinRM-HTTPS" -DisplayName "WinRM over HTTPS" -Enabled True -Protocol TCP -LocalPort 5986 -Action Allow

Write-Host "WinRM setup complete."
