@echo off
setlocal enabledelayedexpansion

:: Set the path to MySQL command-line tools in the current directory
set MYSQL_PATH=%~dp0

:: Set MySQL connection parameters
set DB_HOST=localhost
set DB_PORT=3306
set DB_USER=local
set DB_PASSWORD=P@$$W0rd
set DB_DATABASE=lightstar
set TABLE_NAME=tb_joborder

:: Set Laravel app API endpoint
set LARAVEL_APP_ENDPOINT=http://127.0.0.1:8000/api/jo

:: Set columns for the query
set COLUMN_NAMES=jo.JobOrderNo, jo.Client_ID, jo.Note, jo.status, jo.duedate, cl.customervendorcode, cl.companyname
@REM set COLUMN_NAMES=jo.JobOrderNo, jo.Client_ID, jo.Note, jo.status, jo.duedate, cl.customervendorcode, cl.companyname

REM MySQL query
set SQL_QUERY=SELECT %COLUMN_NAMES% FROM %TABLE_NAME% jo LEFT JOIN tb_clients cl ON cl.clientid = jo.Client_ID;

:: Get current date and time
for /f "delims=" %%a in ('wmic OS Get localdatetime ^| find "."') do set "DT=%%a"
set TIMESTAMP=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%_%DT:~8,2%%DT:~10,2%%DT:~12,2%
set DATE_ONLY=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%

:: Set the path for the log file with date and connection status in the current directory
set LOG_FILE=%~dp0\output_%DATE_ONLY%.log

:: Set the path for the JSON file with date and connection status in the current directory
set JSON_FILE=%~dp0\output_%DATE_ONLY%.json

:: Debug: Output MySQL command to log
echo %TIMESTAMP% MySQL command: %MYSQL_PATH%mysql.exe -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASSWORD% -D%DB_DATABASE%  -e "%SQL_QUERY%" >> %LOG_FILE%

:: Check MySQL connection
%MYSQL_PATH%mysql.exe -h %DB_HOST% -P %DB_PORT% -u %DB_USER% -p%DB_PASSWORD% -e "exit" > nul 2>&1
if %errorlevel% neq 0 (
    echo %TIMESTAMP% MySQL connection failed >> %LOG_FILE%
    goto :END
) else (
    echo %TIMESTAMP% MySQL connection successful >> %LOG_FILE%
)

@echo off

:: Debug: Output MySQL query to log
echo %TIMESTAMP% MySQL query: %SQL_QUERY% >> %LOG_FILE%

:: Set path to a temporary file
set TEMP_FILE=temp_output.txt

:: Execute MySQL query and store result in a temporary file
"%MYSQL_PATH%\mysql.exe" -h !DB_HOST! -u !DB_USER! -p!DB_PASSWORD! -D !DB_DATABASE! -e "!SQL_QUERY!" --batch --raw --skip-column-names > %TEMP_FILE%

:: Log the contents of the temporary file
echo %TIMESTAMP% Temporary file content: >> %LOG_FILE%
type %TEMP_FILE% >> %LOG_FILE%

:: Read the contents of the temporary file into a variable
set /p RESULT=<%TEMP_FILE%
:: Convert the contents into a multilevel array using PowerShell
powershell -command "& {$content = Get-Content \"%TEMP_FILE%\"; $resultArray = @(); foreach ($line in $content) {$resultArray += @($line -split '\t')}; Invoke-RestMethod -Uri \"%LARAVEL_APP_ENDPOINT%\" -Method Post -Headers @{ 'X-XSRF-TOKEN' = \"%CSRF_TOKEN%\" } -Body ($resultArray | ConvertTo-Json) -ContentType 'application/json';}"
@REM powershell -command "& {$content = Get-Content \"%TEMP_FILE%\"; $resultArray = @(); foreach ($line in $content) {$resultArray += @(@($line -split '\t'))}; $resultArray | ConvertTo-Json -Depth 1}"

@REM :: Delete the temporary file
@REM del %TEMP_FILE%


@REM :: Execute MySQL query and store result in a variable using PowerShell
@REM @REM for /f "tokens=* delims=" %%a in ('powershell -command "& {%MYSQL_PATH%mysql.exe  -h %DB_HOST% -u %DB_USER% -p %DB_PASSWORD% -D %DB_DATABASE% -e "%SQL_QUERY%"  --skip-column-names -e \"%SQL_QUERY%\"}"') do set RESULT=%%a
@REM for /f "tokens=* delims=" %%a in ('powershell -command "& {%MYSQL_PATH%\mysql.exe -h !DB_HOST! -u !DB_USER! -p!DB_PASSWORD! -D !DB_DATABASE! -e \"!SQL_QUERY!\" --skip-column-names"}') do set RESULT=%%a

@REM REM Send result to Laravel app using PowerShell with CSRF token
@REM powershell -command "& {& Invoke-RestMethod -Uri \"%LARAVEL_APP_ENDPOINT%\" -Method Post -Headers @{ 'X-XSRF-TOKEN' = \"%CSRF_TOKEN%\" } -Body (@{ data = \"%RESULT%\" } | ConvertTo-Json) -ContentType 'application/json'}"
@REM :: Debug: Output MySQL query result to log
@REM echo %TIMESTAMP% MySQL query result: %RESULT% >> %LOG_FILE%

:END
echo %TIMESTAMP% Script execution completed.
pause
