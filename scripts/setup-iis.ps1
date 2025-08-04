param(
    [string]$AppName = "BlazorApp",
    [string]$ConnectionString = "",
    [string]$AppZipUrl = ""
)

# Enhanced logging function that writes to multiple locations
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console (appears in stdout)
    Write-Host $logMessage -ForegroundColor $Color
    
    # Write to custom log file (easier to access)
    $logMessage | Out-File -FilePath "C:\temp\deployment.log" -Append -Encoding utf8
    
    # Write to Windows Event Log
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("CustomDeployment")) {
            [System.Diagnostics.EventLog]::CreateEventSource("CustomDeployment", "Application")
        }
        Write-EventLog -LogName "Application" -Source "CustomDeployment" -EventId 1000 -EntryType Information -Message $logMessage
    }
    catch {
        # Ignore event log errors
    }
}

# Set error handling
$ErrorActionPreference = "Continue"

try {
    # Create accessible log directory
    $logDir = "C:\temp"
    if (!(Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force
    }
    
    # Clear previous log
    if (Test-Path "C:\temp\deployment.log") {
        Remove-Item "C:\temp\deployment.log" -Force
    }
    
    Write-Log "=== Starting ASP.NET Core Blazor Server Deployment ===" "INFO" "Green"
    Write-Log "Server: $env:COMPUTERNAME" "INFO" "Cyan"
    Write-Log "Script Parameters: AppName=$AppName, AppZipUrl=$AppZipUrl" "INFO" "Cyan"
    
    # Test internet connectivity first
    Write-Log "Testing internet connectivity..." "INFO" "Yellow"
    try {
        $testUrl = "https://www.microsoft.com"
        $webRequest = [System.Net.WebRequest]::Create($testUrl)
        $webRequest.Method = "HEAD"
        $webRequest.Timeout = 10000
        $response = $webRequest.GetResponse()
        $response.Close()
        Write-Log "Internet connectivity test PASSED" "SUCCESS" "Green"
    }
    catch {
        Write-Log "Internet connectivity test FAILED: $($_.Exception.Message)" "ERROR" "Red"
    }
    
    # Install IIS features
    Write-Log "Installing IIS and required features..." "INFO" "Yellow"
    $features = @(
        "IIS-WebServerRole", "IIS-WebServer", "IIS-CommonHttpFeatures",
        "IIS-HttpErrors", "IIS-HttpLogging", "IIS-HttpRedirect", 
        "IIS-ApplicationDevelopment", "IIS-NetFxExtensibility45",
        "IIS-HealthAndDiagnostics", "IIS-HttpTracing", "IIS-Security",
        "IIS-RequestFiltering", "IIS-Performance", "IIS-WebServerManagementTools",
        "IIS-ManagementConsole", "IIS-IIS6ManagementCompatibility", "IIS-Metabase"
    )
    
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName $features -All -NoRestart
        Write-Log "IIS features installed successfully" "SUCCESS" "Green"
    }
    catch {
        Write-Log "IIS features installation warning: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    # Download .NET hosting bundle
    Write-Log "Downloading .NET 9.0 Hosting Bundle..." "INFO" "Yellow"
    
    $dotnetUrls = @(
        "https://download.visualstudio.microsoft.com/download/pr/72e8b5b6-9d9b-4199-9de2-b0a4c1f2c1a5/9e97b01255a14b2c8eca3d6f6b4e8b0f/dotnet-hosting-9.0.0-win.exe",
        "https://dotnetcli.azureedge.net/dotnet/aspnetcore/Runtime/9.0.0/dotnet-hosting-9.0.0-win.exe"
    )
    
    $dotnetInstaller = "$logDir\dotnet-hosting-bundle.exe"
    $downloadSuccess = $false
    
    foreach ($url in $dotnetUrls) {
        try {
            Write-Log "Attempting download from: $url" "INFO" "Cyan"
            Invoke-WebRequest -Uri $url -OutFile $dotnetInstaller -UseBasicParsing -TimeoutSec 300
            if (Test-Path $dotnetInstaller) {
                $fileSize = (Get-Item $dotnetInstaller).Length
                Write-Log ".NET bundle downloaded successfully. Size: $fileSize bytes" "SUCCESS" "Green"
                $downloadSuccess = $true
                break
            }
        }
        catch {
            Write-Log "Download failed from $url : $($_.Exception.Message)" "ERROR" "Red"
        }
    }
    
    if ($downloadSuccess) {
        try {
            Write-Log "Installing .NET hosting bundle..." "INFO" "Yellow"
            $installProcess = Start-Process -FilePath $dotnetInstaller -ArgumentList "/quiet" -Wait -PassThru
            Write-Log ".NET installation completed with exit code: $($installProcess.ExitCode)" "INFO" "Cyan"
        }
        catch {
            Write-Log ".NET installation failed: $($_.Exception.Message)" "ERROR" "Red"
        }
    }
    
    # Restart IIS to load new modules
    Write-Log "Restarting IIS..." "INFO" "Yellow"
    Start-Sleep -Seconds 5
    iisreset /restart
    Start-Sleep -Seconds 10

    # Create application directory
    $appPath = "C:\inetpub\wwwroot\$AppName"
    Write-Log "Creating application directory: $appPath" "INFO" "Yellow"
    if (Test-Path $appPath) {
        Remove-Item $appPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $appPath -Force

    # Download application from GitHub releases
    if ($AppZipUrl -ne "") {
        Write-Log "Downloading Blazor application from: $AppZipUrl" "INFO" "Yellow"
        
        $appZip = "$logDir\blazorapp.zip"
        
        try {
            Invoke-WebRequest -Uri $AppZipUrl -OutFile $appZip -UseBasicParsing
            Write-Log "Extracting application files..." "INFO" "Yellow"
            Expand-Archive -Path $appZip -DestinationPath $appPath -Force
            Write-Log "✅ Blazor application deployed successfully!" "SUCCESS" "Green"
        }
        catch {
            Write-Warning "⚠️ Could not download application: $($_.Exception.Message)"
            Write-Log "Creating placeholder application structure..." "INFO" "Yellow"
            New-Item -ItemType Directory -Path "$appPath\wwwroot" -Force
        }
    }

    # Create or update appsettings.json with connection string
    if ($ConnectionString -ne "") {
        Write-Log "Creating appsettings.json with SQL Server connection..." "INFO" "Yellow"
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
        Write-Log "Creating web.config for ASP.NET Core..." "INFO" "Yellow"
        
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
    Write-Log "Creating Application Pool for .NET Core..." "INFO" "Yellow"
    $poolName = "${AppName}Pool"
    if (Get-IISAppPool -Name $poolName -ErrorAction SilentlyContinue) {
        Remove-IISAppPool -Name $poolName -Confirm:$false
        Start-Sleep -Seconds 2
    }
    New-IISAppPool -Name $poolName
    Set-IISAppPool -Name $poolName -ProcessModel.IdentityType ApplicationPoolIdentity
    Set-IISAppPool -Name $poolName -ManagedRuntimeVersion ""  # No Managed Code for .NET Core

    # Create IIS Application
    Write-Log "Creating IIS Application..." "INFO" "Yellow"
    $siteName = "Default Web Site"
    $appVirtualPath = "/$AppName"
    
    if (Get-IISApp -Name "$siteName$appVirtualPath" -ErrorAction SilentlyContinue) {
        Remove-IISApp -Name "$siteName$appVirtualPath" -Confirm:$false
        Start-Sleep -Seconds 2
    }
    New-IISApp -Name "$siteName$appVirtualPath" -PhysicalPath $appPath -ApplicationPool $poolName

    # Download and install WMI Exporter
    Write-Log "Installing WMI Exporter for monitoring..." "INFO" "Yellow"
    $wmiExporterUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v0.24.0/windows_exporter-0.24.0-amd64.msi"
    $wmiExporter = "$logDir\windows_exporter.msi"
    Invoke-WebRequest -Uri $wmiExporterUrl -OutFile $wmiExporter -UseBasicParsing
    Start-Process msiexec.exe -Wait -ArgumentList "/I $wmiExporter /quiet /norestart"

    # Start WMI Exporter service
    Start-Sleep -Seconds 10
    Start-Service windows_exporter -ErrorAction SilentlyContinue
    Set-Service windows_exporter -StartupType Automatic -ErrorAction SilentlyContinue

    # Test SQL Server connectivity
    if ($ConnectionString -ne "") {
        Write-Log "Testing SQL Server connectivity..." "INFO" "Yellow"
        try {
            $connectionTest = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $connectionTest.Open()
            $connectionTest.Close()
            Write-Log "✅ SQL Server connection successful!" "SUCCESS" "Green"
        }
        catch {
            Write-Warning "⚠️ SQL Server connection failed: $($_.Exception.Message)"
            Write-Log "This requires VPN connectivity to be established first." "INFO" "Yellow"
        }
    }

    # Final status
    Write-Log "=== Deployment Summary ===" "INFO" "Green"
    Write-Log "Check logs at: C:\temp\deployment.log" "INFO" "Cyan"
    Write-Log "Check extension logs at: C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\" "INFO" "Cyan"
    Write-Log "Deployment completed" "SUCCESS" "Green"
    
    exit 0
}
catch {
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)" "ERROR" "Red"
    Write-Log "Stack trace: $($_.Exception.StackTrace)" "ERROR" "Red"
    exit 1
}