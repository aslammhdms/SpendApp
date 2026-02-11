# SpendSheet - Project Setup Script
# Run this after Flutter is installed

$ErrorActionPreference = "Stop"
$ProjectPath = "C:\Personal\Spendapp\spendsheet"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SpendSheet - Project Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Flutter
$flutterPath = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutterPath) {
    $flutterPath = "C:\flutter\bin\flutter.bat"
    if (-not (Test-Path $flutterPath)) {
        Write-Host "Flutter not found! Please run setup_flutter.ps1 first." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Using Flutter at: $flutterPath" -ForegroundColor Gray
Write-Host ""

# Navigate to project
Set-Location $ProjectPath

Write-Host "Step 1: Getting dependencies..." -ForegroundColor Yellow
& flutter pub get

Write-Host ""
Write-Host "Step 2: Generating code (Freezed, JSON serializable)..." -ForegroundColor Yellow
& flutter pub run build_runner build --delete-conflicting-outputs

Write-Host ""
Write-Host "Step 3: Checking project..." -ForegroundColor Yellow
& flutter analyze --no-fatal-infos

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project setup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To run the app:" -ForegroundColor Yellow
Write-Host "  flutter run"
Write-Host ""
Write-Host "IMPORTANT: Before running, you need to set up Google Cloud:" -ForegroundColor Red
Write-Host "1. Go to https://console.cloud.google.com"
Write-Host "2. Create a new project"
Write-Host "3. Enable 'Google Sheets API' and 'Google Drive API'"
Write-Host "4. Configure OAuth consent screen"
Write-Host "5. Create OAuth 2.0 Client ID for Android"
Write-Host "   - Get your SHA-1: cd android && ./gradlew signingReport"
Write-Host "   - Package name: com.spendsheet.spendsheet"
Write-Host ""
