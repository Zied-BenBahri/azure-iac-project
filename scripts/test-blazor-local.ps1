# Local Blazor App Testing Script
param(
    [Parameter(Mandatory = $false)]
    [string]$AppPackageUrl = "https://github.com/Zied-BenBahri/azure-iac-project/releases/download/v1.0.0/blazorapp.zip",
    
    [Parameter(Mandatory = $false)]
    [string]$TestDirectory = "C:\temp\blazor-test",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseServer = "87.74.128.223",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseName = "BlazorCrudApp",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseUser = "blazoruser",
    
    [Parameter(Mandatory = $false)]
    [string]$DatabasePassword = "BlazorApp2024!"
)

Write-Host "=== Local Blazor App Testing ===" -ForegroundColor Green

try {
    # Create test directory
    Write-Host "Creating test directory..." -ForegroundColor Yellow
    if (Test-Path $TestDirectory) {
        Remove-Item -Path $TestDirectory -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TestDirectory -Force

    # Download the app package
    Write-Host "Downloading application package..." -ForegroundColor Yellow
    $packagePath = "$TestDirectory\blazorapp.zip"
    Invoke-WebRequest -Uri $AppPackageUrl -OutFile $packagePath -UseBasicParsing
    
    # Extract the package
    Write-Host "Extracting application..." -ForegroundColor Yellow
    Expand-Archive -Path $packagePath -DestinationPath $TestDirectory -Force
    
    # Analyze the deployment
    Write-Host "`n=== DEPLOYMENT ANALYSIS ===" -ForegroundColor Cyan
    
    # Check for main executable files
    $exeFiles = Get-ChildItem -Path $TestDirectory -Filter "*.exe" -ErrorAction SilentlyContinue
    $dllFiles = Get-ChildItem -Path $TestDirectory -Filter "*.dll" -ErrorAction SilentlyContinue
    $runtimeConfigs = Get-ChildItem -Path $TestDirectory -Filter "*.runtimeconfig.json" -ErrorAction SilentlyContinue
    
    Write-Host "Files found:" -ForegroundColor White
    Write-Host "  - EXE files: $($exeFiles.Count)" -ForegroundColor $(if($exeFiles.Count -gt 0) {'Green'} else {'Red'})
    Write-Host "  - DLL files: $($dllFiles.Count)" -ForegroundColor $(if($dllFiles.Count -gt 0) {'Green'} else {'Red'})
    Write-Host "  - Runtime configs: $($runtimeConfigs.Count)" -ForegroundColor $(if($runtimeConfigs.Count -gt 0) {'Green'} else {'Red'})
    
    # Determine deployment type
    if ($exeFiles.Count -gt 0) {
        $deploymentType = "Self-Contained"
        $mainExecutable = $exeFiles[0].FullName
        Write-Host "Self-contained deployment detected" -ForegroundColor Green
        Write-Host "  Main executable: $($exeFiles[0].Name)" -ForegroundColor White
    } elseif ($dllFiles.Count -gt 0 -and $runtimeConfigs.Count -gt 0) {
        $deploymentType = "Framework-Dependent"
        $mainDll = $dllFiles | Where-Object { $_.Name -notlike "*.Views.dll" -and $_.Name -notlike "*.resources.dll" } | Select-Object -First 1
        Write-Host "Framework-dependent deployment detected" -ForegroundColor Green
        Write-Host "  Main DLL: $($mainDll.Name)" -ForegroundColor White
    } else {
        Write-Host "❌ Unable to determine deployment type" -ForegroundColor Red
        throw "Invalid deployment package"
    }
    
    # Check for appsettings.json
    $appsettingsPath = "$TestDirectory\appsettings.json"
    if (Test-Path $appsettingsPath) {
        Write-Host "appsettings.json found" -ForegroundColor Green
        
        # Update connection string for testing
        Write-Host "Updating connection string for local testing..." -ForegroundColor Yellow
        try {
            $appsettings = Get-Content $appsettingsPath -Raw | ConvertFrom-Json
            $connectionString = "Server=tcp:$DatabaseServer,1433;Database=$DatabaseName;User Id=$DatabaseUser;Password=$DatabasePassword;TrustServerCertificate=true;MultipleActiveResultSets=true;Connection Timeout=30;"
            
            if (-not $appsettings.ConnectionStrings) {
                $appsettings | Add-Member -Type NoteProperty -Name ConnectionStrings -Value @{}
            }
            $appsettings.ConnectionStrings.DefaultConnection = $connectionString
            
            $appsettings | ConvertTo-Json -Depth 10 | Set-Content $appsettingsPath -Encoding UTF8
            Write-Host "Connection string updated successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Warning: Could not update connection string - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ appsettings.json not found" -ForegroundColor Yellow
    }
    
    # Check for common dependencies
    Write-Host "`n=== DEPENDENCY CHECK ===" -ForegroundColor Cyan
    $commonDlls = @(
        "Microsoft.AspNetCore.dll",
        "Microsoft.Extensions.DependencyInjection.dll",
        "System.Text.Json.dll",
        "Microsoft.EntityFrameworkCore.dll"
    )
    
    foreach ($dll in $commonDlls) {
        $found = Get-ChildItem -Path $TestDirectory -Filter $dll -Recurse -ErrorAction SilentlyContinue
        if ($found) {
            Write-Host "$dll found" -ForegroundColor Green
        } else {
            Write-Host "$dll not found" -ForegroundColor Yellow
        }
    }
    
    # Test the application
    Write-Host "`n=== TESTING APPLICATION ===" -ForegroundColor Cyan
    
    if ($deploymentType -eq "Self-Contained") {
        Write-Host "Starting self-contained application..." -ForegroundColor Yellow
        Write-Host "Command: $mainExecutable" -ForegroundColor Gray
        Write-Host "Press Ctrl+C to stop the application when done testing." -ForegroundColor Yellow
        
        # Start the application
        Set-Location -Path $TestDirectory
        & $mainExecutable
        
    } else {
        # Framework-dependent - need dotnet command
        Write-Host "Starting framework-dependent application..." -ForegroundColor Yellow
        Write-Host "Command: dotnet $($mainDll.Name)" -ForegroundColor Gray
        Write-Host "Press Ctrl+C to stop the application when done testing." -ForegroundColor Yellow
        
        # Check if dotnet is available
        try {
            $dotnetVersion = dotnet --version
            Write-Host ".NET CLI available (version: $dotnetVersion)" -ForegroundColor Green
            
            Set-Location -Path $TestDirectory
            & dotnet $mainDll.Name
            
        } catch {
            Write-Host "❌ .NET CLI not found. Please install .NET SDK or Runtime" -ForegroundColor Red
            Write-Host "Download from: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Host "❌ Error during testing: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.Exception.StackTrace)" -ForegroundColor Red
} finally {
    Write-Host "`n=== Testing completed ===" -ForegroundColor Green
    Write-Host "Test files are located at: $TestDirectory" -ForegroundColor White
    Write-Host "You can manually inspect the files or run the application again." -ForegroundColor White
}
