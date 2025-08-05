# Optimized Azure VM Custom Script Extension for Blazor App Deployment (No Start-Job)

param(
    [Parameter(Mandatory = $true)]
    [string]$AppPackageUrl = "https://github.com/Zied-BenBahri/azure-iac-project/releases/download/v1.0.0/blazorapp.zip",
    
    [Parameter(Mandatory = $false)]
    [string]$SiteName = "BlazorApp1",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseServer = "172.16.0.130",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseName = "BlazorCrudApp",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseUser = "blazoruser",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabasePassword = "BlazorApp2024!"
)

# Enable verbose logging
$VerbosePreference = "Continue"
$ErrorActionPreference = "Continue"

# Log function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Output $logMessage
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path "C:\deployment.log" -Value $logMessage -Force
}

Write-Log "Starting Optimized Blazor Application Deployment"

$deploymentStart = Get-Date

try {
    Write-Log "Creating temp directory..."
    if (!(Test-Path "C:\temp")) {
        New-Item -ItemType Directory -Path "C:\temp" -Force
    }

    # 1. Install IIS and required features
    Write-Log "Installing essential IIS features..."
    Enable-WindowsOptionalFeature -Online -FeatureName `
        IIS-WebServerRole, `
        IIS-WebServer, `
        IIS-CommonHttpFeatures, `
        IIS-ApplicationDevelopment, `
        IIS-NetFxExtensibility45, `
        IIS-ASPNET45, `
        IIS-WebServerManagementTools, `
        IIS-ManagementConsole -All -NoRestart

    # 2. Download installers sequentially
    $dotnetUrl = "https://download.microsoft.com/download/7/8/b/78b69c87-8e04-4f9c-af70-7598b43af07e/dotnet-hosting-9.0.0-win.exe"
    $dotnetInstaller = "C:\temp\dotnet-hosting-9.0.0-win.exe"
    $urlRewriteUrl = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
    $urlRewriteInstaller = "C:\temp\rewrite_amd64_en-US.msi"
    $appZipPath = "C:\temp\blazorapp.zip"

    Write-Log "Downloading .NET Hosting Bundle..."
    Invoke-WebRequest -Uri $dotnetUrl -OutFile $dotnetInstaller -UseBasicParsing

    Write-Log "Downloading URL Rewrite..."
    Invoke-WebRequest -Uri $urlRewriteUrl -OutFile $urlRewriteInstaller -UseBasicParsing

    Write-Log "Downloading application package..."
    Invoke-WebRequest -Uri $AppPackageUrl -OutFile $appZipPath -UseBasicParsing

    # 3. Install .NET Hosting Bundle
    if (Test-Path $dotnetInstaller) {
        Write-Log "Installing .NET 9 Hosting Bundle..."
        Start-Process -FilePath $dotnetInstaller -ArgumentList "/quiet", "/norestart" -Wait -NoNewWindow
    }

    # 4. Install URL Rewrite
    if (Test-Path $urlRewriteInstaller) {
        Write-Log "Installing URL Rewrite Module..."
        Start-Process msiexec.exe -ArgumentList "/i", $urlRewriteInstaller, "/quiet", "/norestart" -Wait -NoNewWindow
    }

    # 5. Configure IIS and deploy app
    Import-Module WebAdministration -Force
    $appPath = "C:\inetpub\wwwroot\$SiteName"
    if (Test-Path $appPath) { Remove-Item -Path $appPath -Recurse -Force }
    New-Item -ItemType Directory -Path $appPath -Force

    if (Test-Path $appZipPath) {
        Write-Log "Extracting application package..."
        Expand-Archive -Path $appZipPath -DestinationPath $appPath -Force
    }

    # Update connection string
    $appsettingsPath = "$appPath\appsettings.json"
    if (Test-Path $appsettingsPath) {
        try {
            $appsettings = Get-Content $appsettingsPath -Raw | ConvertFrom-Json
            $connectionString = "Server=tcp:$DatabaseServer,1433;Database=$DatabaseName;User Id=$DatabaseUser;Password=$DatabasePassword;TrustServerCertificate=true;MultipleActiveResultSets=true;Connection Timeout=30;"
            if (-not $appsettings.ConnectionStrings) { $appsettings | Add-Member -Type NoteProperty -Name ConnectionStrings -Value @{} }
            $appsettings.ConnectionStrings.DefaultConnection = $connectionString
            $appsettings | ConvertTo-Json -Depth 10 | Set-Content $appsettingsPath -Encoding UTF8
        } catch {
            Write-Log "Warning: Could not update connection string - $($_.Exception.Message)"
        }
    }

    # Application Pool
    $appPoolName = "$SiteName`_AppPool"
    if (Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue) {
        Remove-WebAppPool -Name $appPoolName -ErrorAction SilentlyContinue
    }
    New-WebAppPool -Name $appPoolName
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value ""
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "startMode" -Value "AlwaysRunning"
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "processModel.idleTimeout" -Value "00:00:00"

    # IIS Site
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $SiteName -ErrorAction SilentlyContinue
    }
    New-Website -Name $SiteName -Port 80 -PhysicalPath $appPath -ApplicationPool $appPoolName

    # Permissions
    $appPoolIdentity = "IIS AppPool\$appPoolName"
    Start-Process icacls -ArgumentList $appPath, "/grant", "$($appPoolIdentity):(OI)(CI)F", "/T" -Wait -NoNewWindow

    # Start site
    Start-WebAppPool -Name $appPoolName
    Start-Website -Name $SiteName

    Write-Log "Deployment completed successfully!"
    Write-Log "Total deployment time: $((Get-Date) - $deploymentStart)"

} catch {
    Write-Log "ERROR during deployment: $($_.Exception.Message)"
} finally {
    Write-Log "Script execution completed"
}
