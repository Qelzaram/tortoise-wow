@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Turtle WoW Spirit Tap TRACE - installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp000_prepare_trace_server.ps1"
if errorlevel 1 (
  echo.
  echo TRACE setup failed. Nothing should have modified the primary DB volume.
)
pause
