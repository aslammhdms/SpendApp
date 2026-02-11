@echo off
echo ========================================
echo SpendSheet - Quick Setup
echo ========================================
echo.
echo This will set up Flutter and the project.
echo.
echo Step 1: Installing Flutter...
powershell -ExecutionPolicy Bypass -File "%~dp0setup_flutter.ps1"
echo.
echo Step 2: Setting up project...
powershell -ExecutionPolicy Bypass -File "%~dp0setup_project.ps1"
echo.
echo Setup complete! See instructions above.
pause
