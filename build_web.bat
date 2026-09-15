@echo off
setlocal
echo ======================================================
echo    STARFALL VENGEANCE - BUILD WEB
echo ======================================================
cd /d "%~dp0"
python tools\build_web.py
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Web build failed!
    exit /b %ERRORLEVEL%
)
echo [OK] Web build successful in web\dist\
