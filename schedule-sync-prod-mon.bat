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
set TABLE_NAME=tbl_joborder

:: Set Laravel app API endpoint
set LARAVEL_APP_ENDPOINT=https://lscph.net/api/jo
@REM set LARAVEL_APP_ENDPOINT=http://127.0.0.1:8000/api/jo

:: Get current date and time
for /f "delims=" %%a in ('wmic OS Get localdatetime ^| find "."') do set "DT=%%a"
set TIMESTAMP=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%_%DT:~8,2%%DT:~10,2%%DT:~12,2%
set DATE_ONLY=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%

:: Set the path for the log file with date and connection status in the current directory
set LOG_FILE=%~dp0\output_%DATE_ONLY%.log


:: Set the path for the JSON file with date and connection status in the current directory
set JSON_FILE=%~dp0\output_%DATE_ONLY%.json


set "filename=max_jobid.txt"
set "content="

REM Read file line by line and append to the content variable
for /f "delims=" %%a in ('type "%filename%"') do (
    set "content=!content!%%a"
)

echo Content of the file:
echo "MAX ID: %content%" >> %LOG_FILE%
:: Set columns for the query
set COLUMN_NAMES=jo.JobOrderNo, jo.Client_ID, jo.Note, jo.Status, jo.DueDate, jo.JobID, cl.ClientName
@REM set COLUMN_NAMES=jo.JobOrderNo, jo.Client_ID, jo.Note, jo.status, jo.duedate, cl.customervendorcode, cl.companyname

REM MySQL query
set SQL_QUERY=SELECT %COLUMN_NAMES% FROM %TABLE_NAME% jo LEFT JOIN tbl_clients cl ON cl.clientid = jo.Client_ID WHERE jo.JobID ^> %content% AND jo.Date ^>= '2024-01-01'; >nul


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
@REM echo %TIMESTAMP% MySQL query: %SQL_QUERY% >> %LOG_FILE%

:: Set path to a temporary file
set TEMP_FILE=temp_output.txt

:: Execute MySQL query and store result in a temporary file
"%MYSQL_PATH%\mysql.exe" -h !DB_HOST! -u !DB_USER! -p!DB_PASSWORD! -D !DB_DATABASE! -e "!SQL_QUERY!" --batch --raw --skip-column-names > %TEMP_FILE%

:: Log the contents of the temporary file
echo %TIMESTAMP% Temporary file content: >> %LOG_FILE%
type %TEMP_FILE% >> %LOG_FILE%

:: Read the contents of the temporary file into a variable
set /p RESULT=<%TEMP_FILE%

REM Check if the RESULT variable is not null
if not "!RESULT!"=="" (
    @REM echo Result is not null: !RESULT!
    :: Convert the contents into a multilevel array using PowerShell
    powershell -command "& {$content = Get-Content \"%TEMP_FILE%\"; $resultArray = @(); foreach ($line in $content) {$resultArray += @($line -split '\t')}; Invoke-RestMethod -Uri \"%LARAVEL_APP_ENDPOINT%\" -Method Post -Headers @{ 'X-XSRF-TOKEN' = \"%CSRF_TOKEN%\" } -Body ($resultArray | ConvertTo-Json) -ContentType 'application/json';}"

) else (
    echo %TEMP_FILE% Result is null. >> %LOG_FILE%
)

@REM :: Delete the temporary file
del %TEMP_FILE%

:: Query to get the max JobID
set MAX_JOBID_QUERY=SELECT MAX(JobID) FROM %TABLE_NAME% where JobID ^>= !content! >nul
set MAX_JOBID_FILE=max_jobid.txt

:: Execute query and save result to a text file
"%MYSQL_PATH%\mysql.exe" -h !DB_HOST! -u !DB_USER! -p!DB_PASSWORD! -D !DB_DATABASE! -e "!MAX_JOBID_QUERY!" --batch --raw --skip-column-names > %MAX_JOBID_FILE%

:: Read the contents of the text file into a variable
set /p MAX_JOBID=<%MAX_JOBID_FILE%


:: Output the max JobID to the log file
echo %TIMESTAMP% Max JobID: %MAX_JOBID% >> %LOG_FILE%

:END
echo %TIMESTAMP% Script execution completed.  >> %LOG_FILE%
echo --------------------------------------------------->> %LOG_FILE%
@REM pause
