@echo off

setlocal



set MOD_NAME=Monorail Tracks

set SOURCE=%~dp0%MOD_NAME%

set DEST=%APPDATA%\SpaceEngineers\Mods\%MOD_NAME%



goto :main



:log

for /f "usebackq tokens=*" %%t in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do (

    if "%~1"=="" (echo.) else echo [%%t] %~1

)

exit /b 0



:main

call :log ""

call :log "Deploying %MOD_NAME%"

call :log "  From: %SOURCE%"

call :log "  To:   %DEST%"

call :log ""



if not exist "%SOURCE%" (

    call :log "ERROR: Source folder not found: %SOURCE%"

    exit /b 1

)



if exist "%DEST%" (

    call :log "Removing existing deployment..."

    rmdir /s /q "%DEST%"

)



xcopy /E /Y /I "%SOURCE%\Data" "%DEST%\Data" >nul

if errorlevel 1 (

    call :log "ERROR: failed copying Data"

    exit /b 1

)



xcopy /E /Y /I "%SOURCE%\Textures" "%DEST%\Textures" >nul

if errorlevel 1 (

    call :log "ERROR: failed copying Textures"

    exit /b 1

)



xcopy /E /Y /I "%SOURCE%\Models" "%DEST%\Models" >nul

if errorlevel 1 (

    call :log "ERROR: failed copying Models"

    exit /b 1

)

xcopy /E /Y /I "%SOURCE%\thumb.jpg" "%DEST%\" >nul

if errorlevel 1 (

    call :log "ERROR: failed copying thumb.jpg"

    exit /b 1

)



copy /Y "%SOURCE%\modinfo.sbm" "%DEST%\modinfo.sbm" >nul

if errorlevel 1 (

    call :log "ERROR: failed copying modinfo.sbm"

    exit /b 1

)



call :log "Done. Mod deployed to:"

call :log "  %DEST%"

exit /b 0


