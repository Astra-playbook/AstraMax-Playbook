@echo off
title Astra - Post Install
color 0D
set "HERE=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%PostInstall.ps1" %*
