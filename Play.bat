@echo off
rem Launches Scuffed Street without the editor. Set GODOT to your Godot exe
rem folder if it is not the one below. Extra arguments are passed to the game,
rem e.g.  Play.bat --watch   (an all-CPU game).
setlocal
if "%GODOT%"=="" set "GODOT=D:\Downloads\Godot_v4.7.2-stable_win64.exe"
set "GODOT_EXE=%GODOT%\Godot_v4.7.2-stable_win64.exe"
set "GODOT_CONSOLE=%GODOT%\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_EXE%" (
  echo Godot not found at "%GODOT_EXE%". Set GODOT to the folder holding it.
  pause
  exit /b 1
)
cd /d "%~dp0"
rem Refresh the import cache so new or renamed scripts are picked up.
"%GODOT_CONSOLE%" --headless --path . --import >nul 2>&1
if "%~1"=="" (
  start "" "%GODOT_EXE%" --path .
) else (
  start "" "%GODOT_EXE%" --path . -- %*
)
