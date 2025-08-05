# Optimized Azure VM Custom Script Extension for Blazor App Deployment

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
$ErrorActionPreference = "Continue"  # Changed from "Stop" to avoid script termination

# Log function with console output
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Output $logMessage
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path "C:\deployment.log" -Value $logMessage -Force
}

Write-Log "=== Starting Optimized Blazor Application Deployment ==="

# Track deployment start time
$deploymentStart = Get-Date

try {
    # Create temp directory first
    Write-Log "Creating temp directory..."
    if (!(Test-Path "C:\temp")) {
        New-Item -ItemType Directory -Path "C:\temp" -Force
    }

    # 1. Install IIS and required features (parallel downloads while this runs)
    Write-Log "Installing IIS and ASP.NET Core features..."
    
    # Start downloads in background while IIS installs
    $dotnetUrl = "https://download.microsoft.com/download/7/8/b/78b69c87-8e04-4f9c-af70-7598b43af07e/dotnet-hosting-9.0.0-win.exe"
    $dotnetInstaller = "C:\temp\dotnet-hosting-9.0.0-win.exe"
    $urlRewriteUrl = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
    $urlRewriteInstaller = "C:\temp\rewrite_amd64_en-US.msi"
    
    # Start downloads in background
    Write-Log "Starting background downloads..."
    $dotnetJob = Start-Job -ScriptBlock { 
        param($url, $path)
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
    } -ArgumentList $dotnetUrl, $dotnetInstaller
    
    $urlRewriteJob = Start-Job -ScriptBlock { 
        param($url, $path)
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
    } -ArgumentList $urlRewriteUrl, $urlRewriteInstaller
    
    $appJob = Start-Job -ScriptBlock { 
        param($url, $path)
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
    } -ArgumentList $AppPackageUrl, "C:\temp\blazorapp.zip"

    # Install IIS features (minimal set)
    Write-Log "Installing essential IIS features only..."
    Enable-WindowsOptionalFeature -Online -FeatureName `
        IIS-WebServerRole, `
        IIS-WebServer, `
        IIS-CommonHttpFeatures, `
        IIS-ApplicationDevelopment, `
        IIS-NetFxExtensibility45, `
        IIS-ASPNET45, `
        IIS-WebServerManagementTools, `
        IIS-ManagementConsole -All -NoRestart

    # Wait for .NET download and install
    Write-Log "Waiting for .NET download to complete..."
    Wait-Job $dotnetJob | Out-Null
    $dotnetResult = Receive-Job $dotnetJob
    Remove-Job $dotnetJob
    
    if (Test-Path $dotnetInstaller) {
        Write-Log "Installing .NET 9 Hosting Bundle..."
        Start-Process -FilePath $dotnetInstaller -ArgumentList "/quiet", "/norestart" -Wait -NoNewWindow
        Write-Log ".NET 9 Hosting Bundle installed"
    }

    # Wait for URL Rewrite download and install
    Write-Log "Waiting for URL Rewrite download to complete..."
    Wait-Job $urlRewriteJob | Out-Null
    Remove-Job $urlRewriteJob
    
    if (Test-Path $urlRewriteInstaller) {
        Write-Log "Installing URL Rewrite Module..."
        Start-Process msiexec.exe -ArgumentList "/i", $urlRewriteInstaller, "/quiet", "/norestart" -Wait -NoNewWindow
        Write-Log "URL Rewrite Module installed"
    }

    # Import WebAdministration module early
    Write-Log "Importing WebAdministration module..."
    Import-Module WebAdministration -Force

    # Create application directory
    Write-Log "Creating application directory..."
    $appPath = "C:\inetpub\wwwroot\$SiteName"
    if (Test-Path $appPath) {
        Remove-Item -Path $appPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $appPath -Force

    # Wait for app download and extract
    Write-Log "Waiting for application download to complete..."
    Wait-Job $appJob | Out-Null
    Remove-Job $appJob
    
    if (Test-Path "C:\temp\blazorapp.zip") {
        Write-Log "Extracting application package..."
        Expand-Archive -Path "C:\temp\blazorapp.zip" -DestinationPath $appPath -Force
        Write-Log "Application extracted successfully"
    }
    else {
        Write-Log "ERROR: Application package not found!"
        throw "Application package download failed"
    }

    # Update connection string
    Write-Log "Updating connection string..."
    $appsettingsPath = "$appPath\appsettings.json"
    if (Test-Path $appsettingsPath) {
        try {
            $appsettings = Get-Content $appsettingsPath -Raw | ConvertFrom-Json
            $connectionString = "Server=tcp:$DatabaseServer,1433;Database=$DatabaseName;User Id=$DatabaseUser;Password=$DatabasePassword;TrustServerCertificate=true;MultipleActiveResultSets=true;Connection Timeout=30;"
            
            if (-not $appsettings.ConnectionStrings) {
                $appsettings | Add-Member -Type NoteProperty -Name ConnectionStrings -Value @{}
            }
            $appsettings.ConnectionStrings.DefaultConnection = $connectionString
            
            $appsettings | ConvertTo-Json -Depth 10 | Set-Content $appsettingsPath -Encoding UTF8
            Write-Log "Connection string updated successfully"
        }
        catch {
            Write-Log "Warning: Could not update connection string - $($_.Exception.Message)"
        }
    }

    # Create Application Pool
    Write-Log "Creating Application Pool..."
    $appPoolName = "$SiteName`_AppPool"
    
    # Remove existing pool if it exists
    if (Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue) {
        Remove-WebAppPool -Name $appPoolName -ErrorAction SilentlyContinue
    }
    
    New-WebAppPool -Name $appPoolName
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value ""
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "startMode" -Value "AlwaysRunning"
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "processModel.idleTimeout" -Value "00:00:00"

    # Create IIS Site
    Write-Log "Creating IIS Site..."
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $SiteName -ErrorAction SilentlyContinue
    }
    
    New-Website -Name $SiteName -Port 80 -PhysicalPath $appPath -ApplicationPool $appPoolName

    # Set permissions
    Write-Log "Setting permissions..."
    $appPoolIdentity = "IIS AppPool\$appPoolName"
    Start-Process icacls -ArgumentList $appPath, "/grant", "$($appPoolIdentity):(OI)(CI)F", "/T" -Wait -NoNewWindow

    # Create web.config with dynamic DLL name
    $webConfigPath = "$appPath\web.config"
    if (!(Test-Path $webConfigPath)) {
        Write-Log "Creating web.config..."
        
        # Find the main DLL file
        $dllFiles = Get-ChildItem -Path $appPath -Filter "*.dll" | Where-Object { $_.Name -notlike "*.Views.dll" -and $_.Name -notlike "*.resources.dll" }
        $mainDll = if ($dllFiles.Count -gt 0) { $dllFiles[0].Name } else { "$SiteName.dll" }
        
        $webConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="dotnet" arguments=".\$mainDll" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="inprocess">
        <environmentVariables>
          <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
        </environmentVariables>
      </aspNetCore>
      <security>
        <requestFiltering>
          <requestLimits maxAllowedContentLength="52428800" />
        </requestFiltering>
      </security>
    </system.webServer>
  </location>
</configuration>
"@
        $webConfigContent | Out-File -FilePath $webConfigPath -Encoding UTF8
        Write-Log "Web.config created with DLL: $mainDll"
    }

    # Create logs directory
    $logsPath = "$appPath\logs"
    if (!(Test-Path $logsPath)) {
        New-Item -ItemType Directory -Path $logsPath -Force
        Start-Process icacls -ArgumentList $logsPath, "/grant", "$($appPoolIdentity):(OI)(CI)F", "/T" -Wait -NoNewWindow
    }

    # Start services (no full IIS reset)
    Write-Log "Starting website and application pool..."
    Start-WebAppPool -Name $appPoolName
    Start-Website -Name $SiteName

    Write-Log "=== Deployment completed successfully! ==="
    Write-Log "Application is available at: http://localhost"
    Write-Log "Total deployment time: $((Get-Date) - $deploymentStart)"
    
    # Quick application test
    Write-Log "Testing application..."
    Start-Sleep -Seconds 5  # Give the app a moment to start
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 15
        Write-Log "✓ Application is responding (Status: $($response.StatusCode))"
    }
    catch {
        Write-Log "⚠ Application test failed - $($_.Exception.Message)"
        Write-Log "This might be normal if the application needs more time to start"
    }

    # Cleanup temp files
    Write-Log "Cleaning up temporary files..."
    Remove-Item -Path "C:\temp\*.exe", "C:\temp\*.msi", "C:\temp\*.zip" -ErrorAction SilentlyContinue

}
catch {
    Write-Log "❌ ERROR during deployment: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.Exception.StackTrace)"
    
    # Try to get more details about what failed
    Write-Log "=== Troubleshooting Information ==="
    Write-Log "Current PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Log "Current user: $env:USERNAME"
    Write-Log "Available disk space: $((Get-WmiObject -Class Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object -First 1).FreeSpace / 1GB) GB"
    
    throw
}
finally {
    # Cleanup any remaining jobs
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
    Write-Log "=== Script execution completed ==="
}
