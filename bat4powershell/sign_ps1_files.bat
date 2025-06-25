@echo off
setlocal enabledelayedexpansion

REM === ������ ===
echo.
echo [PowerShell ��ñ�N�Xñ�p�妸�@�~]
echo -----------------------------------------------------------
echo 1. ���ͦ�ñ�N�Xñ�p���ҡ]�p���s�b�^�C
echo 2. �N�Ӿ��ҶפJ�u�����H�����ھ��ұ��v���v(LocalMachine\Root)�C
echo 3. �N�Ӿ��ҶפJ�u�������H�����o��̡v(LocalMachine\TrustedPublisher)�C
echo 4. �H�Ӿ���ñ�p���w��Ƨ��U�Ҧ� PS1 �ɮסC
echo 5. �ˬd�C�� PS1 �ɮת�ñ�����A�C
echo -----------------------------------------------------------
echo ���@�~�ݭn�t�κ޲z���v���A�нT�{�w�H[�t�κ޲z��]��������C
echo.
set /p usercho=�O�_�n�~�����H(Y/N)�G
if /i not "!usercho!"=="Y" (
    echo �w��������C
    pause
    exit /b
)

REM === �v���ˬd�P�ۧڴ��� ===
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [!] ���@�~�����H�t�κ޲z����������A���b���զۧڴ���...
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit /b
)

REM === �B�z PS1 �ؿ����|�Ѽ� ===
if "%~1"=="" (
    set "PS_DIR=%cd%"
) else (
    set "PS_DIR=%~1"
)

REM === �ˬd�ؿ��O�_�s�b ===
if not exist "%PS_DIR%\" (
    echo [!] ���w����Ƨ����s�b�G%PS_DIR%
    pause
    exit /b
)

REM === �ˬd�O�_�� ps1 �ɮ� ===
dir /b /a-d "%PS_DIR%\*.ps1" >nul 2>&1
if errorlevel 1 (
    echo [!] �ؿ� "%PS_DIR%" ���䤣����� .ps1 �ɮסA�妸�@�~�����C
    echo.
    echo �Ϊk�����G
    echo    %~nx0  [ps1�ɮץؿ����|]
    echo.
    echo �Y�����w���|�A�w�]�B�z�ثe�ؿ��U�� .ps1 �ɮסC
    pause
    exit /b
)

REM 1. �إߦ�ñ�N�Xñ�p���ҡ]�p�|���s�b�^
echo [1/5] �إߦ�ñ�N�Xñ�p���ҡ]�����^...
powershell -NoProfile -Command "if (-not (Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' })) { New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=MyCodeSigning' -CertStoreLocation 'Cert:\LocalMachine\My' }"

REM 2. �N���ҥ[�J�����H���ھ��Ҧs��ϡ]LocalMachine\Root�^
echo [2/5] �פJ���Ҩ쥻���H�����ھ��Ҧs���...
powershell -NoProfile -Command "$cert = Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' }; if (-not (Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Thumbprint -eq $cert.Thumbprint })) { $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root','LocalMachine'); $store.Open('ReadWrite'); $store.Add($cert); $store.Close(); Write-Host '�w�פJ�H���ھ��ҡC' } else { Write-Host '���Ҥw�s�b��H���ھ��Ҧs��ϡC' }"

REM 3. �N���ҥ[�J�������H�����o��̡]LocalMachine\TrustedPublisher�^
echo [3/5] �פJ���Ҩ쥻�����H�����o��̦s���...
powershell -NoProfile -Command "$cert = Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' }; if (-not (Get-ChildItem -Path Cert:\LocalMachine\TrustedPublisher | Where-Object { $_.Thumbprint -eq $cert.Thumbprint })) { $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('TrustedPublisher','LocalMachine'); $store.Open('ReadWrite'); $store.Add($cert); $store.Close(); Write-Host '�w�פJ���H�����o��̡C' } else { Write-Host '���Ҥw�s�b����H�����o��̦s��ϡC' }"

REM 4. �ξ���ñ�p�Ҧ� ps1 �ɮ�
echo [4/5] �ϥξ���ñ�p %PS_DIR% �ؿ��U���Ҧ� ps1 �ɮ�...
for %%F in ("%PS_DIR%\*.ps1") do (
    echo  ���bñ�p: %%F
    powershell -NoProfile -Command "$cert = Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' }; Set-AuthenticodeSignature -FilePath '%%F' -Certificate $cert | Out-Null"
)

REM 5. �ˬdñ�����A
echo [5/5] �ˬdñ�����A:
for %%F in ("%PS_DIR%\*.ps1") do (
    echo  %%F ��ñ�����A:
    powershell -NoProfile -Command "Get-AuthenticodeSignature '%%F' | Format-List Status,StatusMessage,SignerCertificate"
    echo -----------------------------------------------
)

pause