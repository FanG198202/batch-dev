@echo off
REM === Windows 批次檔：robocopy 備份腳本（命令列/互動模式雙用，含磁碟空間檢查與管理員權限檢查） ===

SETLOCAL ENABLEDELAYEDEXPANSION

REM ====================================================
REM 0. 檢查是否以系統管理員身份執行，若否則嘗試自動提權
REM ====================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [錯誤] 本批次檔需要以「系統管理員」權限執行！
    echo.
    echo 正在嘗試自動以系統管理員權限重新啟動...
    setlocal
    set ARGS=%*
    if "%ARGS%"=="" (
        powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    endlocal
    if %errorlevel% neq 0 (
        echo 無法自動取得系統管理員權限，請用右鍵「以系統管理員身分執行」本檔案！
        pause
        exit /b
    )
    exit /b
)

REM -------------------------
REM 1. 參數檢查與模式判斷（含 -? 說明）
REM -------------------------
SET SRC=
SET DST=
SET USER=

IF /I "%~1"=="-?" GOTO :SHOW_USAGE
IF "%~1"=="" GOTO :INTERACTIVE

REM 命令列參數模式
SET SRC=%~1
SET DST=%~2
SET USER=%~3
IF "%DST%"=="" GOTO :SHOW_USAGE
IF "%USER%"=="" GOTO :SHOW_USAGE
GOTO :MAIN

:INTERACTIVE
echo ================================================
echo [互動模式]：請依序輸入備份資訊
echo ================================================
set /p SRC=請輸入來源磁碟機路徑 (如 E:\Users) ：
set /p USER=請輸入要備份的用戶名稱（如 your_id）：
set /p DST=請輸入目標備份路徑（如 D:\backup_ssd）：

:MAIN
REM 組合完整來源與目標路徑
SET SRC_USER=%SRC%\%USER%
SET DST_USER=%DST%\%USER%

echo.
echo ================================================
echo 本批次檔將使用robocopy執行以下備份作業：
echo 來源：!SRC_USER!
echo 目標：!DST_USER!
echo 排除系統(S)與隱藏(H)屬性檔案
echo 鏡像同步（/MIR），請確認目標資料夾內容會被同步刪除
echo.
echo.
echo 註：若目標磁碟剩餘空間不足備份來源磁碟資料夾時將中斷備份作業。
echo ================================================
echo.

set /p confirm=請確認上述資訊，是否要繼續？(Y/N)：

if /i not "%confirm%"=="Y" (
    echo 已取消作業
    pause
    exit /b
)

REM ====================================================
REM 3. 檢查來源與目標路徑
REM ====================================================
if not exist "!SRC_USER!" (
    echo 錯誤：來源資料夾 "!SRC_USER!" 不存在！
    pause
    exit /b
)
if not exist "!DST!" (
    echo 目標上層資料夾 "!DST!" 不存在，正在建立...
    mkdir "!DST!"
    if errorlevel 1 (
        echo 建立目標資料夾失敗！
        pause
        exit /b
    )
)

REM ====================================================
REM 4. 檢查目標磁碟空間是否足夠
REM ====================================================
REM 取得來源資料夾大小（以位元組為單位，排除junction、文件、目錄鏈接）
echo [訊息] 正在統計來源資料夾大小，請耐心等候（依資料量可能數分鐘）...
set SRC_SIZE=
for /f "tokens=3" %%A in (
    'robocopy "!SRC_USER!" . /L /S /NFL /NDL /NJH /BYTES /XD /XF /XJ ^| findstr /C:"位元組 :"'
) do (
    set SRC_SIZE=%%A
)
if not defined SRC_SIZE (
    echo 錯誤：無法取得來源資料夾大小，請確認路徑正確。
    pause
    exit /b
)
REM 取得目標磁碟機（只取磁碟機字母，例如D:）
set DST_DRIVE=!DST:~0,2!

REM 取得目標磁碟剩餘空間（以位元組為單位）
set DST_FREE=
REM for /f "skip=1 tokens=3" %%B in ('wmic logicaldisk where "DeviceID='!DST_DRIVE!'" get FreeSpace') do (
    if not "%%B"=="" set DST_FREE=%%B
for /f %%B in ('powershell -Command "(Get-PSDrive D).Free"') do set DST_FREE=%%B
    goto :gotspace
)
:gotspace

if not defined DST_FREE (
    echo 錯誤：無法取得目標磁碟剩餘空間，請確認磁碟存在。
    pause
    exit /b
)

REM 秀出來源資料夾大小與目標剩餘空間
echo 來源資料夾大小：!SRC_SIZE! Bytes
echo 目標磁碟剩餘空間：!DST_FREE! Bytes

REM 若剩餘空間小於來源大小，則警告並結束
setlocal enableextensions
REM 使用 setlocal 延伸解決大數字比較問題
if !DST_FREE! lss !SRC_SIZE! (
    echo 錯誤：目標磁碟空間不足，無法備份！
    pause
    exit /b
)
endlocal

REM ====================================================
REM 5. 執行備份
REM ====================================================
echo 開始備份...
robocopy "!SRC_USER!" "!DST_USER!" /MIR /Z /XJ /XA:SH /R:2 /W:2 /LOG+:backup_log.txt

if %errorlevel% GEQ 8 (
    echo robocopy 執行時發生錯誤（錯誤碼：%errorlevel%），請檢查 backup_log.txt
) else (
    echo 備份作業完成！
)
pause
exit /b

REM ====================================================
:SHOW_USAGE
echo.
echo 用法說明：
echo.
echo   %~nx0 來源路徑 目標路徑 用戶名稱
echo   %~nx0 ^-?
echo.
echo 範例：
echo   %~nx0 E:\Users D:\backup_ssd your_id
echo.
echo 或不加參數進入互動對話框模式
echo.
echo 參數說明：
echo   來源路徑   來源的Users資料夾路徑，例如 E:\Users
echo   目標路徑   備份目標資料夾路徑，例如 D:\backup_ssd
echo   用戶名稱   要備份的用戶資料夾名稱，例如 your_id
echo   -?         顯示本說明
echo.
pause
exit /b