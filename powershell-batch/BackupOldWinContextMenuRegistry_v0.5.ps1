<# 
BackupOldWinContextMenuRegistry_v0.5.ps1

用途：
  備份舊版Windows 10滑鼠右鍵選單相關註冊表機碼

說明：
  1. 須以系統管理員權限執行。
  2. 建議預先製作自簽 Code Signing 憑證並為本腳本簽名。
  3. 本腳本會備份與經典右鍵選單有關的註冊表機碼。
  4. 如遇執行原則阻擋，請先補簽名或調整 PowerShell 執行原則。

作者：Fan198202@gmail.com
日期：2025-06-26
版本：v0.5 優化性能版本
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 檢查本機是否有 Code Signing 憑證
$cert = Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' }

if (-not $cert) {
    Write-Host "==========================================================="
    Write-Host "【未檢測到自簽憑證：CN=MyCodeSigning】"
    Write-Host ""
    Write-Host "請先手動產生自簽憑證並為本腳本補簽。"
    Write-Host ""
    Write-Host "請依下列步驟操作："
    Write-Host "1. 執行 bat：sign_ps1_files.bat，指定目前資料夾"
    Write-Host "2. 或手動於 PowerShell 輸入如下指令："
    Write-Host ""
    Write-Host "   # 建立自簽憑證（如尚未建立）"
    Write-Host "   New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=MyCodeSigning' -CertStoreLocation 'Cert:\LocalMachine\My'"
    Write-Host ""
    Write-Host "   # 幫本腳本簽名（請替換 FilePath 為本檔案路徑）"
    Write-Host "   \$cert = Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert | Where-Object { \$_.Subject -eq 'CN=MyCodeSigning' }"
    Write-Host "   Set-AuthenticodeSignature -FilePath '$($MyInvocation.MyCommand.Path)' -Certificate \$cert"
    Write-Host ""
    Write-Host "操作完畢後，請重新執行本腳本。"
    Write-Host "==========================================================="
    Exit
}

function Show-Help {
    Write-Host @"
程序名稱:
    BackupOldWinContextMenuRegistry_v0.5.ps1

程序用途:
    從指定來源Windows安裝路徑備份舊系統滑鼠右鍵Context Menu相關Registry鍵值，匯出為CSV。

命令列結構:
    powershell -ExecutionPolicy Bypass -File .\BackupOldWinContextMenuRegistry_v0.5.ps1 [-h] [-SourceDisk <備份來源磁碟代號>] [-Target <備份輸出資料夾路徑>]

命令列參數說明:
    -h             顯示此說明訊息
    -SourceDisk    舊系統所在磁碟代號 (例: E:\ ，後續會檢查該磁碟下 Windows\System32\Config\SOFTWARE 路徑)
    -Target        備份檔案儲存目標資料夾 (例: D:\Backup\)
"@
}

function Test-Admin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
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
    $csvPath = Join-Path $TargetFolder "ContextMenuHandlers-OldSOFTWARE.csv"
    
    # 優化：使用內存數組緩存錯誤信息，減少磁盤寫入
    $errorMessages = [System.Collections.Generic.List[string]]::new()
    
    function Log-Error {
        param($Message)
        $errorMessages.Add("$((Get-Date).ToString('u')) $Message")
    }
    
    # 優化：改進的註冊表掛載邏輯，增加重試機制
    Write-Host "正在掛載註冊表..." -ForegroundColor Cyan
    $mounted = $false
    $retryCount = 0
    
    while (-not $mounted -and $retryCount -lt 5) {
        $mountResult = reg.exe load "HKLM\$HiveName" $HivePath 2>&1
        if ($LASTEXITCODE -eq 0) {
            $mounted = $true
            Write-Host "註冊表掛載成功" -ForegroundColor Green
        } else {
            Write-Host "掛載嘗試 $($retryCount+1) 失敗，重試中..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            $retryCount++
        }
    }
    
    if (-not $mounted) {
        Log-Error "多次嘗試掛載 hive 仍失敗"
        Write-Host "掛載註冊表失敗，請查看錯誤日誌" -ForegroundColor Red
        return $false
    }
    
    # 優化：註冊表路徑列表（可根據實際情況註釋掉不需要的路徑）
    $paths = @(
        "HKLM:\$HiveName\Classes\*\shell",
        "HKLM:\$HiveName\Classes\*\shellex\ContextMenuHandlers",
        "HKLM:\$HiveName\Classes\Directory\shell",
        "HKLM:\$HiveName\Classes\Directory\shellex\ContextMenuHandlers",
        "HKLM:\$HiveName\Classes\Directory\Background\shell",
        "HKLM:\$HiveName\Classes\Directory\Background\shellex\ContextMenuHandlers",
        "HKLM:\$HiveName\Classes\Drive\shell",
        "HKLM:\$HiveName\Classes\Drive\shellex\ContextMenuHandlers"
    )
    
    Write-Host "開始掃瞄註冊表項..." -ForegroundColor Cyan
    
    # 優化：使用數組緩存結果，最後批量導出
    $results = [System.Collections.Generic.List[object]]::new()
    
    foreach ($path in $paths) {
        try {
            if (Test-Path $path) {
                Write-Host "正在處理路徑: $path" -ForegroundColor DarkCyan
                
                # 優化：使用更快的註冊表查詢方法
                $items = Get-ChildItem $path -ErrorAction SilentlyContinue
                $itemCount = $items.Count
                $processed = 0
                
                foreach ($item in $items) {
                    $keyName = $item.PSChildName
                    $keyPath = $item.PSPath
                    $default = ""
                    
                    try {
                        # 優化：直接獲取默認值，避免異常捕獲的性能開銷
                        $itemProps = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
                        if ($itemProps) {
                            $default = $itemProps."(default)"
                        }
                    } catch {
                        Log-Error "讀取 $keyPath 默認值失敗: $($_.Exception.Message)"
                    }
                    
                    # 添加到結果集
                    $results.Add([PSCustomObject]@{
                        Path    = $keyPath
                        Name    = $keyName
                        Default = $default
                    })
                    
                    # 顯示進度
                    $processed++
                    if ($processed % 100 -eq 0) {
                        Write-Progress -Activity "處理註冊表項" -Status "已處理: $processed / $itemCount" -PercentComplete (($processed / $itemCount) * 100)
                    }
                }
                
                Write-Progress -Activity "處理註冊表項" -Completed
            } else {
                Write-Host "路徑不存在: $path" -ForegroundColor Yellow
            }
        } catch {
            Log-Error "處理 $path 遇到錯誤: $($_.Exception.Message)"
            Write-Host "處理路徑時出錯: $path" -ForegroundColor Red
        }
    }
    
    # 優化：批量導出CSV
    Write-Host "正在導出結果到CSV..." -ForegroundColor Cyan
    try {
        $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Force
        Write-Host "導出完成，共處理 $($results.Count) 個註冊表項" -ForegroundColor Green
    } catch {
        Log-Error "導出 CSV 失敗: $($_.Exception.Message)"
        Write-Host "導出CSV失敗，請查看錯誤日誌" -ForegroundColor Red
    }
    
    # 卸載註冊表
    Write-Host "正在卸載註冊表..." -ForegroundColor Cyan
    try {
        reg.exe unload "HKLM\$HiveName" | Out-Null
        Write-Host "註冊表卸載成功" -ForegroundColor Green
    } catch {
        Log-Error "卸載 hive 失敗: $($_.Exception.Message)"
        Write-Host "卸載註冊表失敗，請手動檢查" -ForegroundColor Red
    }
    
    # 寫入錯誤日誌
    if ($errorMessages.Count -gt 0) {
        try {
            $errorMessages | Out-File -FilePath $ErrorLog -Encoding UTF8 -Force
            Write-Host "錯誤日誌已保存至: $ErrorLog" -ForegroundColor Yellow
        } catch {
            Write-Host "保存錯誤日誌失敗!" -ForegroundColor Red
        }
    }
    
    return $results.Count -gt 0
}

