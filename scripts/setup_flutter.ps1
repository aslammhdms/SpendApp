# SpendSheet - Flutter Setup Script for Windows
# Run this script in PowerShell as Administrator

$ErrorActionPreference = "Stop"
$FlutterVersion = "3.50.0"
$FlutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip"
$FlutterPath = "C:\flutter"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SpendSheet - Flutter Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is already installed
if (Test-Path "$FlutterPath\bin\flutter.bat") {
    Write-Host "Flutter is already installed at $FlutterPath" -ForegroundColor Green
    & "$FlutterPath\bin\flutter.bat" --version
} else {
    Write-Host "Downloading Flutter SDK v$FlutterVersion..." -ForegroundColor Yellow
    Write-Host "This may take 5-10 minutes depending on your internet speed."
    Write-Host ""

    # Create directory
    if (-not (Test-Path $FlutterPath)) {
        New-Item -ItemType Directory -Path $FlutterPath -Force | Out-Null
    }

    # Download Flutter
    $zipPath = "$FlutterPath\flutter.zip"

    # Use BITS for faster download with progress
    Start-BitsTransfer -Source $FlutterUrl -Destination $zipPath -DisplayName "Downloading Flutter SDK"

    Write-Host ""
    Write-Host "Extracting Flutter SDK..." -ForegroundColor Yellow

    # Extract
    Expand-Archive -Path $zipPath -DestinationPath $FlutterPath -Force

    # Move contents up one level (archive extracts to flutter/flutter)
    if (Test-Path "$FlutterPath\flutter") {
        Get-ChildItem "$FlutterPath\flutter" | Move-Item -Destination $FlutterPath -Force
        Remove-Item "$FlutterPath\flutter" -Force -Recurse -ErrorAction SilentlyContinue
    }

    # Clean up
    Remove-Item $zipPath -Force

    Write-Host "Flutter installed successfully!" -ForegroundColor Green
}

# Add to PATH for current session
$env:Path = "$FlutterPath\bin;$env:Path"

# Add to system PATH permanently
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$FlutterPath\bin*") {
    Write-Host ""
    Write-Host "Adding Flutter to system PATH..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("Path", "$FlutterPath\bin;$currentPath", "User")
    Write-Host "Flutter added to PATH. Please restart your terminal." -ForegroundColor Green
}

Write-Host ""
Write-Host "Running Flutter doctor..." -ForegroundColor Yellow
Write-Host ""

& "$FlutterPath\bin\flutter.bat" doctor

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter setup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart your terminal"
Write-Host "2. Run: cd C:\Personal\Spendapp\spendsheet"
Write-Host "3. Run: flutter pub get"
Write-Host "4. Run: flutter pub run build_runner build"
Write-Host ""
