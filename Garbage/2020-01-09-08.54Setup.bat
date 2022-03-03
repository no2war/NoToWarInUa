@echo off
rem Use OEM-866 (Cyrillic) encoding

setlocal EnableExtensions
setlocal EnableDelayedExpansion

set "DefaultAddress=https://localhost/tessa"
set "DefaultFiles=C:\Tessa\Files"
set "DefaultDatabaseMessage=from app.json, don't create db"

set "Login=admin"
set "Password=admin"
set "Connection=default"
set "CheckTimeout=20"

set "Configuration=..\Configuration"
set "Fixes=..\Fixes"

set "CurrentDir=%~dp0"
if "%CurrentDir:~-1%" == "\" (
    set "CurrentDir=%CurrentDir:~0,-1%"
)

set "Tools=%CurrentDir%\Tools"
pushd "%Tools%"

:Start
cls
echo This script will install Tessa to a new database
echo;
echo Please check connection string prior to installation in configuration file:
echo %Tools%\app.json
echo;
set /P Address="Service address, press Enter to use default [%DefaultAddress%]: "
if "%Address%"=="" set "Address=%DefaultAddress%"
echo;
set /P Database="Database name, press Enter to use default [%DefaultDatabaseMessage%]: "
echo;
set /P Files="Files folder, press Enter to use default [%DefaultFiles%]: "
if "%Files%"=="" set "Files=%DefaultFiles%"
echo;
echo [Address] = %Address%
if "%Database%"=="" (
echo [Database] = %DefaultDatabaseMessage%
) else (
echo [Database] = %Database%
)
echo [Files] = %Files%
echo;
echo Press any key to begin installation...
pause>nul

cls
echo Installing Tessa
echo;
echo [Address] = %Address%
if "%Database%"=="" (
echo [Database] = %DefaultDatabaseMessage%
) else (
echo [Database] = %Database%
)
echo [Files] = %Files%
echo;

if "%Database%"=="" (
set DbParam=
) else (
set DbParam="/db:%Database%"
)

echo  ^> Checking connection to database server
tadmin CheckDatabase /c "/cs:%Connection%" /timeout:%CheckTimeout% /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

for /f "tokens=* usebackq" %%f in (`tadmin CheckDatabase "/cs:%Connection%" /timeout:%CheckTimeout% /dbms`) do set dbms=%%f
echo    DBMS = %dbms%
echo;
if "%dbms%"=="" goto :Fail

if "%Database%"=="" goto :DatabaseIsCreated

echo  ^> Creating database
tadmin CreateDatabase %DbParam% "/cs:%Connection%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

:DatabaseIsCreated

echo  ^> Importing scheme
tadmin ImportSchemeSql "%Configuration%\Scheme" %DbParam% "/cs:%Connection%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo;

echo  ^> Checking connection to web service
tadmin CheckService "/a:%Address%" "/u:%Login%" "/p:%Password%" /timeout:%CheckTimeout% /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo  ^> Importing localization
tadmin ImportLocalization "%Configuration%\Localization" "/a:%Address%" "/u:%Login%" "/p:%Password%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo  ^> Importing types
tadmin ImportTypes "%Configuration%\Types" "/a:%Address%" "/u:%Login%" "/p:%Password%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo  ^> Importing cards
tadmin ImportCards "%Configuration%\Cards\Tessa.%dbms%.cardlib" "/a:%Address%" "/u:%Login%" "/p:%Password%" /e /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo  ^> Setting up files folder
tadmin FileSource 2 "/f:%Files%" "/a:%Address%" "/u:%Login%" "/p:%Password%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo  ^> Importing file templates
tadmin ImportCards "%Configuration%\Cards\File templates.cardlib" "/a:%Address%" "/u:%Login%" "/p:%Password%" /e /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo  ^> Importing views
tadmin ImportViews "%Configuration%\Views" "/a:%Address%" "/u:%Login%" "/p:%Password%" /r /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo  ^> Importing workplaces
tadmin ImportWorkplaces "%Configuration%\Workplaces" "/a:%Address%" "/u:%Login%" "/p:%Password%" /r /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo;

echo  ^> Rebuilding calendar
tadmin RebuildCalendar "/a:%Address%" "/u:%Login%" "/p:%Password%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo  ^> Rebuilding indexes
tadmin Sql "%Fixes%\RebuildIndexes.%dbms%.sql" %DbParam% "/cs:%Connection%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo;
echo Tessa is installed. Please, restart application pool and start Chronos.
echo Press any key to close...
pause>nul
cls
goto :Finish

:Fail
echo;
echo Installation failed with error code: %ErrorLevel%
echo See the details in log file: %Tools%\log.txt
echo;
echo Press any key to close...
pause>nul
cls
goto :Finish

:Finish
endlocal
goto :EOF
