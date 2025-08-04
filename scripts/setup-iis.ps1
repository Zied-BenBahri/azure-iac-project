param(
    [string]$AppName = "BlazorApp",
    [string]$ConnectionString = "",
    [string]$AppZipUrl = ""
)

# Set error handling
$ErrorActionPreference = "Stop"

try {
    Write-Host "=== Starting ASP.NET Core Blazor Server Deployment ===" -ForegroundColor Green
    Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor Cyan

    # Install IIS with ASP.NET Core features
    Write-Host "Installing IIS and required features..." -ForegroundColor Yellow
    $features = @(
        "IIS-WebServerRole", "IIS-WebServer", "IIS-CommonHttpFeatures",
        "IIS-HttpErrors", "IIS-HttpLogging", "IIS-HttpRedirect", 
        "IIS-ApplicationDevelopment", "IIS-NetFxExtensibility45",
        "IIS-HealthAndDiagnostics", "IIS-HttpTracing", "IIS-Security",
        "IIS-RequestFiltering", "IIS-Performance", "IIS-WebServerManagementTools",
        "IIS-ManagementConsole", "IIS-IIS6ManagementCompatibility", "IIS-Metabase"
    )
    
    Enable-WindowsOptionalFeature -Online -FeatureName $features -All -NoRestart

    # Create temp directory
    $tempDir = "C:\temp"
    if (!(Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force
    }

    # Download and Install .NET 9.0 Hosting Bundle
    Write-Host "Downloading .NET 9.0 Hosting Bundle..." -ForegroundColor Yellow
    $dotnetUrl = "https://download.visualstudio.microsoft.com/download/pr/72e8b5b6-9d9b-4199-9de2-b0a4c1f2c1a5/9e97b01255a14b2c8eca3d6f6b4e8b0f/dotnet-hosting-9.0.0-win.exe"
    $dotnetInstaller = "$tempDir\dotnet-hosting-bundle.exe"
    
    Invoke-WebRequest -Uri $dotnetUrl -OutFile $dotnetInstaller -UseBasicParsing
    
    Write-Host "Installing .NET 9.0 Hosting Bundle..." -ForegroundColor Yellow
    Start-Process -FilePath $dotnetInstaller -ArgumentList "/quiet" -Wait
    
    # Restart IIS to load new modules
    Write-Host "Restarting IIS..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    iisreset /restart
    Start-Sleep -Seconds 10

    # Create application directory
    $appPath = "C:\inetpub\wwwroot\$AppName"
    Write-Host "Creating application directory: $appPath" -ForegroundColor Yellow
    if (Test-Path $appPath) {
        Remove-Item $appPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $appPath -Force

    # Download application from GitHub releases
    if ($AppZipUrl -ne "") {
        Write-Host "Downloading Blazor application from: $AppZipUrl" -ForegroundColor Yellow
        
        $appZip = "$tempDir\blazorapp.zip"
        
        try {
            Invoke-WebRequest -Uri $AppZipUrl -OutFile $appZip -UseBasicParsing
            Write-Host "Extracting application files..." -ForegroundColor Yellow
            Expand-Archive -Path $appZip -DestinationPath $appPath -Force
            Write-Host "✅ Blazor application deployed successfully!" -ForegroundColor Green
        }
        catch {
            Write-Warning "⚠️ Could not download application: $($_.Exception.Message)"
            Write-Host "Creating placeholder application structure..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Path "$appPath\wwwroot" -Force
        }
    }

    # Create or update appsettings.json with connection string
    if ($ConnectionString -ne "") {
        Write-Host "Creating appsettings.json with SQL Server connection..." -ForegroundColor Yellow
        $hostname = $env:COMPUTERNAME
        $appSettings = @{
            "Logging"           = @{
                "LogLevel" = @{
                    "Default"              = "Information"
                    "Microsoft.AspNetCore" = "Warning"
                }
            }
            "AllowedHosts"      = "*"
            "ConnectionStrings" = @{
                "DefaultConnection" = $ConnectionString
            }
            "ServerInfo"        = @{
                "Hostname"       = $hostname
                "DeploymentTime" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        $appSettingsJson = $appSettings | ConvertTo-Json -Depth 4
        $appSettingsJson | Out-File -FilePath "$appPath\appsettings.json" -Encoding UTF8 -Force
    }

    # Create web.config for ASP.NET Core
    if (Get-ChildItem -Path $appPath -Filter "*.dll" -ErrorAction SilentlyContinue) {
        Write-Host "Creating web.config for ASP.NET Core..." -ForegroundColor Yellow
        
        # Find the main application DLL
        $mainDll = Get-ChildItem -Path $appPath -Filter "*.dll" | Where-Object { $_.BaseName -like "*$AppName*" } | Select-Object -First 1
        if (-not $mainDll) {
            $mainDll = Get-ChildItem -Path $appPath -Filter "*.dll" | Select-Object -First 1
        }
        
        $dllName = if ($mainDll) { $mainDll.Name } else { "$AppName.dll" }
        
        $webConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="dotnet" 
                  arguments=".\$dllName" 
                  stdoutLogEnabled="true" 
                  stdoutLogFile=".\logs\stdout" 
                  hostingModel="inprocess">
        <environmentVariables>
          <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
        </environmentVariables>
      </aspNetCore>
    </system.webServer>
  </location>
</configuration>
"@
        $webConfig | Out-File -FilePath "$appPath\web.config" -Encoding UTF8 -Force
        
        # Create logs directory
        New-Item -ItemType Directory -Path "$appPath\logs" -Force
    }

    # Import WebAdministration module
    Import-Module WebAdministration -Force

    # Create Application Pool
    Write-Host "Creating Application Pool for .NET Core..." -ForegroundColor Yellow
    $poolName = "${AppName}Pool"
    if (Get-IISAppPool -Name $poolName -ErrorAction SilentlyContinue) {
        Remove-IISAppPool -Name $poolName -Confirm:$false
        Start-Sleep -Seconds 2
    }
    New-IISAppPool -Name $poolName
    Set-IISAppPool -Name $poolName -ProcessModel.IdentityType ApplicationPoolIdentity
    Set-IISAppPool -Name $poolName -ManagedRuntimeVersion ""  # No Managed Code for .NET Core

    # Create IIS Application
    Write-Host "Creating IIS Application..." -ForegroundColor Yellow
    $siteName = "Default Web Site"
    $appVirtualPath = "/$AppName"
    
    if (Get-IISApp -Name "$siteName$appVirtualPath" -ErrorAction SilentlyContinue) {
        Remove-IISApp -Name "$siteName$appVirtualPath" -Confirm:$false
        Start-Sleep -Seconds 2
    }
    New-IISApp -Name "$siteName$appVirtualPath" -PhysicalPath $appPath -ApplicationPool $poolName

    # Download and install WMI Exporter
    Write-Host "Installing WMI Exporter for monitoring..." -ForegroundColor Yellow
    $wmiExporterUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v0.24.0/windows_exporter-0.24.0-amd64.msi"
    $wmiExporter = "$tempDir\windows_exporter.msi"
    Invoke-WebRequest -Uri $wmiExporterUrl -OutFile $wmiExporter -UseBasicParsing
    Start-Process msiexec.exe -Wait -ArgumentList "/I $wmiExporter /quiet /norestart"

    # Start WMI Exporter service
    Start-Sleep -Seconds 10
    Start-Service windows_exporter -ErrorAction SilentlyContinue
    Set-Service windows_exporter -StartupType Automatic -ErrorAction SilentlyContinue

    # Test SQL Server connectivity
    if ($ConnectionString -ne "") {
        Write-Host "Testing SQL Server connectivity..." -ForegroundColor Yellow
        try {
            $connectionTest = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $connectionTest.Open()
            $connectionTest.Close()
            Write-Host "✅ SQL Server connection successful!" -ForegroundColor Green
        }
        catch {
            Write-Warning "⚠️ SQL Server connection failed: $($_.Exception.Message)"
            Write-Host "This requires VPN connectivity to be established first." -ForegroundColor Yellow
        }
    }

    Write-Host "=== Deployment Summary ===" -ForegroundColor Green
    Write-Host "Server: $env:COMPUTERNAME" -ForegroundColor White
    Write-Host "Application Pool: $poolName" -ForegroundColor White
    Write-Host "Application Path: $appPath" -ForegroundColor White
    Write-Host "Blazor App URL: http://localhost/$AppName" -ForegroundColor Cyan
    Write-Host "WMI Exporter: http://localhost:9182/metrics" -ForegroundColor Cyan
    Write-Host "✅ ASP.NET Core Blazor Server deployment completed!" -ForegroundColor Green

}
catch {
    Write-Error "❌ Deployment failed: $($_.Exception.Message)"
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}