<#
.SYNOPSIS
   備份舊系統滑鼠右鍵Context Menu Registry鍵值
.DESCRIPTION
   此腳本會從指定的舊系統路徑讀取Context Menu Registry鍵值，備份到指定的備份資料夾路徑。
.NOTES
   必須以管理員權限執行
   檔案名稱: BackupOldWinContextMenuRegistry_v0.3.ps1
   作者: 
   版本: 0.3
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Show-Help {
    Write-Host @"
程序名稱:
    BackupOldWinContextMenuRegistry_v0.3.ps1

程序用途:
    從指定來源Windows安裝路徑備份舊系統滑鼠右鍵Context Menu相關Registry鍵值，匯出為CSV。

命令列結構:
    powershell -ExecutionPolicy Bypass -File .\BackupOldWinContextMenuRegistry_v0.3.ps1 [-h] [-Source <來源SOFTWARE檔路徑>] [-Target <備份輸出資料夾路徑>]

命令列參數說明:
    -h             顯示此說明訊息
    -Source        舊系統SOFTWARE registry hive檔案完整路徑 (例: E:\Windows\System32\Config\SOFTWARE)
    -Target        備份檔案儲存目標資料夾 (例: D:\Backup\)
"@
}

function Test-Admin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-DigitalSignature {
    param([string]$ScriptPath)
    $signature = Get-AuthenticodeSignature $ScriptPath
    return $signature.Status -eq 'Valid'
}

function Ensure-SelfSignedCert {
    param([string]$ScriptPath)
    # 嘗試取得現有自簽憑證
    $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*BackupOldWinContextMenuRegistry*" }
    if (-not $cert) {
        # 無自簽憑證則建立
        $cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My -Subject "CN=BackupOldWinContextMenuRegistry Script Signing" -KeyUsage DigitalSignature -NotAfter (Get-Date).AddYears(5)
    }
    # 為腳本檔案簽名
    try {
        Set-AuthenticodeSignature -FilePath $ScriptPath -Certificate $cert | Out-Null
        Write-Host "已為腳本加入自簽憑證，將自動重新啟動..."
        Start-Sleep -Seconds 2
        # 重新啟動腳本
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Verb runas
        exit
    } catch {
        Write-Error "自動簽署腳本失敗: $($_.Exception.Message)"
        exit 1
    }
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )
    Add-Type -AssemblyName Microsoft.VisualBasic
    $result = [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, "參數輸入", $Default)
    return $result
}

function Backup-ContextMenuRegistry {
    param(
        [string]$HivePath,
        [string]$TargetFolder,
        [string]$HiveName = "OldSOFTWARE"
    )
    $ErrorLog = Join-Path -Path $TargetFolder -ChildPath "RegistryExtract_ErrorLog.txt"
    Remove-Item $ErrorLog -ErrorAction SilentlyContinue

    function Log-Error {
        param($Message)
        Add-Content -Path $ErrorLog -Value "$((Get-Date).ToString('u')) $Message"
    }

    try {
        reg.exe load "HKLM\$HiveName" $HivePath | Out-Null
        Start-Sleep -Seconds 1
    } catch {
        Log-Error "掛載 hive 失敗: $($_.Exception.Message)"
        return $false
    }

    $paths = @(
        "HKLM:\$HiveName\Classes\*\shell",
        "HKLM:\$HiveName\Classes\*\shellex\ContextMenuHandlers",
        "HKLM:\$HiveName\Classes\AllFileSystemObjects\shell",
        "HKLM:\$HiveName\Classes\Directory\shell",
        "HKLM:\$HiveName\Classes\Directory\shellex\ContextMenuHandlers",
        "HKLM:\$HiveName\Classes\Directory\Background\shell",
        "HKLM:\$HiveName\Classes\Directory\Background\shellex\ContextMenuHandlers",
        "HKLM:\$HiveName\Classes\Drive\shell",
        "HKLM:\$HiveName\Classes\Drive\shellex\ContextMenuHandlers"
    )

    $results = @()
    foreach ($path in $paths) {
        try {
            if (Test-Path $path) {
                Get-ChildItem $path -ErrorAction Stop | ForEach-Object {
                    $keyName = $_.PSChildName
                    $keyPath = $_.PSPath
                    $default = ""
                    try {
                        $default = (Get-ItemProperty -Path $_.PSPath -ErrorAction Stop)."(default)"
                    } catch {
                        Log-Error "讀取 $keyPath 預設值失敗: $($_.Exception.Message)"
                    }
                    $results += [PSCustomObject]@{
                        Path     = $keyPath
                        Name     = $keyName
                        Default  = $default
                    }
                }
            }
        } catch {
            Log-Error "處理 $path 遇到錯誤: $($_.Exception.Message)"
        }
    }

    $csvPath = Join-Path $TargetFolder "ContextMenuHandlers-OldSOFTWARE.csv"
    try {
        $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "匯出完成，請查看 $csvPath 檔案"
    } catch {
        Log-Error "匯出 CSV 失敗: $($_.Exception.Message)"
    }
    try {
        reg.exe unload "HKLM\$HiveName" | Out-Null
    } catch {
        Log-Error "卸載 hive 失敗: $($_.Exception.Message)"
    }
    return $true
}

