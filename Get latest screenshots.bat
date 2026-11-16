@echo off
rem Double-click: downloads the latest app screenshots from the cloud tests and opens the folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\latest-screenshots.ps1"
if errorlevel 1 pause
