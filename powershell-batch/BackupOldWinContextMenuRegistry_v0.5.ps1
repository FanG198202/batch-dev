<# 
BackupOldWinContextMenuRegistry_v0.5.ps1

�γ~�G
  �ƥ��ª�Windows 10�ƹ��k����������U����X

�����G
  1. ���H�t�κ޲z���v������C
  2. ��ĳ�w���s�@��ñ Code Signing ���Ҩì����}��ñ�W�C
  3. ���}���|�ƥ��P�g��k���榳�������U����X�C
  4. �p�J�����h���סA�Х���ñ�W�νվ� PowerShell �����h�C

�@�̡GFan198202@gmail.com
����G2025-06-26
�����Gv0.5 �u�Ʃʯ઩��
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# �ˬd�����O�_�� Code Signing ����
$cert = Get-ChildItem -Path Cert:\LocalMachine\My -CodeSigningCert | Where-Object { $_.Subject -eq 'CN=MyCodeSigning' }

if (-not $cert) {
    Write-Host "==========================================================="
    Write-Host "�i���˴����ñ���ҡGCN=MyCodeSigning�j"
    Write-Host ""
    Write-Host "�Х���ʲ��ͦ�ñ���Ҩì����}����ñ�C"
    Write-Host ""
    Write-Host "�Ш̤U�C�B�J�ާ@�G"
    Write-Host "1. ���� bat�Gsign_ps1_files.bat�A���w�ثe��Ƨ�"
    Write-Host "2. �Τ�ʩ� PowerShell ��J�p�U���O�G"
    Write-Host ""
    Write-Host "   # �إߦ�ñ���ҡ]�p�|���إߡ^"
    Write-Host "   New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=MyCodeSigning' -CertStoreLocation 'Cert:\LocalMachine\My'"
    Write-Host ""
    Write-Host "   # �����}��ñ�W�]�д��� FilePath �����ɮ׸��|�^"
    Write-Host "   \$cert = Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert | Where-Object { \$_.Subject -eq 'CN=MyCodeSigning' }"
    Write-Host "   Set-AuthenticodeSignature -FilePath '$($MyInvocation.MyCommand.Path)' -Certificate \$cert"
    Write-Host ""
    Write-Host "�ާ@������A�Э��s���楻�}���C"
    Write-Host "==========================================================="
    Exit
}