function Main {
    $ScriptPath = $MyInvocation.MyCommand.Path

    # 步驟1-1 檢查/補簽憑證
    if (-not (Test-DigitalSignature -ScriptPath $ScriptPath)) {
        if (-not (Test-Admin)) {
            Write-Warning "補簽憑證需要系統管理員權限，嘗試提權..."
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell.exe"
            if ($args.Count -gt 0) {
                $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $($args -join ' ')"
            } else {
                $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
            }
            $psi.Verb = "runas"
            $psi.UseShellExecute = $true
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            exit
        }
        Ensure-SelfSignedCert -ScriptPath $ScriptPath
        return
    }

    # 步驟1-2 檢查系統管理員權限
    if (-not (Test-Admin)) {
        Write-Warning "補簽憑證需要系統管理員權限，嘗試提權..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        if ($args.Count -gt 0) {
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $($args -join ' ')"
        } else {
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
        }
        $psi.Verb = "runas"
        $psi.UseShellExecute = $true
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }

    # 步驟1-3 解析命令列參數
    param(
        [switch]$h,
        [string]$Source,
        [string]$Target
    )
    $argsDict = @{}
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -like "-*") {
            $key = $args[$i].TrimStart("-")
            $value = if ($i + 1 -lt $args.Count -and $args[$i+1] -notlike "-*") { $args[$i+1] } else { $null }
            $argsDict[$key] = $value
        }
    }
    if ($argsDict.ContainsKey("h")) {
        Show-Help
        Pause
        exit
    }
    $Source = $argsDict["Source"]
    $Target = $argsDict["Target"]

    # 若未指定參數則用互動視窗取得
    if (-not $Source) {
        $Source = Get-UserInput -Prompt "請輸入舊系統SOFTWARE hive檔案路徑 (如E:\Windows\System32\Config\SOFTWARE):"
    }
    if (-not $Target) {
        $Target = Get-UserInput -Prompt "請輸入備份CSV存放目標資料夾 (如D:\Backup\):"
    }

    # 步驟1-4 檢查路徑有效性
    if (-not (Test-Path $Source)) {
        Write-Error "來源SOFTWARE檔案不存在: $Source"
        Pause
        exit 1
    }
    if (-not (Test-Path $Target)) {
        try {
            New-Item -Path $Target -ItemType Directory -Force | Out-Null
            Write-Host "已建立目標資料夾: $Target"
        } catch {
            Write-Error "無法建立目標資料夾: $($_.Exception.Message)"
            Pause
            exit 1
        }
    }

    # 步驟1-5 執行備份
    $result = Backup-ContextMenuRegistry -HivePath $Source -TargetFolder $Target
    # 步驟1-6 顯示結果
    if ($result) {
        Write-Host "`n備份完成! 檔案已儲存於 $Target"
    } else {
        Write-Host "`n備份時發生錯誤，請檢查錯誤日誌。"
    }
    Write-Host "請按任意鍵結束..."
    [void][System.Console]::ReadKey($true)
}

Main