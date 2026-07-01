@echo off
REM wddebug launcher for Windows.
REM
REM Prerequisite: build the assembled output once from the repo root:
REM   mvn -pl toolbox/debug -am package
setlocal enabledelayedexpansion

set "DIR=%~dp0"
pushd "%DIR%..\.." >nul
set "ROOT=%CD%"
popd >nul
set "REPO=%ROOT%\repo"

if not exist "%REPO%" (
  echo Build output missing ^(%REPO%^).
  echo From the repo root run: mvn -pl toolbox/debug -am package
  exit /b 1
)

set "CP="
for /r "%REPO%" %%J in (*.jar) do set "CP=!CP!;%%J"
java --enable-native-access=ALL-UNNAMED -cp "!CP!" com.widedot.toolbox.debug.MainCommand %*

endlocal