function Show-Help {
    Write-Host @"
�{�ǦW��:
    BackupOldWinContextMenuRegistry_v0.5.ps1

�{�ǥγ~:
    �q���w�ӷ�Windows�w�˸��|�ƥ��¨t�ηƹ��k��Context Menu����Registry��ȡA�ץX��CSV�C

�R�O�C���c:
    powershell -ExecutionPolicy Bypass -File .\BackupOldWinContextMenuRegistry_v0.5.ps1 [-h] [-SourceDisk <�ƥ��ӷ��ϺХN��>] [-Target <�ƥ���X��Ƨ����|>]

�R�O�C�Ѽƻ���:
    -h             ��ܦ������T��
    -SourceDisk    �¨t�ΩҦb�ϺХN�� (��: E:\ �A����|�ˬd�ӺϺФU Windows\System32\Config\SOFTWARE ���|)
    -Target        �ƥ��ɮ��x�s�ؼи�Ƨ� (��: D:\Backup\)
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
    $result = [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, "�Ѽƿ�J", $Default)
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
    
    # �u�ơG�ϥΤ��s�Ʋսw�s���~�H���A��ֺϽL�g�J
    $errorMessages = [System.Collections.Generic.List[string]]::new()
    
    function Log-Error {
        param($Message)
        $errorMessages.Add("$((Get-Date).ToString('u')) $Message")
    }
    
    # �u�ơG��i�����U�����޿�A�W�[���վ���
    Write-Host "���b�������U��..." -ForegroundColor Cyan
    $mounted = $false
    $retryCount = 0
    
    while (-not $mounted -and $retryCount -lt 5) {
        $mountResult = reg.exe load "HKLM\$HiveName" $HivePath 2>&1
        if ($LASTEXITCODE -eq 0) {
            $mounted = $true
            Write-Host "���U�������\" -ForegroundColor Green
        } else {
            Write-Host "�������� $($retryCount+1) ���ѡA���դ�..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            $retryCount++
        }
    }
    
    if (-not $mounted) {
        Log-Error "�h�����ձ��� hive ������"
        Write-Host "�������U���ѡA�Ьd�ݿ��~��x" -ForegroundColor Red
        return $false
    }
    
    # �u�ơG���U����|�C��]�i�ھڹ�ڱ��p���������ݭn�����|�^
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
    
    Write-Host "�}�l���˵��U��..." -ForegroundColor Cyan
    
    # �u�ơG�ϥμƲսw�s���G�A�̫��q�ɥX
    $results = [System.Collections.Generic.List[object]]::new()
    
    foreach ($path in $paths) {
        try {
            if (Test-Path $path) {
                Write-Host "���b�B�z���|: $path" -ForegroundColor DarkCyan
                
                # �u�ơG�ϥΧ�֪����U��d�ߤ�k
                $items = Get-ChildItem $path -ErrorAction SilentlyContinue
                $itemCount = $items.Count
                $processed = 0
                
                foreach ($item in $items) {
                    $keyName = $item.PSChildName
                    $keyPath = $item.PSPath
                    $default = ""
                    
                    try {
                        # �u�ơG��������q�{�ȡA�קK���`���򪺩ʯ�}�P
                        $itemProps = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
                        if ($itemProps) {
                            $default = $itemProps."(default)"
                        }
                    } catch {
                        Log-Error "Ū�� $keyPath �q�{�ȥ���: $($_.Exception.Message)"
                    }
                    
                    # �K�[�쵲�G��
                    $results.Add([PSCustomObject]@{
                        Path    = $keyPath
                        Name    = $keyName
                        Default = $default
                    })
                    
                    # ��ܶi��
                    $processed++
                    if ($processed % 100 -eq 0) {
                        Write-Progress -Activity "�B�z���U��" -Status "�w�B�z: $processed / $itemCount" -PercentComplete (($processed / $itemCount) * 100)
                    }
                }
                
                Write-Progress -Activity "�B�z���U��" -Completed
            } else {
                Write-Host "���|���s�b: $path" -ForegroundColor Yellow
            }
        } catch {
            Log-Error "�B�z $path �J����~: $($_.Exception.Message)"
            Write-Host "�B�z���|�ɥX��: $path" -ForegroundColor Red
        }
    }
    
    # �u�ơG��q�ɥXCSV
    Write-Host "���b�ɥX���G��CSV..." -ForegroundColor Cyan
    try {
        $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Force
        Write-Host "�ɥX�����A�@�B�z $($results.Count) �ӵ��U��" -ForegroundColor Green
    } catch {
        Log-Error "�ɥX CSV ����: $($_.Exception.Message)"
        Write-Host "�ɥXCSV���ѡA�Ьd�ݿ��~��x" -ForegroundColor Red
    }
    
    # �������U��
    Write-Host "���b�������U��..." -ForegroundColor Cyan
    try {
        reg.exe unload "HKLM\$HiveName" | Out-Null
        Write-Host "���U��������\" -ForegroundColor Green
    } catch {
        Log-Error "���� hive ����: $($_.Exception.Message)"
        Write-Host "�������U���ѡA�Ф���ˬd" -ForegroundColor Red
    }
    
    # �g�J���~��x
    if ($errorMessages.Count -gt 0) {
        try {
            $errorMessages | Out-File -FilePath $ErrorLog -Encoding UTF8 -Force
            Write-Host "���~��x�w�O�s��: $ErrorLog" -ForegroundColor Yellow
        } catch {
            Write-Host "�O�s���~��x����!" -ForegroundColor Red
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
    
    # �ˬd�t�κ޲z���v��
    if (-not (Test-Admin)) {
        Write-Host "�ݭn�t�κ޲z���v���A���մ��v..." -ForegroundColor Yellow
        
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
            Write-Host "���v���ѡA�Ф�ʥH�t�κ޲z�������B�榹�}��" -ForegroundColor Red
        }
        exit
    }
    
    # �B�z�R�O�C�Ѽ�
    if ($h) {
        Show-Help
        Pause
        exit
    }
    
    # ����ӷ��ϽL
    if (-not $SourceDisk) {
        $SourceDisk = Get-UserInput -Prompt "�п�J�¨t�ΩҦb�ϽL�N�� (��: E:\ �A�N�ˬd�ӺϽL�U��Windows\System32\Config\SOFTWARE):"
        
        # �T�O�ϽL���|�榡���T
        if ($SourceDisk -notmatch ':\\$') {
            $SourceDisk = $SourceDisk.TrimEnd('\') + '\'
        }
    }
    
    # �c�ا��㪺SOFTWARE���|
    $Source = Join-Path -Path $SourceDisk -ChildPath "Windows\System32\Config\SOFTWARE"
    
    # ����ؼФ��
    if (-not $Target) {
        $Target = Get-UserInput -Prompt "�п�J�ƥ�CSV�s��ؼФ�� (�pD:\Backup\):"
    }
    
    # �ˬd���|���ĩ�
    Write-Host "���b�ˬd���|���ĩ�..." -ForegroundColor Cyan
    
    if (-not (Test-Path $Source)) {
        Write-Host "���~: �ӷ��ϽL $SourceDisk �U��SOFTWARE��󤣦s�b: $Source" -ForegroundColor Red
        Pause
        exit 1
    }
    
    if (-not (Test-Path $Target)) {
        try {
            New-Item -Path $Target -ItemType Directory -Force | Out-Null
            Write-Host "�w�إߥؼФ��: $Target" -ForegroundColor Green
        } catch {
            Write-Host "�L�k�إߥؼФ��: $($_.Exception.Message)" -ForegroundColor Red
            Pause
            exit 1
        }
    }
    
    # �O���}�l�ɶ�
    $startTime = Get-Date
    Write-Host "�}�l�ƥ����U��A�ɶ�: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    
    # ����ƥ�
    $result = Backup-ContextMenuRegistry -HivePath $Source -TargetFolder $Target
    
    # �O�������ɶ��íp��Ӯ�
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    # ��ܵ��G
    if ($result) {
        Write-Host "`n�ƥ�����! ���w�x�s�� $Target" -ForegroundColor Green
        Write-Host "�Ӯ�: $($duration.Hours)�p�� $($duration.Minutes)���� $($duration.Seconds)��" -ForegroundColor Green
    } else {
        Write-Host "`n�ƥ��ɵo�Ϳ��~�A���ˬd���~��x�C" -ForegroundColor Red
    }
    
    Write-Host "�Ы����N�䵲��..."
    [void][System.Console]::ReadKey($true)
}

# �ե� Main ��ƨöǤJ�Ҧ��Ѽ�
Main @args

