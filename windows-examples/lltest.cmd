@echo off & setlocal enabledelayedexpansion

:INIT
set "PORT=9931"
set "ALIAS=llama-home"
set "QUESTION=What is 1+1?"
for /f "usebackq delims=" %%A in (`echo prompt $E^| cmd`) do set "ESC=%%A"
set "GREEN=%ESC%[32m"
set "RESET=%ESC%[0m"

:MAIN
echo ============================================================
echo  llama.cpp  ^|  API smoke test  ^|  Port %PORT%
echo  Model  : %ALIAS%
echo  Question: %QUESTION%
echo ============================================================
echo.
curl -s http://localhost:%PORT%/v1/chat/completions -H "content-type: application/json" -d "{\"model\": \"%ALIAS%\", \"messages\": [{\"role\": \"user\", \"content\": \"%QUESTION%\"}], \"n_predict\": 64}" | powershell -command "$obj = $input | ConvertFrom-Json; if (-not $obj.choices) { Write-Host '  no response - is the server running?'; return }; $c = $obj.choices[0].message.content; $t = $obj.timings.predicted_per_second; if ($c) { Write-Host ''; Write-Host '%GREEN%'$c'%RESET%' } else { Write-Host '  answer : (empty)' }; if ($t) { Write-Host ('  speed  : ' + [math]::Round($t,1) + ' t/s') }"
goto :END

:END
echo.
if "%~1"=="" (echo  Press any key to close ...& pause >nul)
endlocal
exit /b 0
