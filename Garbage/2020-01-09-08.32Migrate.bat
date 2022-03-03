@echo off
rem Use OEM-866 (Cyrillic) encoding

setlocal EnableExtensions
setlocal EnableDelayedExpansion

set "DefaultAddress=https://localhost/tessa"
set "DefaultDatabaseMessage=from app.json, don't create db"

set "Login=admin"
set "Password=admin"
set "SourceConnection=default"
set "TargetConnection=migration"
set "CheckTimeout=120"

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
echo This script will migrate Tessa to a new database
echo;
echo Please check connection strings "default" (source) and "migration" (target)
echo prior to migration in configuration file:
echo %Tools%\app.json
echo;
set /P Address="Service address connected to target database, press Enter to use default [%DefaultAddress%]: "
if "%Address%"=="" set "Address=%DefaultAddress%"
echo;
set /P Database="Target database name, press Enter to use default [%DefaultDatabaseMessage%]: "
echo;
echo [Address] = %Address%
if "%Database%"=="" (
echo [Database] = %DefaultDatabaseMessage%
) else (
echo [Database] = %Database%
)
echo;
echo Press any key to begin migration...
pause>nul

cls
echo Migrating Tessa
echo;
echo [Address] = %Address%
if "%Database%"=="" (
echo [Database] = %DefaultDatabaseMessage%
) else (
echo [Database] = %Database%
)
echo;

if "%Database%"=="" (
set DbParam=
set TDbParam=
) else (
set DbParam="/db:%Database%"
set TDbParam="/tdb:%Database%"
)

echo  ^> Checking connection to source database server
tadmin CheckDatabase /c "/cs:%SourceConnection%" /timeout:%CheckTimeout% /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

for /f "tokens=* usebackq" %%f in (`tadmin CheckDatabase "/cs:%SourceConnection%" /timeout:%CheckTimeout% /dbms`) do set SourceDbms=%%f
echo    DBMS = %SourceDbms%
echo;
if "%SourceDbms%"=="" goto :Fail

echo  ^> Checking connection to target database server
tadmin CheckDatabase /c "/cs:%TargetConnection%" /timeout:%CheckTimeout% /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

for /f "tokens=* usebackq" %%f in (`tadmin CheckDatabase "/cs:%TargetConnection%" /timeout:%CheckTimeout% /dbms`) do set dbms=%%f
echo    DBMS = %dbms%
echo;
if "%dbms%"=="" goto :Fail

if "%Database%"=="" goto :DatabaseIsCreated

echo  ^> Creating database
tadmin CreateDatabase %DbParam% "/cs:%TargetConnection%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

:DatabaseIsCreated

echo;

echo  ^> Migrating database
tadmin MigrateDatabase "%TargetConnection%" %TDbParam% "/cs:%SourceConnection%" /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo;

echo  ^> Checking connection to web service
tadmin CheckService "/a:%Address%" "/u:%Login%" "/p:%Password%" /timeout:%CheckTimeout% /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo  ^> Disabling constraints
tadmin Sql "%Fixes%\ConstraintsOff.%dbms%.sql" %DbParam% "/cs:%TargetConnection%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

call :MigrateToDbms_%dbms%
if "%Fail%"=="1" goto :Fail

echo  ^> Enabling constraints
tadmin Sql "%Fixes%\ConstraintsOn.%dbms%.sql" %DbParam% "/cs:%TargetConnection%" /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

echo;
echo Tessa is migrated. Please, restart application pool and start Chronos.
echo Press any key to close...
pause>nul
cls
goto :Finish

:Fail
set Fail=1
echo;
echo Migration failed with error code: %ErrorLevel%
echo See the details in log file: %Tools%\log.txt
echo;
echo Press any key to close...
pause>nul
cls
goto :Finish

:Finish
endlocal
goto :EOF



:MigrateToDbms_pg

echo  ^> Importing cards for PostgreSQL
tadmin ImportCards "%Configuration%\Cards\PostgreSql" "/a:%Address%" "/u:%Login%" "/p:%Password%" /c /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

goto :EOF



:MigrateToDbms_ms

echo  ^> Importing cards for Microsoft SQL Server
tadmin ImportCards "%Configuration%\Cards\Roles" "/a:%Address%" "/u:%Login%" "/p:%Password%" /c /q /nologo
if not "%ErrorLevel%"=="0" goto :Fail

goto :EOF
