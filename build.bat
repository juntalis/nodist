@echo off
if exist "%~dp0bin\node.exe" (
	echo Removing existing executable file..
	call del /F /Q "%~dp0bin\node.exe">nul 2>nul
	if errorlevel 1 (
		echo Error occurred deleting file: "%~dp0bin\node.exe"!
		exit /B %ERRORLEVEL%
	)
)

echo Starting build..
call go.exe build -o "%~dp0bin\node.exe" "%~dp0src\shim.go"
if errorlevel 1 goto build_failed
if not exist "%~dp0bin\node.exe" goto build_failed
echo Build successful..

:build_success
echo Getting harder to deal with..
goto :EOF


:build_failed
echo Build failed..
exit /B %ERRORLEVEL%
