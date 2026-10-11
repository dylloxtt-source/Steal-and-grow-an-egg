@echo off
chcp 65001 >nul
cd /d "%~dp0"

set ROJO=rojo.exe
if exist "rojo.exe" goto run
where rojo >nul 2>nul
if errorlevel 1 goto missing
set ROJO=rojo
goto run

:missing
echo Не найден rojo.exe.
echo Скачай rojo-...-windows-x86_64.zip с https://github.com/rojo-rbx/rojo/releases
echo и положи rojo.exe в эту папку, рядом с этим файлом.
pause
exit /b 1

:run
echo Rojo запущен. Не закрывай это окно, пока работаешь в Studio.
echo В Studio: Plugins - Rojo - Connect
echo.
%ROJO% serve default.project.json
pause
