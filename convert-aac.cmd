@echo off
rem ---------------------------------------------------------------------------
rem  Launcher for convert-aac.ps1  (Windows)
rem
rem  This file must stay ASCII-only. cmd.exe reads batch files using the console
rem  code page, so a non-ASCII byte here (a Chinese comment, or a reference to a
rem  Chinese-named script) becomes mojibake and the window vanishes before you
rem  can read the error. See docs/GOTCHAS.md.
rem
rem  It also avoids if(...) and for in (...) blocks on purpose: release folder
rem  names such as "[Group] Show (AMZN 1920x1080 E-AC3)" contain parentheses,
rem  and the ")" inside them ends the block early.
rem ---------------------------------------------------------------------------

set "AAC_TOOL=%~dp0"
set "AAC_FOLDER=%~dp0"
set "AAC_PS1=%~dp0convert-aac.ps1"

if not exist "%AAC_PS1%" goto :missing
if not "%~1"=="" set "AAC_FOLDER=%~1"

rem Paths are passed through environment variables rather than as quoted
rem arguments: a folder name containing a single quote would otherwise break
rem out of the PowerShell string literal.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$sb=[scriptblock]::Create((Get-Content -LiteralPath $env:AAC_PS1 -Raw -Encoding UTF8)); & $sb -Folder $env:AAC_FOLDER -ToolDir $env:AAC_TOOL"
goto :done

:missing
echo.
echo [ERROR] convert-aac.ps1 was not found.
echo         It must sit in the same folder as this .cmd file.
echo         Folder: %~dp0

:done
echo.
echo --- finished (exit code %ERRORLEVEL%) ---
pause
