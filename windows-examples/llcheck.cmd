@echo off & setlocal enabledelayedexpansion

:INIT
set "BASE=%~dp0"

:MAIN
echo ============================================================
echo  llama.cpp  ^|  memory and GPU status
echo ============================================================
echo.
echo [RAM usage]
powershell -Command "$p = Get-Process llama-server -ErrorAction SilentlyContinue; if($p) { $ws = [math]::Round($p.WorkingSet64 / 1GB, 2); Write-Host 'llama-server uses: ' $ws ' GB physical RAM' } else { Write-Host 'llama-server is not running.' }"
echo.
echo [VRAM]
nvidia-smi --query-gpu=memory.total,memory.used,memory.free --format=csv,noheader,nounits | powershell -Command "$in = $input | Out-String; $a = $in.Split(','); Write-Host ('Total: ' + $a[0].Trim() + ' MB | Used: ' + $a[1].Trim() + ' MB | Free: ' + $a[2].Trim() + ' MB')"
echo.
echo [Compute processes]
nvidia-smi pmon -c 1 | powershell -Command "$input | Where-Object { $_ -match '#|Idx' -or ($_ -match '  C  ') }"
goto :END

:END
echo.
if "%~1"=="" (echo  Press any key to close ...& pause >nul)
endlocal
exit /b 0
