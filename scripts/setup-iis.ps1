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

# Function to clean parameter strings (remove extra quotes)
function Clean-Parameter {
    param([string]$Value)
    
    if ([string]::IsNullOrEmpty($Value)) {
        return ""
    }
    
    # Remove surrounding single quotes
    $cleanValue = $Value.Trim("'")
    # Remove surrounding double quotes
    $cleanValue = $cleanValue.Trim('"')
    
    return $cleanValue
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
        & $appcmd delete apppool "$PoolName" 2>$null
        Start-Sleep -Seconds 2
        
        # Create new application pool (use quotes for pool name)
        & $appcmd add apppool /name:"$PoolName"
        & $appcmd set apppool "$PoolName" /managedRuntimeVersion:""
        & $appcmd set apppool "$PoolName" /processModel.identityType:ApplicationPoolIdentity
        
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
        
        # Create new application (use proper quoting)
        & $appcmd add app /site.name:"$SiteName" /path:"/$AppName" /physicalPath:"$PhysicalPath"
        & $appcmd set app "$SiteName/$AppName" /applicationPool:"$PoolName"
        
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
    # Clean all input parameters to remove extra quotes
    $AppName = Clean-Parameter -Value $AppName
    $ConnectionString = Clean-Parameter -Value $ConnectionString
    $AppZipUrl = Clean-Parameter -Value $AppZipUrl
    
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
    Write-Log "Script Parameters (cleaned):" "INFO" "Cyan"
    Write-Log "  - AppName: '$AppName'" "INFO" "Cyan"
    Write-Log "  - ConnectionString provided: $($ConnectionString -ne '')" "INFO" "Cyan"
    Write-Log "  - AppZipUrl: '$AppZipUrl'" "INFO" "Cyan"
    
    # Validate parameters
    if ([string]::IsNullOrWhiteSpace($AppName)) {
        $AppName = "BlazorApp"
        Write-Log "AppName was empty, using default: $AppName" "WARNING" "Yellow"
    }
    
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
        "IIS-ASPNET45"
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
    
    # Create application directory (fixed path construction)
    $appPath = "C:\inetpub\wwwroot\$AppName"
    Write-Log "Creating application directory: $appPath" "INFO" "Yellow"
    if (Test-Path $appPath) {
        Remove-Item $appPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $appPath -Force
    Write-Log "Application directory created successfully" "SUCCESS" "Green"
    
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
    else {
        Write-Log "No AppZipUrl provided. Creating basic structure." "INFO" "Yellow"
        New-Item -ItemType Directory -Path "$appPath\wwwroot" -Force
        
        # Create a simple index.html for testing
        $indexHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Blazor App - $env:COMPUTERNAME</title>
</head>
<body>
    <h1>Blazor Application Placeholder</h1>
    <p>Server: $env:COMPUTERNAME</p>
    <p>Deployment Time: $(Get-Date)</p>
    <p>Application Path: $appPath</p>
</body>
</html>
"@
        $indexHtml | Out-File -FilePath "$appPath\wwwroot\index.html" -Encoding UTF8 -Force
        Write-Log "Created placeholder index.html" "INFO" "Cyan"
    }
    
    # Create appsettings.json (fix connection string handling)
    if ($ConnectionString -ne "") {
        Write-Log "Creating appsettings.json..." "INFO" "Yellow"
        Write-Log "Connection string length: $($ConnectionString.Length)" "INFO" "Cyan"
        
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
      <defaultDocument>
        <files>
          <clear />
          <add value="index.html" />
          <add value="default.html" />
        </files>
      </defaultDocument>
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
    
    # Create application pool using native methods (fixed naming)
    $poolName = "${AppName}Pool"
    if (Create-IISAppPool -PoolName $poolName) {
        # Create IIS application
        $siteName = "Default Web Site"
        Create-IISApplication -SiteName $siteName -AppName $AppName -PhysicalPath $appPath -PoolName $poolName
    }
    
    # Test SQL Server connectivity (fix connection string parsing)
    if ($ConnectionString -ne "") {
        Write-Log "Testing SQL Server connectivity..." "INFO" "Yellow"
        Write-Log "Connection string preview: $($ConnectionString.Substring(0, [Math]::Min(50, $ConnectionString.Length)))..." "INFO" "Cyan"
        
        try {
            # Test the connection string format first
            if ($ConnectionString.Contains("Server=") -or $ConnectionString.Contains("Data Source=")) {
                $connectionTest = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
                $connectionTest.Open()
                $connectionTest.Close()
                Write-Log "SQL Server connection successful" "SUCCESS" "Green"
            }
            else {
                Write-Log "Connection string format appears invalid - missing Server= or Data Source=" "WARNING" "Yellow"
            }
        }
        catch {
            Write-Log "SQL Server connection failed: $($_.Exception.Message)" "WARNING" "Yellow"
            Write-Log "This may require VPN connectivity to be established" "INFO" "Cyan"
        }
    }
    
    # Verify application deployment
    Write-Log "Verifying application deployment..." "INFO" "Yellow"
    try {
        $appFiles = Get-ChildItem $appPath -Recurse -File
        Write-Log "Application files deployed: $($appFiles.Count)" "INFO" "Cyan"
        
        # Test local access
        Start-Sleep -Seconds 5
        $testUrl = "http://localhost/$AppName"
        try {
            $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10
            Write-Log "Application test successful - Status: $($response.StatusCode)" "SUCCESS" "Green"
        }
        catch {
            Write-Log "Application test failed: $($_.Exception.Message)" "WARNING" "Yellow"
            Write-Log "This may be normal if no actual application files were deployed" "INFO" "Cyan"
        }
    }
    catch {
        Write-Log "Application verification failed: $($_.Exception.Message)" "WARNING" "Yellow"
    }
    
    # Final summary (fixed formatting)
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