@echo off
title Formatar Sem Medo - Backup
echo.
echo  Formatar Sem Medo - BACKUP
echo  Este script so copia ficheiros. Nao apaga nada.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup.ps1"
echo.
pause
