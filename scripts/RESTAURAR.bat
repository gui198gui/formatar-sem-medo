@echo off
title Formatar Sem Medo - Restauro
echo.
echo  Formatar Sem Medo - RESTAURO
echo  Corre isto DEPOIS de formatar, a partir da pen/disco com o backup.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restaurar.ps1"
echo.
pause
