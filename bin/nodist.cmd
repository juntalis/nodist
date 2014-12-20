@echo off
rem localize our runtime environment
rem FIXME: Is there any reason that NODIST_PREFIX needs to be a persistent
rem        environment variable?
setlocal
rem just in case
setlocal ENABLEEXTENSIONS

rem the following allows us to detect when this script gets run by itself (or
rem run by one of the programs that this script run)
if not defined NODIST_FORK_LEVEL (
	set /A NODIST_FORK_LEVEL=1
) else (
	set /A NODIST_FORK_LEVEL=%NODIST_FORK_LEVEL% + 1
)

rem when such a run is detected, go straight to executing cli.js
if %NODIST_FORK_LEVEL% GTR 1 goto forked

rem if the environment is not currently configured for nodist, do so now.
if not defined NODIST_PREFIX goto setprefix

rem otherwise, continue on to our opts parser.
goto getopts

:dirname
rem Get the dirname of the second argument and set the variable who's
rem name was specified in the first argument.
call set %~1=%%~dp2
call set %~1=%%%~1:~0,-1%%
GOTO :EOF

:setprefix
rem Since dp0 leaves a trailing '\', remove it priot to calling dirname
set NODIST_PREFIX=%~dp0
set NODIST_PREFIX=%NODIST_PREFIX:~0,-1%
call :dirname NODIST_PREFIX "%NODIST_PREFIX%"
goto getopts

:getopts
rem hook `nodist use <version>`
if /i "%~1"=="use" goto env
if /i "%~1"=="env" goto env

rem hook `nodist update`
if /i "%~1"=="update" goto selfupdate
if /i "%~1"=="selfupdate" goto selfupdate

rem if no hooked commands are detected, execute the nodist js script
goto main

:env
call "%~f0" + %~2
rem FIXME: for some reason, we run add against if the first time succeeded.

rem The following passes for any non-zero exit codes
if ERRORLEVEL 1 goto error

rem get version and set NODIST_VERSION
FOR /F "tokens=1 delims=" %%A in ('"%~f0" add "%~2"') do @set "NODIST_VERSION=%%~A"

rem we can check the exit code of the second run at :end
goto end

:npmrc
rem check the user's .npmrc prior to configuring npm
rem in order to veirfy that we'll be able to make changes.

rem if npmrc does not currently exist, we're should be fine.
if not exist "%~f1" goto :EOF

rem localize the following code to avoid polluting the environment
setlocal

rem Determine what file attributes should be cleared out.
set NPMRC_PATH=%~f1
set NPMRC_ATTRS=%~a1
rem attributes: -rahs----
set NPMRC_RONLY=%NPMRC_ATTRS:~1,1%
set NPMRC_HIDDEN=%NPMRC_ATTRS:~3,1%
set NPMRC_SYSTEM=%NPMRC_ATTRS:~4,1%

rem Build our attrib call
set NPMRC_ATTRIB_CALL=
if not "%NPMRC_RONLY%"=="-" set NPMRC_ATTRIB_CALL=%NPMRC_ATTRIB_CALL% -R
if not "%NPMRC_HIDDEN%"=="-" set NPMRC_ATTRIB_CALL=%NPMRC_ATTRIB_CALL% -H
if not "%NPMRC_SYSTEM%"=="-" set NPMRC_ATTRIB_CALL=%NPMRC_ATTRIB_CALL% -S

rem Check if we need to make changes
if "%NPMRC_ATTRIB_CALL%x"=="x" goto npmrc_ready

rem No matter what, we'll always have an extra space at the start.
set NPMRC_ATTRIB_CALL=%NPMRC_ATTRIB_CALL:~1%
call attrib %NPMRC_ATTRIB_CALL% "%NPMRC_PATH%"
if errorlevel 1 goto npmrc_error

:npmrc_ready
rem configure our local npm instance accordingly
rem FIXME: We did want to run the local copy of npm, right?
call "%~dp0npm.cmd" config set prefix "%NODIST_PREFIX%\bin"
if errorlevel 1 goto npmrc_error
if "%NPMRC_ATTRIB_CALL%x"=="x" goto npmrc_success

rem Reset any previously cleared attrs on .npmrc.
set NPMRC_ATTRIB_CALL=%NPMRC_ATTRIB_CALL:-=+%
call attrib %NPMRC_ATTRIB_CALL% "%NPMRC_PATH%"
if errorlevel 1 goto npmrc_error

:npmrc_success
rem step back into the script's environment
endlocal
goto :EOF

:npmrc_error
echo ERROR: Failed to acquire access to user's .npmrc
endlocal & exit /B %ERRORLEVEL%

:selfupdate
rem run cli.js to install the stable version.
echo Installing latest stable version...
call "%~f0" stable

rem if we encounter an error during update, bail
if errorlevel 1 goto error

rem Verify our access to .npmrc and configure our prefix.
call :npmrc "%USERPROFILE%\.npmrc"
if errorlevel 1 goto error

rem we shouldn't need to cd to the nodist prefix to run npm..
echo Update dependencies...

rem FIXME: CD /D should be redundant since pushd/popd handle drive changes.
rem store our working directory, then change to our NODIST_PREFIX in order
rem to update npm.
pushd "%NODIST_PREFIX%"

rem Update npm
call "%~dp0npm.cmd" update

rem we still need to return to our previous folder, so we'll handle any error 
rem codes in :end
popd

rem handle any errors and cleanup still necessary.
goto end

:main
:forked
rem  run cli.js, then continue down into an error check and success handling.
if /i "%PROCESSOR_ARCHITECTURE%x"=="AMD64x" set NODIST_X64=1
call "%NODIST_PREFIX%\node.exe" "%NODIST_PREFIX%\cli.js" %*

:end
rem Handle any errors that came up at the end.
if ERRORLEVEL 1 goto error

rem The line below is important. Without it, we wont maintain our NODIST_VERSION
rem after this cmd script ends.
endlocal & set NODIST_VERSION=%NODIST_VERSION%
goto :EOF

:error
rem The following lets us print text to the console with no ending newline
rem FIXME: Bell? No Bell?
<nul set /p ECHON=

rem Exit with the failing process's exit code.
exit /B %ERRORLEVEL%
