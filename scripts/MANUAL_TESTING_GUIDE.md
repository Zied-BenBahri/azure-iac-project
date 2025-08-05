# Manual Testing Steps for Blazor App

## Quick Manual Test Commands

### Step 1: Download and Extract
# Create test directory
New-Item -ItemType Directory -Path "C:\temp\blazor-test" -Force

# Download your app
Invoke-WebRequest -Uri "https://github.com/Zied-BenBahri/azure-iac-project/releases/download/v1.0.0/blazorapp.zip" -OutFile "C:\temp\blazor-test\blazorapp.zip"

# Extract
Expand-Archive -Path "C:\temp\blazor-test\blazorapp.zip" -DestinationPath "C:\temp\blazor-test" -Force

### Step 2: Analyze the Deployment
# Navigate to the directory
Set-Location "C:\temp\blazor-test"

# Check what files are present
Get-ChildItem -Recurse | Select-Object Name, Length, Extension | Format-Table

# Look for main executable or DLL
Get-ChildItem -Filter "*.exe"
Get-ChildItem -Filter "*.dll" | Where-Object { $_.Name -notlike "*.Views.dll" -and $_.Name -notlike "*.resources.dll" }

### Step 3: Run the Application

# Option A: If you find an .exe file (self-contained)
.\YourAppName.exe

# Option B: If you find a main .dll file (framework-dependent)
dotnet .\YourAppName.dll

# Option C: If you have a specific DLL name
dotnet .\BlazorApp1.dll

### Step 4: Test in Browser
# Once the app starts, it will show something like:
# "Now listening on: http://localhost:5000"
# Open your browser and go to that URL

### Step 5: Check for Common Issues
# Look for these files to ensure completeness:
# - appsettings.json (configuration)
# - web.config (for IIS deployment)
# - wwwroot folder (static files)
# - Main DLL or EXE file

### Step 6: Database Connection Test
# If the app starts but has database errors, check:
# - Connection string in appsettings.json
# - Database server accessibility (ping 172.16.0.130)
# - SQL Server port 1433 accessibility

### Troubleshooting Commands
# Check .NET version
dotnet --version

# Check if SQL Server is accessible
Test-NetConnection -ComputerName "172.16.0.130" -Port 1433

# View application logs (if any errors occur)
Get-ChildItem -Path "." -Filter "*.log" -Recurse
