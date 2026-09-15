@echo off
setlocal
echo ======================================================
echo    STARFALL VENGEANCE - CRAZYGAMES PACKAGE
echo ======================================================
cd /d "%~dp0"
python tools\package_crazygames.py
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Packaging failed!
    exit /b %ERRORLEVEL%
)
echo [OK] crazygames-starfall-vengeance.zip is ready for upload!
