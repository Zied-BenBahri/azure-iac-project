# Azure VM Custom Script Extension for Blazor App Deployment - FIXED

param(
    [Parameter(Mandatory = $false)]
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
$ErrorActionPreference = "Stop"

# Log function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Output $logMessage
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path "C:\deployment.log" -Value $logMessage -Force
}

# Validation function for web.config
function Test-WebConfig {
    param([string]$ConfigPath)
    
    try {
        if (Test-Path $ConfigPath) {
            [xml]$webConfig = Get-Content $ConfigPath
            Write-Log "✅ web.config is valid XML"
            
            # Check for ASP.NET Core module
            $aspNetCoreModule = $webConfig.configuration.system.webServer.modules.add | Where-Object { $_.name -eq "AspNetCoreModuleV2" }
            if ($aspNetCoreModule) {
                Write-Log "✅ ASP.NET Core Module found in web.config"
                return $true
            }
            else {
                Write-Log "❌ ASP.NET Core Module missing in web.config"
                return $false
            }
        }
        else {
            Write-Log "❌ web.config not found at: $ConfigPath"
            return $false
        }
    }
    catch {
        Write-Log "❌ web.config validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Create proper web.config for Blazor
function New-BlazorWebConfig {
    param([string]$ConfigPath, [string]$ExeName)
    
    $webConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath=".\$ExeName" arguments="" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="inprocess">
        <environmentVariables>
          <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
          <environmentVariable name="ASPNETCORE_URLS" value="http://localhost:80" />
        </environmentVariables>
      </aspNetCore>
      <modules runAllManagedModulesForAllRequests="false">
        <remove name="WebDAVModule" />
      </modules>
    </system.webServer>
  </location>
</configuration>
"@

    Set-Content -Path $ConfigPath -Value $webConfigContent -Encoding UTF8
    Write-Log "✅ Created proper web.config for Blazor application"
}

Write-Log "Starting FIXED Azure Blazor Application Deployment"
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
        IIS-HttpErrors, `
        IIS-HttpLogging, `
        IIS-HttpRedirect, `
        IIS-ApplicationDevelopment, `
        IIS-NetFxExtensibility45, `
        IIS-ASPNET45, `
        IIS-ISAPIExtensions, `
        IIS-ISAPIFilter, `
        IIS-WebServerManagementTools, `
        IIS-ManagementConsole -All -NoRestart

    # 2. Download CORRECT installers - FIXED URLs
    Write-Log "=== DOWNLOADING CORRECT ASP.NET CORE HOSTING BUNDLE ==="
    
    # FIXED: Use ASP.NET Core Hosting Bundle instead of SDK
    $dotnetHostingUrl = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/9.0.8/dotnet-hosting-9.0.8-win.exe"
    $dotnetInstaller = "C:\temp\dotnet-hosting-8.0.8-win.exe"
    
    $urlRewriteUrl = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
    $urlRewriteInstaller = "C:\temp\rewrite_amd64_en-US.msi"
    $appZipPath = "C:\temp\blazorapp.zip"

    # Download with error handling
    try {
        Write-Log "Downloading ASP.NET Core 8 Hosting Bundle (REQUIRED FOR IIS)..."
        Invoke-WebRequest -Uri $dotnetHostingUrl -OutFile $dotnetInstaller -UseBasicParsing -TimeoutSec 300
        Write-Log "✅ ASP.NET Core Hosting Bundle downloaded: $((Get-Item $dotnetInstaller).Length / 1MB) MB"
    }
    catch {
        Write-Log "❌ Failed to download ASP.NET Core Hosting Bundle: $($_.Exception.Message)"
        throw
    }

    Write-Log "Downloading URL Rewrite Module..."
    Invoke-WebRequest -Uri $urlRewriteUrl -OutFile $urlRewriteInstaller -UseBasicParsing -TimeoutSec 120

    Write-Log "Downloading application package..."
    Invoke-WebRequest -Uri $AppPackageUrl -OutFile $appZipPath -UseBasicParsing -TimeoutSec 300

    # 3. Install ASP.NET Core Hosting Bundle (CRITICAL FOR IIS)
    if (Test-Path $dotnetInstaller) {
        Write-Log "Installing ASP.NET Core 8 Hosting Bundle for IIS..."
        $installResult = Start-Process -FilePath $dotnetInstaller -ArgumentList "/quiet", "/norestart" -Wait -NoNewWindow -PassThru
        
        if ($installResult.ExitCode -eq 0) {
            Write-Log "✅ ASP.NET Core Hosting Bundle installed successfully"
        }
        elseif ($installResult.ExitCode -eq 1638) {
            Write-Log "⚠️ ASP.NET Core Hosting Bundle already installed (Exit Code 1638)"
        }
        else {
            Write-Log "❌ ASP.NET Core installation failed with exit code: $($installResult.ExitCode)"
            throw "ASP.NET Core installation failed"
        }
    }

    # 4. Install URL Rewrite
    if (Test-Path $urlRewriteInstaller) {
        Write-Log "Installing URL Rewrite Module..."
        Start-Process msiexec.exe -ArgumentList "/i", $urlRewriteInstaller, "/quiet", "/norestart" -Wait -NoNewWindow
    }

    # IMPORTANT: Restart IIS to load the new modules
    Write-Log "Restarting IIS to load ASP.NET Core Module..."
    Restart-Service W3SVC -Force
    Start-Sleep -Seconds 5

    # 5. Configure IIS and deploy app
    Import-Module WebAdministration -Force
    $appPath = "C:\inetpub\wwwroot\$SiteName"
    
    Write-Log "Setting up application directory..."
    if (Test-Path $appPath) { Remove-Item -Path $appPath -Recurse -Force }
    New-Item -ItemType Directory -Path $appPath -Force
    
    # Create logs directory
    $logsPath = "$appPath\logs"
    New-Item -ItemType Directory -Path $logsPath -Force

    if (Test-Path $appZipPath) {
        Write-Log "Extracting application package..."
        
        # Handle nested directory structure
        $tempExtractPath = "C:\temp\extract"
        if (Test-Path $tempExtractPath) { Remove-Item -Path $tempExtractPath -Recurse -Force }
        New-Item -ItemType Directory -Path $tempExtractPath -Force
        
        Expand-Archive -Path $appZipPath -DestinationPath $tempExtractPath -Force
        
        # Find actual app files
        $deploymentFolder = Get-ChildItem -Path $tempExtractPath -Directory | Where-Object { $_.Name -like "*deployment*" } | Select-Object -First 1
        
        if ($deploymentFolder) {
            Write-Log "Found deployment folder: $($deploymentFolder.Name)"
            Copy-Item -Path "$($deploymentFolder.FullName)\*" -Destination $appPath -Recurse -Force
        }
        else {
            Copy-Item -Path "$tempExtractPath\*" -Destination $appPath -Recurse -Force
        }
        
        Remove-Item -Path $tempExtractPath -Recurse -Force
    }

    # FIXED: Create proper web.config for IIS + ASP.NET Core
    $webConfigPath = "$appPath\web.config"
    $exeName = "BlazorApp1.exe"
    
    Write-Log "Creating proper web.config for ASP.NET Core..."
    New-BlazorWebConfig -ConfigPath $webConfigPath -ExeName $exeName
    
    # Validate web.config
    if (-not (Test-WebConfig -ConfigPath $webConfigPath)) {
        throw "web.config validation failed"
    }

    # Update connection string
    $appsettingsPath = "$appPath\appsettings.json"
    if (Test-Path $appsettingsPath) {
        try {
            Write-Log "Updating database connection string..."
            $appsettings = Get-Content $appsettingsPath -Raw | ConvertFrom-Json
            $connectionString = "Server=tcp:$DatabaseServer,1433;Database=$DatabaseName;User Id=$DatabaseUser;Password=$DatabasePassword;TrustServerCertificate=true;MultipleActiveResultSets=true;Connection Timeout=30;"
            if (-not $appsettings.ConnectionStrings) { $appsettings | Add-Member -Type NoteProperty -Name ConnectionStrings -Value @{} }
            $appsettings.ConnectionStrings.DefaultConnection = $connectionString
            $appsettings | ConvertTo-Json -Depth 10 | Set-Content $appsettingsPath -Encoding UTF8
            Write-Log "✅ Connection string updated"
        }
        catch {
            Write-Log "Warning: Could not update connection string - $($_.Exception.Message)"
        }
    }

    # Application Pool configuration
    $appPoolName = "$SiteName`_AppPool"
    
    Write-Log "Configuring Application Pool..."
    if (Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue) {
        Remove-WebAppPool -Name $appPoolName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    
    New-WebAppPool -Name $appPoolName
    
    # FIXED: Proper app pool settings for ASP.NET Core
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value ""  # No Managed Code for .NET Core
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "startMode" -Value "AlwaysRunning"
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "processModel.idleTimeout" -Value "00:00:00"
    Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name "recycling.periodicRestart.time" -Value "00:00:00"

    # IIS Site configuration
    Write-Log "Configuring IIS Website..."
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $SiteName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    
    New-Website -Name $SiteName -Port 80 -PhysicalPath $appPath -ApplicationPool $appPoolName

    # Set proper permissions
    Write-Log "Setting file permissions..."
    $appPoolIdentity = "IIS AppPool\$appPoolName"
    
    # Give full permissions to app pool identity
    Start-Process icacls -ArgumentList $appPath, "/grant", "$($appPoolIdentity):(OI)(CI)F", "/T" -Wait -NoNewWindow
    
    # Give permissions to logs folder
    Start-Process icacls -ArgumentList $logsPath, "/grant", "$($appPoolIdentity):(OI)(CI)F", "/T" -Wait -NoNewWindow

    # Start services
    Write-Log "Starting Application Pool and Website..."
    Start-WebAppPool -Name $appPoolName
    Start-Sleep -Seconds 3
    
    Start-Website -Name $SiteName
    Start-Sleep -Seconds 2

    # Final validation
    Write-Log "Performing final validation..."
    $appPoolState = Get-WebAppPoolState -Name $appPoolName
    $websiteState = Get-WebsiteState -Name $SiteName
    
    Write-Log "✅ App Pool State: $($appPoolState.Value)"
    Write-Log "✅ Website State: $($websiteState.Value)"

    Write-Log "🎉 Deployment completed successfully!"
    Write-Log "🕒 Total deployment time: $((Get-Date) - $deploymentStart)"
    Write-Log "🌐 Application should be accessible at: http://localhost"
    Write-Log "📋 Check logs at: $logsPath"

}
catch {
    Write-Log "❌ ERROR during deployment: $($_.Exception.Message)"
    Write-Log "❌ Stack Trace: $($_.ScriptStackTrace)"
    
    # Additional troubleshooting info
    Write-Log "=== TROUBLESHOOTING INFORMATION ==="
    if (Test-Path "C:\inetpub\wwwroot\$SiteName\web.config") {
        Write-Log "📄 web.config exists"
        Get-Content "C:\inetpub\wwwroot\$SiteName\web.config" | ForEach-Object { Write-Log "   $_" }
    }
    else {
        Write-Log "❌ web.config missing"
    }
    
    exit 1
}
finally {
    Write-Log "🏁 Script execution completed"
}