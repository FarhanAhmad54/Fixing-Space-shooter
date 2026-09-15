@echo off
setlocal
echo ======================================================
echo       STARFALL VENGEANCE - POKI PACKAGE BUILD
echo ======================================================
cd /d "%~dp0"
python tools\package_poki.py
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Packaging failed!
    exit /b %ERRORLEVEL%
)
echo [OK] Production packages ready:
echo      - poki-starfall-vengeance.zip
echo      - game.zip
pause
