@echo off
setlocal enabledelayedexpansion

REM Windows Lab 1 experiment runner for CPE 333 PS12.
REM Runs non-elevated via cmd /c. Captures expected privilege errors for mklink
REM symlinks as real results. Always removes subst D: and %TEMP%\ps12 on exit.

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PS12_DIR=%%~fI"
if not exist "%PS12_DIR%\results" mkdir "%PS12_DIR%\results"
set "OUT=%PS12_DIR%\results\1_links_windows.txt"

set "WORK=%TEMP%\ps12"
if exist "%WORK%" (
    if exist "%WORK%\dirtest\parent\child\loop" rmdir "%WORK%\dirtest\parent\child\loop" >nul 2>&1
    if exist "%WORK%\dirtest\dir_junc" rmdir "%WORK%\dirtest\dir_junc" >nul 2>&1
    rmdir /s /q "%WORK%" >nul 2>&1
)
mkdir "%WORK%"

REM Ensure D: is not already subst'd by a previous aborted run
subst D: /d >nul 2>&1

call :run_all > "%OUT%" 2>&1
set "RC=%ERRORLEVEL%"

REM Guaranteed cleanup even on failure
if exist "D:\junc_to_c" rmdir "D:\junc_to_c" >nul 2>&1
subst D: /d >nul 2>&1
if exist "%WORK%\dirtest\parent\child\loop" rmdir "%WORK%\dirtest\parent\child\loop" >nul 2>&1
if exist "%WORK%\dirtest\dir_junc" rmdir "%WORK%\dirtest\dir_junc" >nul 2>&1
if exist "%WORK%" rmdir /s /q "%WORK%" >nul 2>&1

if not "%RC%"=="0" (
    echo run_windows.cmd finished with errorlevel %RC% 1>&2
    exit /b %RC%
)
echo Captured Windows Lab 1 transcript to %OUT%
exit /b 0

:run_all
pushd "%WORK%"

echo --- win_item1_2: hard and symbolic links, deleting source ---
echo C:\^> echo hello windows lab 12 ^> source.txt
echo hello windows lab 12 > source.txt
echo C:\^> mklink sym_link.txt source.txt
mklink sym_link.txt source.txt
echo C:\^> mklink /H hard_link.txt source.txt
mklink /H hard_link.txt source.txt
echo C:\^> dir /a-d /b source.txt hard_link.txt
dir /a-d /b source.txt hard_link.txt
echo C:\^> del source.txt
del source.txt
echo C:\^> dir /a-d /b source.txt hard_link.txt
dir /a-d /b source.txt hard_link.txt
echo C:\^> type hard_link.txt
type hard_link.txt
echo.

echo --- win_item3: level 1 and level 2 hard link chain ---
mkdir "%WORK%\lvl"
pushd "%WORK%\lvl"
echo C:\^> echo win chain data ^> src3.txt
echo win chain data > src3.txt
echo C:\^> mklink /H l1_hard.txt src3.txt
mklink /H l1_hard.txt src3.txt
echo C:\^> mklink /H l2_hard.txt l1_hard.txt
mklink /H l2_hard.txt l1_hard.txt
echo C:\^> del src3.txt
del src3.txt
echo C:\^> type l1_hard.txt
type l1_hard.txt
echo C:\^> type l2_hard.txt
type l2_hard.txt
echo C:\^> del l1_hard.txt
del l1_hard.txt
echo C:\^> type l2_hard.txt
type l2_hard.txt
popd
echo.

echo --- win_item4: directory links, junction loop, and dir /s ---
mkdir "%WORK%\dirtest\parent\child"
pushd "%WORK%\dirtest"
echo parent file > parent\p.txt
echo child file > parent\child\c.txt
echo C:\^> mklink /D dir_sym parent
mklink /D dir_sym parent
echo C:\^> mklink /H dir_hard parent
mklink /H dir_hard parent
echo C:\^> mklink /J dir_junc parent
mklink /J dir_junc parent
echo C:\^> dir /b dir_junc
dir /b dir_junc
echo C:\^> mklink /J parent\child\loop parent
mklink /J parent\child\loop parent
echo C:\^> dir /s parent   (only the "Directory of" lines shown)
dir /s parent > "%WORK%\dir_s.tmp" 2>&1
for /f %%N in ('type "%WORK%\dir_s.tmp" ^| %SystemRoot%\System32\find.exe /c /v ""') do set "TOTAL_LINES=%%N"
for /f %%N in ('%SystemRoot%\System32\find.exe /c "Directory of" ^< "%WORK%\dir_s.tmp"') do set "TOTAL_DIRS=%%N"
set "COUNT=0"
for /f "usebackq delims=" %%L in (`%SystemRoot%\System32\findstr.exe /c:"Directory of" "%WORK%\dir_s.tmp"`) do (
    set /a COUNT+=1
    if !COUNT! leq 5 echo %%L
)
echo ... [!TOTAL_DIRS! directories listed; total lines produced by dir /s parent: !TOTAL_LINES!] ...
set "NONEMPTY=0"
for /f "usebackq delims=" %%L in ("%WORK%\dir_s.tmp") do set /a NONEMPTY+=1
set /a TAIL_START=!NONEMPTY!-2
set "COUNT=0"
for /f "usebackq delims=" %%L in ("%WORK%\dir_s.tmp") do (
    set /a COUNT+=1
    if !COUNT! geq !TAIL_START! echo %%L
)
rmdir parent\child\loop
rmdir dir_junc
popd
echo.

echo --- win_item5: drive D: (subst) to drive C: ---
mkdir "%WORK%\driveD"
mkdir "%WORK%\c_dir"
echo c-drive source > "%WORK%\c_src.txt"
echo inside c_dir > "%WORK%\c_dir\inside.txt"
echo C:\^> subst D: "%WORK%\driveD"
subst D: "%WORK%\driveD"
echo C:\^> subst
subst
echo C:\^> mklink D:\sym_to_c.txt "%WORK%\c_src.txt"
mklink D:\sym_to_c.txt "%WORK%\c_src.txt"
echo C:\^> mklink /H D:\hard_to_c.txt "%WORK%\c_src.txt"
mklink /H D:\hard_to_c.txt "%WORK%\c_src.txt"
echo C:\^> type D:\hard_to_c.txt
type D:\hard_to_c.txt
echo C:\^> mklink /J D:\junc_to_c "%WORK%\c_dir"
mklink /J D:\junc_to_c "%WORK%\c_dir"
echo C:\^> dir /b D:\junc_to_c
dir /b D:\junc_to_c
rmdir D:\junc_to_c
echo C:\^> subst D: /d
subst D: /d

popd
exit /b 0
