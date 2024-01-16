@echo off

NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO Requesting administrative privileges...
    GOTO UACPrompt
) ELSE (
    GOTO StartPowerShell
)

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:StartPowerShell
    :: Start PowerShell with ExecutionPolicy Bypass
    PowerShell.exe -ExecutionPolicy Bypass
    exit /B
