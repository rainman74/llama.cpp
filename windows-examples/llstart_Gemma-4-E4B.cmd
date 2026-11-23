@echo off & setlocal enabledelayedexpansion

:INIT
set "BASE=%~dp0"
set "LLAMA_BIN=%BASE%llama-cli.exe"

set "MODELNAME=Gemma 4 E4B"
set "MODEL=%BASE%models\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf"
set "MMPROJ=%BASE%models\mmproj-Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-f16.gguf"
set "DRAFT=%BASE%models\mtp-gemma-4-E4B-it-Q8_0.gguf"
set "CTX=131072"
set "KVTYPE=q8_0"
set "LOADMODE=none"
set "THINK_BUDGET=256"
set "SPEC_TYPE=draft-mtp"
set "VERBOSITY=3"
set "TEMP=1.0"
set "TOP_P=0.95"
set "TOP_K=64"
set "MIN_P=0"
set "BATCH=4096"
set "UBATCH=512"
set "KVFLAG=--kv-offload"
set "REASONING=auto"
set "BUDGET_TEXT=%THINK_BUDGET% Token"
if /i "%REASONING%"=="off" set "BUDGET_TEXT=0 Token (reasoning off)"
set "CHAT_TPL=%BASE%models\chat-template-gemma-4-exb.jinja"
set "SYSPROMPT=Antworte immer auf Deutsch."

if defined DRAFT set DRAFT_ARGS=--model-draft "%DRAFT%" --spec-type %SPEC_TYPE% --spec-draft-n-max 2 --n-gpu-layers-draft 99
if not defined DRAFT set DRAFT_ARGS=--spec-type %SPEC_TYPE%

if not exist "%LLAMA_BIN%" goto :NO_BIN
if not exist "%MODEL%"     goto :NO_MODEL
if not exist "%MMPROJ%"    goto :NO_MMPROJ
if defined DRAFT if not exist "%DRAFT%" goto :NO_DRAFT
if not exist "%CHAT_TPL%" goto :NO_TPL

:MAIN
echo ============================================================
echo  %MODELNAME%  ^|  ctx %CTX%  ^|  KV %KVTYPE%  ^|  CLI
echo  Model  : %MODEL%
echo  Vision : %MMPROJ%
if defined DRAFT echo  Drafter: %DRAFT%
echo  Budget : %BUDGET_TEXT%
echo  System : %SYSPROMPT%
echo ============================================================
echo.

"%LLAMA_BIN%" ^
-m "%MODEL%" ^
--mmproj "%MMPROJ%" ^
%DRAFT_ARGS% ^
--ctx-size %CTX% ^
-lv %VERBOSITY% ^
-b %BATCH% -ub %UBATCH% ^
--jinja ^
--chat-template-file "%CHAT_TPL%" ^
--cache-type-k %KVTYPE% --cache-type-v %KVTYPE% ^
--flash-attn on ^
%KVFLAG% ^
-lm %LOADMODE% ^
--no-reasoning-preserve ^
--reasoning-budget %THINK_BUDGET% ^
--reasoning %REASONING% ^
--temp %TEMP% --top-p %TOP_P% --top-k %TOP_K% --min-p %MIN_P% ^
-sys "%SYSPROMPT%" ^
--no-warmup ^
--no-show-timings

echo.
echo [cli] session ended.
goto :END

:NO_BIN
echo ERROR: llama-cli.exe not found: %LLAMA_BIN%
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

:NO_TPL
echo ERROR: chat template not found: %CHAT_TPL%
goto :FAIL

:FAIL
echo  Press any key to close ...
pause >nul
exit /b 1

:END
endlocal
exit /b 0