param(
    [string]$AppName = "BlazorApp",
    [string]$ConnectionString = "",
    [string]$AppZipUrl = ""
)

# Enhanced logging function
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console
    Write-Host $logMessage -ForegroundColor $Color
    
    # Write to accessible log file
    $logMessage | Out-File -FilePath "C:\temp\deployment.log" -Append -Encoding utf8
    
    # Also write to a secondary location
    $logMessage | Out-File -FilePath "C:\inetpub\wwwroot\deployment.log" -Append -Encoding utf8 -ErrorAction SilentlyContinue
}

# Function to download with multiple methods
function Download-FileAdvanced {
    param(
        [string]$Url,
        [string]$OutputPath,
        [int]$TimeoutSeconds = 300
    )
    
    Write-Log "Attempting to download: $Url" "INFO" "Yellow"
    
    # Method 1: Try Invoke-WebRequest
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -TimeoutSec $TimeoutSeconds
        if (Test-Path $OutputPath) {
            $size = (Get-Item $OutputPath).Length
            Write-Log "Download successful using Invoke-WebRequest. Size: $size bytes" "SUCCESS" "Green"
            return $true
        }
    }
    catch {
        Write-Log "Invoke-WebRequest failed: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    # Method 2: Try .NET WebClient
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        $webClient.Dispose()
        if (Test-Path $OutputPath) {
            $size = (Get-Item $OutputPath).Length
            Write-Log "Download successful using WebClient. Size: $size bytes" "SUCCESS" "Green"
            return $true
        }
    }
    catch {
        Write-Log "WebClient failed: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    # Method 3: Try BITS transfer (if available)
    try {
        Import-Module BitsTransfer -ErrorAction SilentlyContinue
        Start-BitsTransfer -Source $Url -Destination $OutputPath -TransferType Download
        if (Test-Path $OutputPath) {
            $size = (Get-Item $OutputPath).Length
            Write-Log "Download successful using BITS. Size: $size bytes" "SUCCESS" "Green"
            return $true
        }
    }
    catch {
        Write-Log "BITS transfer failed: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    Write-Log "All download methods failed for: $Url" "ERROR" "Red"
    return $false
}

# Function to create IIS application pool using native methods
function Create-IISAppPool {
    param(
        [string]$PoolName
    )
    
    try {
        Write-Log "Creating application pool: $PoolName" "INFO" "Yellow"
        
        # Use appcmd.exe instead of PowerShell cmdlets
        $appcmd = "$env:SystemRoot\System32\inetsrv\appcmd.exe"
        
        # Delete existing pool if it exists
        & $appcmd delete apppool $PoolName 2>$null
        Start-Sleep -Seconds 2
        
        # Create new application pool
        & $appcmd add apppool /name:$PoolName
        & $appcmd set apppool $PoolName /managedRuntimeVersion:""
        & $appcmd set apppool $PoolName /processModel.identityType:ApplicationPoolIdentity
        
        Write-Log "Application pool created successfully: $PoolName" "SUCCESS" "Green"
        return $true
    }
    catch {
        Write-Log "Failed to create application pool: $($_.Exception.Message)" "ERROR" "Red"
        return $false
    }
}

# Function to create IIS application using native methods
function Create-IISApplication {
    param(
        [string]$SiteName,
        [string]$AppName,
        [string]$PhysicalPath,
        [string]$PoolName
    )
    
    try {
        Write-Log "Creating IIS application: $AppName" "INFO" "Yellow"
        
        $appcmd = "$env:SystemRoot\System32\inetsrv\appcmd.exe"
        
        # Delete existing application if it exists
        & $appcmd delete app "$SiteName/$AppName" 2>$null
        Start-Sleep -Seconds 2
        
        # Create new application
        & $appcmd add app /site.name:"$SiteName" /path:"/$AppName" /physicalPath:"$PhysicalPath"
        & $appcmd set app "$SiteName/$AppName" /applicationPool:$PoolName
        
        Write-Log "IIS application created successfully: $AppName" "SUCCESS" "Green"
        return $true
    }
    catch {
        Write-Log "Failed to create IIS application: $($_.Exception.Message)" "ERROR" "Red"
        return $false
    }
}

# Set error handling
$ErrorActionPreference = "Continue"

try {
    # Create log directories
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
    Write-Log "Script Parameters: AppName=$AppName" "INFO" "Cyan"
    Write-Log "ConnectionString provided: $($ConnectionString -ne '')" "INFO" "Cyan"
    Write-Log "AppZipUrl: $AppZipUrl" "INFO" "Cyan"
    
    # Test basic network connectivity
    Write-Log "Testing network connectivity..." "INFO" "Yellow"
    try {
        $ping = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -WarningAction SilentlyContinue
        if ($ping.TcpTestSucceeded) {
            Write-Log "Basic internet connectivity: PASSED" "SUCCESS" "Green"
        }
        else {
            Write-Log "Basic internet connectivity: FAILED" "WARNING" "Yellow"
        }
    }
    catch {
        Write-Log "Network test failed: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    # Install IIS features
    Write-Log "Installing IIS and required features..." "INFO" "Yellow"
    $features = @(
        "IIS-WebServerRole", "IIS-WebServer", "IIS-CommonHttpFeatures",
        "IIS-HttpErrors", "IIS-HttpLogging", "IIS-HttpRedirect", 
        "IIS-ApplicationDevelopment", "IIS-NetFxExtensibility45",
        "IIS-HealthAndDiagnostics", "IIS-HttpTracing", "IIS-Security",
        "IIS-RequestFiltering", "IIS-Performance", "IIS-WebServerManagementTools",
        "IIS-ManagementConsole", "IIS-IIS6ManagementCompatibility", "IIS-Metabase",
        "IIS-ASPNET45"  # Added for ASP.NET support
    )
    
    try {
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $features -All -NoRestart
        Write-Log "IIS features installation completed" "SUCCESS" "Green"
    }
    catch {
        Write-Log "IIS features installation warning: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    # Download and install .NET 9.0 Hosting Bundle
    Write-Log "Downloading .NET 9.0 Hosting Bundle..." "INFO" "Yellow"
    
    $dotnetUrls = @(
        "https://dotnetcli.azureedge.net/dotnet/aspnetcore/Runtime/9.0.0/dotnet-hosting-9.0.0-win.exe",
        "https://download.visualstudio.microsoft.com/download/pr/72e8b5b6-9d9b-4199-9de2-b0a4c1f2c1a5/9e97b01255a14b2c8eca3d6f6b4e8b0f/dotnet-hosting-9.0.0-win.exe"
    )
    
    $dotnetInstaller = "$logDir\dotnet-hosting-bundle.exe"
    $dotnetDownloaded = $false
    
    foreach ($url in $dotnetUrls) {
        if (Download-FileAdvanced -Url $url -OutputPath $dotnetInstaller) {
            $dotnetDownloaded = $true
            break
        }
    }
    
    if ($dotnetDownloaded) {
        try {
            Write-Log "Installing .NET hosting bundle..." "INFO" "Yellow"
            $installProcess = Start-Process -FilePath $dotnetInstaller -ArgumentList "/quiet" -Wait -PassThru
            Write-Log ".NET installation completed with exit code: $($installProcess.ExitCode)" "INFO" "Cyan"
            
            if ($installProcess.ExitCode -eq 0) {
                Write-Log ".NET hosting bundle installed successfully" "SUCCESS" "Green"
            }
            else {
                Write-Log ".NET installation may have issues. Exit code: $($installProcess.ExitCode)" "WARNING" "Yellow"
            }
        }
        catch {
            Write-Log ".NET installation failed: $($_.Exception.Message)" "ERROR" "Red"
        }
    }
    else {
        Write-Log "Could not download .NET hosting bundle from any source" "WARNING" "Yellow"
    }
    
    # Restart IIS
    Write-Log "Restarting IIS..." "INFO" "Yellow"
    try {
        & iisreset /restart
        Start-Sleep -Seconds 10
        Write-Log "IIS restarted successfully" "SUCCESS" "Green"
    }
    catch {
        Write-Log "IIS restart warning: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    # Create application directory (fix path issue)
    $appPath = "C:\inetpub\wwwroot\$AppName"  # Remove extra quotes
    Write-Log "Creating application directory: $appPath" "INFO" "Yellow"
    if (Test-Path $appPath) {
        Remove-Item $appPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $appPath -Force
    
    # Download Blazor application
    if ($AppZipUrl -ne "") {
        Write-Log "Downloading Blazor application from: $AppZipUrl" "INFO" "Yellow"
        
        $appZip = "$logDir\blazorapp.zip"
        
        if (Download-FileAdvanced -Url $AppZipUrl -OutputPath $appZip) {
            try {
                Write-Log "Extracting application files..." "INFO" "Yellow"
                Expand-Archive -Path $appZip -DestinationPath $appPath -Force
                Write-Log "Blazor application deployed successfully" "SUCCESS" "Green"
            }
            catch {
                Write-Log "Could not extract application: $($_.Exception.Message)" "ERROR" "Red"
                # Create basic structure
                New-Item -ItemType Directory -Path "$appPath\wwwroot" -Force
            }
        }
        else {
            Write-Log "Could not download application. Creating placeholder structure." "WARNING" "Yellow"
            New-Item -ItemType Directory -Path "$appPath\wwwroot" -Force
        }
    }
    
    # Create appsettings.json
    if ($ConnectionString -ne "") {
        Write-Log "Creating appsettings.json..." "INFO" "Yellow"
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
        
        try {
            $appSettingsJson = $appSettings | ConvertTo-Json -Depth 4
            $appSettingsJson | Out-File -FilePath "$appPath\appsettings.json" -Encoding UTF8 -Force
            Write-Log "appsettings.json created successfully" "SUCCESS" "Green"
        }
        catch {
            Write-Log "Failed to create appsettings.json: $($_.Exception.Message)" "ERROR" "Red"
        }
    }
    
    # Create web.config
    Write-Log "Creating web.config..." "INFO" "Yellow"
    
    $mainDll = Get-ChildItem -Path $appPath -Filter "*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
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
    
    try {
        $webConfig | Out-File -FilePath "$appPath\web.config" -Encoding UTF8 -Force
        New-Item -ItemType Directory -Path "$appPath\logs" -Force
        Write-Log "web.config created successfully" "SUCCESS" "Green"
    }
    catch {
        Write-Log "Failed to create web.config: $($_.Exception.Message)" "ERROR" "Red"
    }
    
    # Create application pool using native methods
    $poolName = "${AppName}Pool"
    if (Create-IISAppPool -PoolName $poolName) {
        # Create IIS application
        $siteName = "Default Web Site"
        Create-IISApplication -SiteName $siteName -AppName $AppName -PhysicalPath $appPath -PoolName $poolName
    }
    
    # Test SQL Server connectivity (if connection string provided)
    if ($ConnectionString -ne "") {
        Write-Log "Testing SQL Server connectivity..." "INFO" "Yellow"
        try {
            $connectionTest = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $connectionTest.Open()
            $connectionTest.Close()
            Write-Log "SQL Server connection successful" "SUCCESS" "Green"
        }
        catch {
            Write-Log "SQL Server connection failed: $($_.Exception.Message)" "WARNING" "Yellow"
            Write-Log "This may require VPN connectivity to be established" "INFO" "Cyan"
        }
    }
    
    # Final summary
    Write-Log "=== Deployment Summary ===" "INFO" "Green"
    Write-Log "Server: $env:COMPUTERNAME" "INFO" "White"
    Write-Log "Application Pool: $poolName" "INFO" "White"
    Write-Log "Application Path: $appPath" "INFO" "White"
    Write-Log "Access URL: http://localhost/$AppName" "INFO" "Cyan"
    Write-Log "Logs available at: C:\temp\deployment.log" "INFO" "Cyan"
    Write-Log "Also at: C:\inetpub\wwwroot\deployment.log" "INFO" "Cyan"
    Write-Log "Deployment completed successfully" "SUCCESS" "Green"
    
    exit 0
}
catch {
    $errorMessage = "CRITICAL ERROR: $($_.Exception.Message)"
    Write-Log $errorMessage "ERROR" "Red"
    Write-Log "Stack trace: $($_.Exception.StackTrace)" "ERROR" "Red"
    exit 1
}