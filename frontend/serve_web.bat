@echo off
echo Serving Flutter web app locally...

cd /d "%~dp0\build\web"

echo Starting local server on http://localhost:8000
echo Press Ctrl+C to stop the server
echo.

python -m http.server 8000

pause