function Main {
    [CmdletBinding()]
    param(
        [switch]$h,
        [string]$SourceDisk,
        [string]$Target
    )
    
    # 檢查系統管理員權限
    if (-not (Test-Admin)) {
        Write-Host "需要系統管理員權限，嘗試提權..." -ForegroundColor Yellow
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        
        if ($PSBoundParameters.Count -gt 0) {
            $params = $PSBoundParameters.GetEnumerator() | ForEach-Object {
                if ($_.Value -is [switch]) {
                    "-$($_.Key)"
                } else {
                    "-$($_.Key) '$($_.Value)'"
                }
            }
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($params -join ' ')"
        } else {
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        }
        
        $psi.Verb = "runas"
        $psi.UseShellExecute = $true
        
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            Write-Host "提權失敗，請手動以系統管理員身份運行此腳本" -ForegroundColor Red
        }
        exit
    }
    
    # 處理命令列參數
    if ($h) {
        Show-Help
        Pause
        exit
    }
    
    # 獲取來源磁盤
    if (-not $SourceDisk) {
        $SourceDisk = Get-UserInput -Prompt "請輸入舊系統所在磁盤代號 (例: E:\ ，將檢查該磁盤下的Windows\System32\Config\SOFTWARE):"
        
        # 確保磁盤路徑格式正確
        if ($SourceDisk -notmatch ':\\$') {
            $SourceDisk = $SourceDisk.TrimEnd('\') + '\'
        }
    }
    
    # 構建完整的SOFTWARE路徑
    $Source = Join-Path -Path $SourceDisk -ChildPath "Windows\System32\Config\SOFTWARE"
    
    # 獲取目標文件夾
    if (-not $Target) {
        $Target = Get-UserInput -Prompt "請輸入備份CSV存放目標文件夾 (如D:\Backup\):"
    }
    
    # 檢查路徑有效性
    Write-Host "正在檢查路徑有效性..." -ForegroundColor Cyan
    
    if (-not (Test-Path $Source)) {
        Write-Host "錯誤: 來源磁盤 $SourceDisk 下的SOFTWARE文件不存在: $Source" -ForegroundColor Red
        Pause
        exit 1
    }
    
    if (-not (Test-Path $Target)) {
        try {
            New-Item -Path $Target -ItemType Directory -Force | Out-Null
            Write-Host "已建立目標文件夾: $Target" -ForegroundColor Green
        } catch {
            Write-Host "無法建立目標文件夾: $($_.Exception.Message)" -ForegroundColor Red
            Pause
            exit 1
        }
    }
    
    # 記錄開始時間
    $startTime = Get-Date
    Write-Host "開始備份註冊表，時間: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    
    # 執行備份
    $result = Backup-ContextMenuRegistry -HivePath $Source -TargetFolder $Target
    
    # 記錄結束時間並計算耗時
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    # 顯示結果
    if ($result) {
        Write-Host "`n備份完成! 文件已儲存於 $Target" -ForegroundColor Green
        Write-Host "耗時: $($duration.Hours)小時 $($duration.Minutes)分鐘 $($duration.Seconds)秒" -ForegroundColor Green
    } else {
        Write-Host "`n備份時發生錯誤，請檢查錯誤日誌。" -ForegroundColor Red
    }
    
    Write-Host "請按任意鍵結束..."
    [void][System.Console]::ReadKey($true)
}

# 調用 Main 函數並傳入所有參數
Main @args

