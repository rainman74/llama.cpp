@echo off & setlocal enabledelayedexpansion

:INIT
set "BASE=%~dp0"
set "LLAMA_BIN=%BASE%llama-server.exe"
set "SLOTS=%BASE%slots"

set "MODELNAME=Inkling 2 Mini IQ2"
set "MODEL=%BASE%models\Inkling-2-Mini-UD-IQ2_XXS.gguf"
set "MMPROJ=%BASE%models\mmproj-F16.gguf"
set "DRAFT=%BASE%models\dspark-Inkling-2-Mini-Q8_0.gguf"
set "ALIAS=llama-home"
set "CTX=131072"
set "KVTYPE=q8_0"
set "LOADMODE=none"
set "THINK_BUDGET=2048"
set "SPEC_TYPE=draft-dspark"
set "PARALLEL=1"
set "VERBOSITY=3"
set "PORT=9931"
set "TEMP=1.0"
set "TOP_P=1.0"
set "TOP_K=0"
set "MIN_P=0.0"
set "BATCH=2048"
set "UBATCH=64"
set "KVFLAG=--no-kv-offload"
set "REASONING=auto"
set "BUDGET_TEXT=%THINK_BUDGET% Token"
if /i "%REASONING%"=="off" set "BUDGET_TEXT=0 Token (reasoning off)"

if defined DRAFT set DRAFT_ARGS=--model-draft "%DRAFT%" --spec-type %SPEC_TYPE% --spec-draft-n-max 2 --n-gpu-layers-draft 99
if not defined DRAFT set DRAFT_ARGS=--spec-type %SPEC_TYPE%

if not exist "%SLOTS%" mkdir "%SLOTS%"
if not exist "%LLAMA_BIN%" goto :NO_BIN
if not exist "%MODEL%"     goto :NO_MODEL
if not exist "%MMPROJ%"    goto :NO_MMPROJ
if defined DRAFT if not exist "%DRAFT%" goto :NO_DRAFT

:MAIN
echo ============================================================
echo  %MODELNAME%  ^|  ctx %CTX%  ^|  KV %KVTYPE%  ^|  Port %PORT%
echo  Model  : %MODEL%
echo  Vision : %MMPROJ%
if defined DRAFT echo  Drafter: %DRAFT%
echo  Alias  : %ALIAS%
echo  Budget : %BUDGET_TEXT%
echo ============================================================
echo.

start /b "" "%LLAMA_BIN%" ^
-m "%MODEL%" ^
--mmproj "%MMPROJ%" ^
%DRAFT_ARGS% ^
--ctx-size %CTX% ^
--parallel %PARALLEL% ^
-lv %VERBOSITY% ^
-b %BATCH% -ub %UBATCH% ^
--jinja ^
--cache-type-k %KVTYPE% --cache-type-v %KVTYPE% ^
--flash-attn on ^
%KVFLAG% ^
--moe-cache-mib auto ^
-lm %LOADMODE% ^
--no-reasoning-preserve ^
--reasoning-budget %THINK_BUDGET% ^
--reasoning %REASONING% ^
--temp %TEMP% --top-p %TOP_P% --top-k %TOP_K% --min-p %MIN_P% ^
--slot-save-path "%SLOTS%" ^
-a %ALIAS% ^
--host 0.0.0.0 --port %PORT%

timeout /t 3 >nul
start "" "http://localhost:%PORT%"
goto :END

:NO_BIN
echo ERROR: llama-server.exe not found: %LLAMA_BIN%
goto :FAIL

:NO_MODEL
echo ERROR: model not found: %MODEL%
goto :FAIL

:NO_MMPROJ
echo ERROR: vision projector not found: %MMPROJ%
goto :FAIL

:NO_DRAFT
echo ERROR: drafter not found: %DRAFT%
goto :FAIL

:FAIL
echo  Press any key to close ...
pause >nul
exit /b 1

:END
endlocal
exit /b 0
