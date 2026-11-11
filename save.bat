@echo off
rem Save your work to GitHub: commits anything changed (asks for a short note), then pushes.
rem Commits Claude already made are pushed too.
setlocal
cd /d "%~dp0"

where git >nul 2>nul
if errorlevel 1 goto nogit

git add -A
git diff --cached --quiet && goto push
set /p MSG="Describe what changed: "
if "%MSG%"=="" set MSG=Work in progress
git commit -m "%MSG%"

:push
echo.
echo Pushing to GitHub...
git push -u origin main
echo.
git log --oneline -5
pause
exit /b 0

:nogit
echo The git command isn't installed. Install "Git for Windows" from https://git-scm.com
echo (or use GitHub Desktop: open this repository and click "Push origin").
pause
exit /b 1
