@echo off
REM === Windows �妸�ɡGrobocopy �ƥ��}���]�R�O�C/���ʼҦ����ΡA�t�ϺЪŶ��ˬd�P�޲z���v���ˬd�^ ===

SETLOCAL ENABLEDELAYEDEXPANSION

REM ====================================================
REM 0. �ˬd�O�_�H�t�κ޲z����������A�Y�_�h���զ۰ʴ��v
REM ====================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [���~] ���妸�ɻݭn�H�u�t�κ޲z���v�v������I
    echo.
    echo ���b���զ۰ʥH�t�κ޲z���v�����s�Ұ�...
    setlocal
    set ARGS=%*
    if "%ARGS%"=="" (
        powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    endlocal
    if %errorlevel% neq 0 (
        echo �L�k�۰ʨ��o�t�κ޲z���v���A�ХΥk��u�H�t�κ޲z����������v���ɮסI
        pause
        exit /b
    )
    exit /b
)

REM -------------------------
REM 1. �Ѽ��ˬd�P�Ҧ��P�_�]�t -? �����^
REM -------------------------
SET SRC=
SET DST=
SET USER=

IF /I "%~1"=="-?" GOTO :SHOW_USAGE
IF "%~1"=="" GOTO :INTERACTIVE

REM �R�O�C�ѼƼҦ�
SET SRC=%~1
SET DST=%~2
SET USER=%~3
IF "%DST%"=="" GOTO :SHOW_USAGE
IF "%USER%"=="" GOTO :SHOW_USAGE
GOTO :MAIN

:INTERACTIVE
echo ================================================
echo [���ʼҦ�]�G�Ш̧ǿ�J�ƥ���T
echo ================================================
set /p SRC=�п�J�ӷ��Ϻо����| (�p E:\Users) �G
set /p USER=�п�J�n�ƥ����Τ�W�١]�p your_id�^�G
set /p DST=�п�J�ؼгƥ����|�]�p D:\backup_ssd�^�G

:MAIN
REM �զX����ӷ��P�ؼи��|
SET SRC_USER=%SRC%\%USER%
SET DST_USER=%DST%\%USER%

echo.
echo ================================================
echo ���妸�ɱN�ϥ�robocopy����H�U�ƥ��@�~�G
echo �ӷ��G!SRC_USER!
echo �ؼСG!DST_USER!
echo �ư��t��(S)�P����(H)�ݩ��ɮ�
echo �蹳�P�B�]/MIR�^�A�нT�{�ؼи�Ƨ����e�|�Q�P�B�R��
echo.
echo.
echo ���G�Y�ؼкϺгѾl�Ŷ������ƥ��ӷ��Ϻи�Ƨ��ɱN���_�ƥ��@�~�C
echo ================================================
echo.

set /p confirm=�нT�{�W�z��T�A�O�_�n�~��H(Y/N)�G

if /i not "%confirm%"=="Y" (
    echo �w�����@�~
    pause
    exit /b
)

REM ====================================================
REM 3. �ˬd�ӷ��P�ؼи��|
REM ====================================================
if not exist "!SRC_USER!" (
    echo ���~�G�ӷ���Ƨ� "!SRC_USER!" ���s�b�I
    pause
    exit /b
)
if not exist "!DST!" (
    echo �ؼФW�h��Ƨ� "!DST!" ���s�b�A���b�إ�...
    mkdir "!DST!"
    if errorlevel 1 (
        echo �إߥؼи�Ƨ����ѡI
        pause
        exit /b
    )
)

REM ====================================================
REM 4. �ˬd�ؼкϺЪŶ��O�_����
REM ====================================================
REM ���o�ӷ���Ƨ��j�p�]�H�줸�լ����A�ư�junction�B���B�ؿ��챵�^
echo [�T��] ���b�έp�ӷ���Ƨ��j�p�A�Э@�ߵ��ԡ]�̸�ƶq�i��Ƥ����^...
set SRC_SIZE=
for /f "tokens=3" %%A in (
    'robocopy "!SRC_USER!" . /L /S /NFL /NDL /NJH /BYTES /XD /XF /XJ ^| findstr /C:"�줸�� :"'
) do (
    set SRC_SIZE=%%A
)
if not defined SRC_SIZE (
    echo ���~�G�L�k���o�ӷ���Ƨ��j�p�A�нT�{���|���T�C
    pause
    exit /b
)
REM ���o�ؼкϺо��]�u���Ϻо��r���A�ҦpD:�^
set DST_DRIVE=!DST:~0,2!

REM ���o�ؼкϺгѾl�Ŷ��]�H�줸�լ����^
set DST_FREE=
REM for /f "skip=1 tokens=3" %%B in ('wmic logicaldisk where "DeviceID='!DST_DRIVE!'" get FreeSpace') do (
    if not "%%B"=="" set DST_FREE=%%B
for /f %%B in ('powershell -Command "(Get-PSDrive D).Free"') do set DST_FREE=%%B
    goto :gotspace
)
:gotspace

if not defined DST_FREE (
    echo ���~�G�L�k���o�ؼкϺгѾl�Ŷ��A�нT�{�ϺЦs�b�C
    pause
    exit /b
)

REM �q�X�ӷ���Ƨ��j�p�P�ؼгѾl�Ŷ�
echo �ӷ���Ƨ��j�p�G!SRC_SIZE! Bytes
echo �ؼкϺгѾl�Ŷ��G!DST_FREE! Bytes

REM �Y�Ѿl�Ŷ��p��ӷ��j�p�A�hĵ�i�õ���
setlocal enableextensions
REM �ϥ� setlocal �����ѨM�j�Ʀr������D
if !DST_FREE! lss !SRC_SIZE! (
    echo ���~�G�ؼкϺЪŶ������A�L�k�ƥ��I
    pause
    exit /b
)
endlocal

REM ====================================================
REM 5. ����ƥ�
REM ====================================================
echo �}�l�ƥ�...
robocopy "!SRC_USER!" "!DST_USER!" /MIR /Z /XJ /XA:SH /R:2 /W:2 /LOG+:backup_log.txt

if %errorlevel% GEQ 8 (
    echo robocopy ����ɵo�Ϳ��~�]���~�X�G%errorlevel%�^�A���ˬd backup_log.txt
) else (
    echo �ƥ��@�~�����I
)
pause
exit /b

REM ====================================================
:SHOW_USAGE
echo.
echo �Ϊk�����G
echo.
echo   %~nx0 �ӷ����| �ؼи��| �Τ�W��
echo   %~nx0 ^-?
echo.
echo �d�ҡG
echo   %~nx0 E:\Users D:\backup_ssd your_id
echo.
echo �Τ��[�Ѽƶi�J���ʹ�ܮؼҦ�
echo.
echo �Ѽƻ����G
echo   �ӷ����|   �ӷ���Users��Ƨ����|�A�Ҧp E:\Users
echo   �ؼи��|   �ƥ��ؼи�Ƨ����|�A�Ҧp D:\backup_ssd
echo   �Τ�W��   �n�ƥ����Τ��Ƨ��W�١A�Ҧp your_id
echo   -?         ��ܥ�����
echo.
pause
exit /b