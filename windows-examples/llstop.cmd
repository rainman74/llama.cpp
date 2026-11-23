@echo off & setlocal enabledelayedexpansion

:INIT
set "PORTS=9931"
set "KILLED=0"

:MAIN
echo ============================================================
echo  Stop llama-server
echo  Port: %PORTS%
echo ============================================================
echo.

call :KILLNAME
echo.
call :PORTS

echo.
echo GPU memory now:
where nvidia-smi >nul 2>&1 && nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader

echo.
if "%KILLED%"=="0" (
  echo Result: nothing was running.
) else (
  echo Result: %KILLED% process^(es^) stopped.
)
goto :END

:KILLNAME
set "ANY="
for /f "tokens=2 delims=," %%A in ('tasklist /fi "imagename eq llama-server.exe" /fo csv /nh 2^>nul') do (
  set "PID=%%~A"
  if defined PID (
    set "ANY=1"
    echo  llama-server.exe PID !PID! stopping ...
    taskkill /f /pid !PID! >nul 2>&1
    if errorlevel 1 (
      echo    ERROR: access denied - is the server running as administrator?
      echo    Then run this script as administrator as well.
    ) else (
      echo    stopped
      set /a KILLED+=1
    )
    set "PID="
  )
)
if not defined ANY echo  No llama-server.exe found
exit /b 0

:PORTS
for %%P in (%PORTS%) do call :CHECKPORT %%P
exit /b 0

:CHECKPORT
set "OCC="
for /f "tokens=1" %%X in ('netstat -ano ^| findstr /c:":%~1 " ^| findstr /c:"0.0.0.0:0"') do set "OCC=1"
if defined OCC (
  echo  Port %~1: still in use
) else (
  echo  Port %~1: free
)
exit /b 0

:END
echo.
if "%~1"=="" (echo  Press any key to close ...& pause >nul)
endlocal
exit /b 0
