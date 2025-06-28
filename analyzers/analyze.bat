@echo off
setlocal

:: Script path (you can adapt if needed)
set PS_SCRIPT=SingleLoudnessAnalysis.ps1

:: Optional: absolute path example
:: set PS_SCRIPT=SingleLoudnessAnalysis.ps1

:: Run the PowerShell script
powershell -ExecutionPolicy Bypass -NoProfile -File "%PS_SCRIPT%"

endlocal
pause
