@echo off
cd bin/bin
if "%1"=="debug" (
  :: run debug
  NTTassemble-Debug.exe
) else (
  :: run release
  NTT-Assemble.exe
)
::pause
