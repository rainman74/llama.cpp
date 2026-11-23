@echo off & setlocal enabledelayedexpansion

:INIT
set "BASE=%~dp0"

:MAIN
echo ============================================================
echo  llama.cpp  ^|  help dump
echo ============================================================
echo.
if not exist "%BASE%llama-server.exe" goto :NO_BIN
"%BASE%llama-server.exe" --help >"%BASE%llama-server.txt"
"%BASE%llama-cli.exe" --help >"%BASE%llama-cli.txt"
echo  written: %BASE%llama-server.txt
echo  written: %BASE%llama-cli.txt
goto :END

:NO_BIN
echo ERROR: llama-server.exe not found: %BASE%llama-server.exe
goto :FAIL

:FAIL
echo.
echo  Press any key to close ...
pause >nul
exit /b 1

:END
echo.
if "%~1"=="" (echo  Press any key to close ...& pause >nul)
endlocal
exit /b 0
