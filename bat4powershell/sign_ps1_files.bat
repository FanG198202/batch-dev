@echo off
setlocal enabledelayedexpansion

REM === 說明區 ===
echo.
echo [PowerShell 自簽代碼簽署批次作業]
echo -----------------------------------------------------------
echo 1. 產生自簽代碼簽署憑證（如未存在）。
echo 2. 將該憑證匯入「本機信任的根憑證授權單位」(LocalMachine\Root)。
echo 3. 將該憑證匯入「本機受信任的發行者」(LocalMachine\TrustedPublisher)。
echo 4. 以該憑證簽署指定資料夾下所有 PS1 檔案。
echo 5. 檢查每個 PS1 檔案的簽章狀態。
echo -----------------------------------------------------------
echo 本作業需要系統管理員權限，請確認已以[系統管理員]身份執行。
echo.
set /p usercho=是否要繼續執行？(Y/N)：
if /i not "!usercho!"=="Y" (
    echo 已取消執行。
    pause
    exit /b
)

REM === 權限檢查與自我提升 ===
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [!] 本作業必須以系統管理員身份執行，正在嘗試自我提升...
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit /b
)

REM === 處理 PS1 目錄路徑參數 ===
if "%~1"=="" (
    set "PS_DIR=%cd%"
) else (
    set "PS_DIR=%~1"
)

REM === 檢查目錄是否存在 ===
if not exist "%PS_DIR%\" (
    echo [!] 指定的資料夾不存在：%PS_DIR%
    pause
    exit /b
)

REM === 檢查是否有 ps1 檔案 ===
dir /b /a-d "%PS_DIR%\*.ps1" >nul 2>&1
if errorlevel 1 (
    echo [!] 目錄 "%PS_DIR%" 中找不到任何 .ps1 檔案，批次作業結束。
    echo.
    echo 用法說明：
    echo    %~nx0  [ps1檔案目錄路徑]
    echo.
    echo 若未指定路徑，預設處理目前目錄下的 .ps1 檔案。
    pause
    exit /b
)

REM 1. 建立自簽代碼簽署憑證（如尚未存在）
echo [1/5] 建立自簽代碼簽署憑證（本機）...
powershell -NoProfile -Command "if (-not (Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' })) { New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=MyCodeSigning' -CertStoreLocation 'Cert:\LocalMachine\My' }"

REM 2. 將憑證加入本機信任根憑證存放區（LocalMachine\Root）
echo [2/5] 匯入憑證到本機信任的根憑證存放區...
powershell -NoProfile -Command "$cert = Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' }; if (-not (Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Thumbprint -eq $cert.Thumbprint })) { $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root','LocalMachine'); $store.Open('ReadWrite'); $store.Add($cert); $store.Close(); Write-Host '已匯入信任根憑證。' } else { Write-Host '憑證已存在於信任根憑證存放區。' }"

REM 3. 將憑證加入本機受信任的發行者（LocalMachine\TrustedPublisher）
echo [3/5] 匯入憑證到本機受信任的發行者存放區...
powershell -NoProfile -Command "$cert = Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' }; if (-not (Get-ChildItem -Path Cert:\LocalMachine\TrustedPublisher | Where-Object { $_.Thumbprint -eq $cert.Thumbprint })) { $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('TrustedPublisher','LocalMachine'); $store.Open('ReadWrite'); $store.Add($cert); $store.Close(); Write-Host '已匯入受信任的發行者。' } else { Write-Host '憑證已存在於受信任的發行者存放區。' }"

REM 4. 用憑證簽署所有 ps1 檔案
echo [4/5] 使用憑證簽署 %PS_DIR% 目錄下的所有 ps1 檔案...
for %%F in ("%PS_DIR%\*.ps1") do (
    echo  正在簽署: %%F
    powershell -NoProfile -Command "$cert = Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' }; Set-AuthenticodeSignature -FilePath '%%F' -Certificate $cert | Out-Null"
)

REM 5. 檢查簽章狀態
echo [5/5] 檢查簽章狀態:
for %%F in ("%PS_DIR%\*.ps1") do (
    echo  %%F 的簽章狀態:
    powershell -NoProfile -Command "Get-AuthenticodeSignature '%%F' | Format-List Status,StatusMessage,SignerCertificate"
    echo -----------------------------------------------
)

pause