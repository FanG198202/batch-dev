<#
.SYNOPSIS
   備份舊系統滑鼠右鍵Context Menu Registry鍵值
.DESCRIPTION
   此腳本會從指定的舊系統路徑讀取Context Menu Registry鍵值，
   備份到指定的備份資料夾路徑。
.NOTES
   必須以管理員權限執行
   檔案名稱: BackupOldWinContextMenuRegistry_v0.2.ps1
   作者: 
   版本: 0.2
#>

# 指定運作環境為 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 檢查是否為系統管理員，否則嘗試提權
function Test-Admin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Warning "本腳本需以系統管理員權限執行，正在嘗試自動提權..."
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        $psi.UseShellExecute = $true
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    } catch {
        Write-Error "無法自動提權，請手動以系統管理員身份重新執行本腳本。"
        exit 1
    }
}

# 錯誤記錄檔案
$ErrorLog = ".\RegistryExtract_ErrorLog.txt"
Remove-Item $ErrorLog -ErrorAction SilentlyContinue

function Log-Error {
    param($Message)
    Add-Content -Path $ErrorLog -Value "$((Get-Date).ToString('u')) $Message"
}

# 掛載舊系統 registry hive (假設 E: 為外接硬碟)
$HivePath = "E:\Windows\System32\Config\SOFTWARE"
$HiveName = "OldSOFTWARE"

try {
    reg.exe load "HKLM\$HiveName" $HivePath | Out-Null
    Start-Sleep -Seconds 1
} catch {
    Log-Error "掛載 hive 失敗: $($_.Exception.Message)"
    exit 1
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

# 匯出結果
try {
    $results | Export-Csv -Path ".\ContextMenuHandlers-OldSOFTWARE.csv" -NoTypeInformation -Encoding UTF8
    Write-Host "匯出完成，請查看 ContextMenuHandlers-OldSOFTWARE.csv 檔案"
} catch {
    Log-Error "匯出 CSV 失敗: $($_.Exception.Message)"
}

# 卸載 hive
try {
    reg.exe unload "HKLM\$HiveName" | Out-Null
} catch {
    Log-Error "卸載 hive 失敗: $($_.Exception.Message)"
}

Write-Host "腳本執行完畢。若有錯誤請檢查 $ErrorLog"