@echo off
rem Build on Windows.  Usage: build.bat [test|run]
cd /d "%~dp0"
if not exist bin mkdir bin
if "%1"=="test" (
  odin test src -out:bin\elite_test.exe -define:ODIN_TEST_THREADS=1
  goto :eof
)
odin build src -out:bin\elite.exe -o:speed || exit /b 1
if "%1"=="run" bin\elite.exe
