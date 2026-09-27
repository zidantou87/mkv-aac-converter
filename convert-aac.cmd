@echo off
rem ---------------------------------------------------------------------------
rem  Launcher for convert-aac.ps1  (Windows)
rem
rem  This file must stay ASCII-only. cmd.exe reads batch files using the console
rem  code page, so a non-ASCII byte here (a Chinese comment, or a reference to a
rem  Chinese-named script) becomes mojibake and the window vanishes before you
rem  can read the error. See docs/GOTCHAS.md.
rem
rem  It deliberately uses no goto labels, no if(...) blocks and no for in (...)
rem  sets:
rem    * release folder names such as "[Group] Show (AMZN 1920x1080 E-AC3)"
rem      contain parentheses, and the ")" inside them ends a block early;
rem    * GitHub's "Download ZIP" hands out the LF-normalised blob, and cmd.exe
rem      parses LF-only batch files unreliably once labels are involved.
rem  Straight-line commands survive all of that.
rem ---------------------------------------------------------------------------

set "AAC_TOOL=%~dp0"
set "AAC_FOLDER=%~dp0"
set "AAC_PS1=%~dp0convert-aac.ps1"
set "AAC_RC=1"

if not "%~1"=="" set "AAC_FOLDER=%~1"

rem Paths are passed through environment variables rather than as quoted
rem arguments: a folder name containing a single quote would otherwise break
rem out of the PowerShell string literal.
if not exist "%AAC_PS1%" echo [ERROR] convert-aac.ps1 was not found next to this .cmd file.
if exist "%AAC_PS1%" powershell -NoProfile -ExecutionPolicy Bypass -Command "$sb=[scriptblock]::Create((Get-Content -LiteralPath $env:AAC_PS1 -Raw -Encoding UTF8)); & $sb -Folder $env:AAC_FOLDER -ToolDir $env:AAC_TOOL"
if exist "%AAC_PS1%" set "AAC_RC=%ERRORLEVEL%"

echo.
echo --- finished (exit code %AAC_RC%) ---
pause
exit /b %AAC_RC%
