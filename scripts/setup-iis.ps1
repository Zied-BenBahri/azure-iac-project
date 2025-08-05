# Azure VM Custom Script Extension for Blazor App Deployment

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
$ErrorActionPreference = "Stop"

# Log function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] $Message"
    Add-Content -Path "C:\deployment.log" -Value "[$timestamp] $Message"
}

Write-Log "Starting Blazor application deployment..."

try {
    # 1. Install IIS and required features
    Write-Log "Installing IIS and ASP.NET Core features..."
    
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures, IIS-HttpErrors, IIS-HttpLogging, IIS-HttpRedirect, IIS-ApplicationDevelopment, IIS-NetFxExtensibility45, IIS-HealthAndDiagnostics, IIS-HttpLogging, IIS-Security, IIS-RequestFiltering, IIS-Performance, IIS-WebServerManagementTools, IIS-ManagementConsole, IIS-IIS6ManagementCompatibility, IIS-Metabase, IIS-ASPNET45 -All

    # 2. Download and install .NET 9 Runtime and ASP.NET Core Runtime
    Write-Log "Downloading and installing .NET 9 Runtime..."
    
    $dotnetUrl = "https://download.microsoft.com/download/7/8/b/78b69c87-8e04-4f9c-af70-7598b43af07e/dotnet-hosting-9.0.0-win.exe"
    $dotnetInstaller = "C:\temp\dotnet-hosting-9.0.0-win.exe"
    
    if (!(Test-Path "C:\temp")) {
        New-Item -ItemType Directory -Path "C:\temp" -Force
    }
    
    Invoke-WebRequest -Uri $dotnetUrl -OutFile $dotnetInstaller
    Start-Process -FilePath $dotnetInstaller -ArgumentList "/quiet" -Wait
    
    Write-Log ".NET 9 Hosting Bundle installed successfully"

    # 3. Install URL Rewrite Module
    Write-Log "Installing URL Rewrite Module..."
    $urlRewriteUrl = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
    $urlRewriteInstaller = "C:\temp\rewrite_amd64_en-US.msi"
    
    Invoke-WebRequest -Uri $urlRewriteUrl -OutFile $urlRewriteInstaller
    Start-Process msiexec.exe -ArgumentList "/i $urlRewriteInstaller /quiet" -Wait

    # 4. Create application directory
    Write-Log "Creating application directory..."
    $appPath = "C:\inetpub\wwwroot\$SiteName"
    if (Test-Path $appPath) {
        Remove-Item -Path $appPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $appPath -Force

    # 5. Download and extract application package
    Write-Log "Downloading application package from: $AppPackageUrl"
    $packagePath = "C:\temp\blazorapp.zip"
    Invoke-WebRequest -Uri $AppPackageUrl -OutFile $packagePath
    
    Write-Log "Extracting application package..."
    Expand-Archive -Path $packagePath -DestinationPath $appPath -Force

    # 6. Update connection string in appsettings.json
    Write-Log "Updating connection string..."
    $appsettingsPath = "$appPath\appsettings.json"
    if (Test-Path $appsettingsPath) {
        $appsettings = Get-Content $appsettingsPath | ConvertFrom-Json
        $connectionString = "Server=tcp:$DatabaseServer,1433;Database=$DatabaseName;User Id=$DatabaseUser;Password=$DatabasePassword;TrustServerCertificate=true;MultipleActiveResultSets=true;Connection Timeout=30;"
        $appsettings.ConnectionStrings.DefaultConnection = $connectionString
        $appsettings | ConvertTo-Json -Depth 10 | Set-Content $appsettingsPath
        Write-Log "Connection string updated successfully"
    }

    # 7. Import WebAdministration module
    Import-Module WebAdministration

    # 8. Create Application Pool
    Write-Log "Creating Application Pool..."
    $appPoolName = "$SiteName`_AppPool"
    
    if (Get-IISAppPool -Name $appPoolName -ErrorAction SilentlyContinue) {
        Remove-WebAppPool -Name $appPoolName
    }
    
    New-WebAppPool -Name $appPoolName
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "managedRuntimeVersion" -Value ""
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "startMode" -Value "AlwaysRunning"
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "processModel.idleTimeout" -Value "00:00:00"

    # 9. Create IIS Site
    Write-Log "Creating IIS Site..."
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Remove-Website -Name $SiteName
    }
    
    New-Website -Name $SiteName -Port 80 -PhysicalPath $appPath -ApplicationPool $appPoolName

    # 10. Set permissions
    Write-Log "Setting permissions..."
    $appPoolIdentity = "IIS AppPool\$appPoolName"
    icacls $appPath /grant "$($appPoolIdentity):(OI)(CI)F" /T

    # 11. Create web.config if it doesn't exist
    $webConfigPath = "$appPath\web.config"
    if (!(Test-Path $webConfigPath)) {
        Write-Log "Creating web.config..."
        $webConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="dotnet" arguments=".\BlazorApp1.dll" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="inprocess">
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
    }

    # 12. Create logs directory
    $logsPath = "$appPath\logs"
    if (!(Test-Path $logsPath)) {
        New-Item -ItemType Directory -Path $logsPath -Force
        icacls $logsPath /grant "$($appPoolIdentity):(OI)(CI)F" /T
    }

    # 13. Restart IIS
    Write-Log "Restarting IIS..."
    iisreset

    # 14. Start the website
    Start-Website -Name $SiteName
    Start-WebAppPool -Name $appPoolName

    Write-Log "Deployment completed successfully!"
    Write-Log "Application is available at: http://localhost"
    
    # Test the application
    Write-Log "Testing application..."
    try {
        $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 30
        if ($response.StatusCode -eq 200) {
            Write-Log "Application is responding correctly (Status: $($response.StatusCode))"
        }
        else {
            Write-Log "Application responded with status: $($response.StatusCode)"
        }
    }
    catch {
        Write-Log "Warning: Unable to test application - $($_.Exception.Message)"
    }

}
catch {
    Write-Log "Error during deployment: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.Exception.StackTrace)"
    throw
}