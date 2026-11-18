@echo off
rem Build on Windows.  Usage: build.bat [test|run]
cd /d "%~dp0"
if not exist bin mkdir bin
if "%1"=="test" (
  odin test src -out:bin\galaxies_test.exe -define:ODIN_TEST_THREADS=1
  goto :eof
)
odin build src -out:bin\galaxies.exe -o:speed || exit /b 1
if "%1"=="run" bin\galaxies.exe
