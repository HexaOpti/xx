# Converted from custom.yml. Generated action-by-action; review before running.
# IMPORTANT: This configuration disables security protections, changes UAC, deletes system paths/tasks,
# modifies networking and may delete restore shadow copies and event logs. Run only on a machine you control.
# The source YAML had two malformed fragments: an unterminated HEXA quote (repaired for parsing) and an orphaned
# 'TrayRefreshMs' registry-value fragment (omitted because its registry path/value name were missing).
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptRoot
function Write-Status([string]$Message) { Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
function Convert-RegPath([string]$Path) {
  $p = $Path -replace "^HKLM\\?", "HKLM:\" -replace "^HKCU\\?", "HKCU:\" -replace "^HKCR\\?", "Registry::HKEY_CLASSES_ROOT\" -replace "^HKU\\?", "Registry::HKEY_USERS\" -replace "^HKCC\\?", "Registry::HKEY_CURRENT_CONFIG\"
  return $p
}
function Set-Reg([string]$Path,[string]$Name,[string]$Kind,[string]$Data) {
  try { $p = Convert-RegPath $Path; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null }; $k = switch ($Kind.ToUpper()) { "REG_DWORD" { "DWord" } "REG_QWORD" { "QWord" } "REG_SZ" { "String" } "REG_EXPAND_SZ" { "ExpandString" } "REG_BINARY" { "Binary" } "REG_MULTI_SZ" { "MultiString" } default { "String" } }; $v = $Data; if ($k -eq "DWord") { $v = [Convert]::ToUInt32($Data,10) }; if ($k -eq "QWord") { $v = [Convert]::ToUInt64($Data,10) }; if ($k -eq "Binary") { $hex = $Data -replace "\s", ""; $bytes = [System.Collections.Generic.List[byte]]::new(); for ($i = 0; $i -lt $hex.Length; $i += 2) { $bytes.Add([Convert]::ToByte($hex.Substring($i,2),16)) }; $v = $bytes.ToArray() }; if ($k -eq "MultiString") { $v = @($Data -split ";") }; New-ItemProperty -LiteralPath $p -Name $Name -PropertyType $k -Value $v -Force | Out-Null } catch { Write-Warning "Registry set failed: $Path [$Name] - $_" }
}
function Remove-RegKey([string]$Path) { try { $p=Convert-RegPath $Path; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "Registry key removal failed: $Path - $_" } }
function Remove-RegValue([string]$Path,[string]$Name) { try { $p=Convert-RegPath $Path; if (Test-Path -LiteralPath $p) { Remove-ItemProperty -LiteralPath $p -Name $Name -Force -ErrorAction Stop } } catch { Write-Warning "Registry value removal failed: $Path [$Name] - $_" } }
function Resolve-Env([string]$Value) { [Environment]::ExpandEnvironmentVariables($Value) }
function Invoke-Native([string]$File,[string]$Arguments) { try { $p=Start-Process -FilePath $File -ArgumentList $Arguments -Wait -PassThru -ErrorAction Stop; if ($p.ExitCode -ne 0) { Write-Warning "$File exited with code $($p.ExitCode)" } } catch { Write-Warning "Could not run $File $Arguments : $_" } }
function Invoke-Cmd([string]$Command) { try { & $env:ComSpec /d /s /c $Command; if ($LASTEXITCODE -ne 0) { Write-Warning "Command exited with code $LASTEXITCODE" } } catch { Write-Warning "Command failed: $_" } }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Error "Run this script from an elevated PowerShell window (Run as administrator)."; exit 1 }
Write-Host "This script applies a large Windows configuration, including disabling Defender-related protections and UAC, deleting system items, and clearing logs/shadow copies." -ForegroundColor Yellow
$confirm = Read-Host "Type APPLY to continue, or anything else to cancel"
if ($confirm -cne "APPLY") { Write-Host "Cancelled."; exit 0 }


# Action 1: !status
Write-Status 'Initializing'

# Action 2: !cmd
Invoke-Cmd 'Robocopy Files %SystemDrive%\ /copy:DA /e /nfl /ndl /njh /nc /ns /np >nul'

# Action 3: !cmd
Invoke-Cmd 'powercfg /import "%CD%\hexa.pow" 01010110-0110-0001-0110-100101101110'

# Action 4: !cmd
Invoke-Cmd 'powercfg /setactive 01010110-0110-0001-0110-100101101110 >nul'

# Action 5: !powerShell
$__cmd = @'
powercfg -list | ForEach-Object { $guid = $_ -replace '.*Power Scheme GUID: ([a-f0-9-]+).*','$1'; if ($guid -ne $_) { powercfg -delete $guid 2>$null } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 6: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy' 'VerifiedAndReputablePolicyState' 'REG_DWORD' '0'

# Action 7: !cmd
Invoke-Cmd 'ipconfig /flushdns >nul'

# Action 8: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'SystemUsesLightTheme' 'REG_DWORD' '0'

# Action 9: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme' 'REG_DWORD' '0'

# Action 10: !status
Write-Status 'Changing Wallpaper & Lockscreen'

# Action 11: !powerShell
$__cmd = @'
$path='C:\Windows\Web\Wallpaper\hexa\img0.jpg'; Get-ChildItem 'Registry::HKU' | ForEach-Object {$key=$_.Name; [microsoft.win32.registry]::SetValue($key+'\Control Panel\Desktop','WallPaper',$path,[Microsoft.Win32.RegistryValueKind]::String)}; Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class Wallpaper{[DllImport(\"user32.dll\",CharSet=CharSet.Auto)]public static extern int SystemParametersInfo(int uAction,int uParam,string lpvParam,int fuWinIni);}'; [Wallpaper]::SystemParametersInfo(20,0,$path,3)
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 12: !powerShell
$__cmd = @'
Add-Type -AssemblyName System.Runtime.WindowsRuntime; [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null; [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime] | Out-Null; $a=[System.WindowsRuntimeSystemExtensions].GetMethods(); $f=($a|Where-Object{$_.Name -eq 'AsTask' -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'})[0].MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null,@([Windows.Storage.StorageFile]::GetFileFromPathAsync('C:\Windows\Web\Wallpaper\hexa\img0.jpg'))).GetAwaiter().GetResult(); ($a|Where-Object{$_.Name -eq 'AsTask' -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'})[0].Invoke($null,@([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($f))).GetAwaiter().GetResult()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 13: !taskKill
try { Stop-Process -Name 'explorer' -Force -ErrorAction SilentlyContinue } catch {}

# Action 14: !status
Write-Status 'Configuring Powershell'

# Action 15: !cmd
Invoke-Cmd 'setx POWERSHELL_TELEMETRY_OPTOUT 1 >nul'

# Action 16: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' 'ExecutionPolicy' 'REG_SZ' 'Unrestricted'

# Action 17: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging' 'EnableModuleLogging' 'REG_DWORD' '0'

# Action 18: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' 'EnableScriptBlockLogging' 'REG_DWORD' '0'

# Action 19: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' 'EnableScriptBlockInvocationLogging' 'REG_DWORD' '0'

# Action 20: !cmd
Invoke-Cmd 'ftype Microsoft.PowerShellScript.1="%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -EP Unrestricted -File "%1" %* >nul'

# Action 21: !registryValue
Set-Reg 'HKCR\Microsoft.PowerShellScript.1\Shell' '' 'REG_SZ' 'Open'

# Action 22: !registryValue
Set-Reg 'HKCR\Microsoft.PowerShellScript.1\Shell\Open\Command' '' 'REG_EXPAND_SZ' '"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" "%1"'

# Action 23: !registryValue
Set-Reg 'HKCR\Microsoft.PowerShellScript.1\Shell\RunAs' 'HasLUAShield' 'REG_SZ' ''

# Action 24: !registryValue
Set-Reg 'HKCR\Microsoft.PowerShellScript.1\Shell\RunAs\Command' '' 'REG_EXPAND_SZ' '"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" "%1"'

# Action 25: !registryValue
Set-Reg 'HKCR\.psm1' '' 'REG_SZ' 'Microsoft.PowerShellModule.1'

# Action 26: !registryValue
Set-Reg 'HKCR\Microsoft.PowerShellModule.1\Shell' '' 'REG_SZ' 'Open'

# Action 27: !registryKey
try { $p=Convert-RegPath 'HKCR\.psm1\OpenWithProgids'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\.psm1\OpenWithProgids - $_" }

# Action 28: !registryKey
try { $p=Convert-RegPath 'HKCR\.ps1\OpenWithProgids'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\.ps1\OpenWithProgids - $_" }

# Action 29: !status
Write-Status 'Installing NGEN'

# Action 30: !powerShell
$__cmd = @'
$env:PATH="$([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory());$env:PATH";foreach($a in [AppDomain]::CurrentDomain.GetAssemblies()){if($a.Location){ngen install $a.Location /nologo 2>&1 | Out-Null}}
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 31: !powerShell
$__cmd = @'
Add-Type -AssemblyName System.Drawing; $img = [System.Drawing.Image]::FromFile((Join-Path $PWD 'user.png')); $dest = [Environment]::GetFolderPath('CommonApplicationData') + '\Microsoft\User Account Pictures\'; @{'user.png'=448;'user.bmp'=448;'guest.png'=448;'guest.bmp'=448;'user-192.png'=192;'user-48.png'=48;'user-40.png'=40;'user-32.png'=32}.GetEnumerator() | ForEach-Object { $b = New-Object System.Drawing.Bitmap($_.Value,$_.Value); $g = [System.Drawing.Graphics]::FromImage($b); $g.DrawImage($img,0,0,$_.Value,$_.Value); $b.Save($dest + $_.Key); $g.Dispose(); $b.Dispose() }; $img.Dispose()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 32: !powerShell
$__cmd = @'
Add-Type -AssemblyName System.Drawing; $img = [System.Drawing.Image]::FromFile((Join-Path $PWD 'user.png')); $sid = (New-Object System.Security.Principal.NTAccount($env:USERNAME)).Translate([System.Security.Principal.SecurityIdentifier]).Value; $dest = 'C:\Users\Public\AccountPictures\' + $sid; if (!(Test-Path $dest)) { New-Item -Path $dest -ItemType Directory -Force }; $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\' + $sid; if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force }; @(1080,448,424,240,208,192,96,64,48,40,32) | ForEach-Object { $b = New-Object System.Drawing.Bitmap($_,$_); $g = [System.Drawing.Graphics]::FromImage($b); $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic; $g.DrawImage($img,0,0,$_,$_); $f = $dest + '\Image' + $_ + '.png'; $b.Save($f,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $b.Dispose(); Set-ItemProperty -Path $regPath -Name ('Image' + $_) -Value $f -Type String }; $img.Dispose()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 33: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.WindowsNotepad*' -or $_.PackageFullName -like 'Microsoft.WindowsNotepad*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.WindowsNotepad*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.WindowsNotepad*: $_" }

# Action 34: !status
Write-Status 'Disabling Notifications'

# Action 35: !service
try { Set-Service -Name 'WpnService' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service WpnService: $_" }

# Action 36: !service
try { Stop-Service -Name 'WpnService' -Force -ErrorAction Stop } catch { Write-Warning "Could not stop service WpnService: $_" }

# Action 37: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userNotificationListener' 'Value' 'REG_SZ' 'Deny'

# Action 38: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications' 'ToastEnabled' 'REG_DWORD' '0'

# Action 39: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications' 'NoCloudApplicationNotification' 'REG_DWORD' '1'

# Action 40: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 'REG_DWORD' '0'

# Action 41: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND' 'REG_DWORD' '0'

# Action 42: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK' 'REG_DWORD' '0'

# Action 43: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK' 'REG_DWORD' '0'

# Action 44: !taskKill
try { Stop-Process -Name 'SystemSettings' -Force -ErrorAction SilentlyContinue } catch {}

# Action 45: !taskKill
try { Stop-Process -Name 'ShellExperienceHost' -Force -ErrorAction SilentlyContinue } catch {}

# Action 46: !status
Write-Status 'Removing Windows Defender'

# Action 47: !taskKill
try { Stop-Process -Name 'NisSrv' -Force -ErrorAction SilentlyContinue } catch {}

# Action 48: !taskKill
try { Stop-Process -Name 'SecurityHealthHost' -Force -ErrorAction SilentlyContinue } catch {}

# Action 49: !taskKill
try { Stop-Process -Name 'SecurityHealthService' -Force -ErrorAction SilentlyContinue } catch {}

# Action 50: !taskKill
try { Stop-Process -Name 'SecurityHealthSystray' -Force -ErrorAction SilentlyContinue } catch {}

# Action 51: !taskKill
try { Stop-Process -Name 'SkypeBackgroundHost' -Force -ErrorAction SilentlyContinue } catch {}

# Action 52: !taskKill
try { Stop-Process -Name 'MsMpEng' -Force -ErrorAction SilentlyContinue } catch {}

# Action 53: !taskKill
try { Stop-Process -Name 'msiexec' -Force -ErrorAction SilentlyContinue } catch {}

# Action 54: !taskKill
try { Stop-Process -Name 'smartscreen' -Force -ErrorAction SilentlyContinue } catch {}

# Action 55: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*SecHealthUI*' -or $_.PackageFullName -like '*SecHealthUI*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*SecHealthUI*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *SecHealthUI*: $_" }

# Action 56: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Windows.Apprep.ChxApp*' -or $_.PackageFullName -like 'Microsoft.Windows.Apprep.ChxApp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.Windows.Apprep.ChxApp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.Windows.Apprep.ChxApp*: $_" }

# Action 57: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Microsoft Antimalware\Real-Time Protection' 'DisableScanOnRealtimeEnable' 'REG_DWORD' '1'

# Action 58: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Microsoft Antimalware\Real-Time Protection' 'DisableOnAccessProtection' 'REG_DWORD' '1'

# Action 59: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' 'DisableScanOnRealtimeEnable' 'REG_DWORD' '1'

# Action 60: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' 'DisableBehaviorMonitoring' 'REG_DWORD' '1'

# Action 61: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\MicrosoftEdge\PhishingFilter' 'EnabledV9' 'REG_DWORD' '0'

# Action 62: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 'REG_DWORD' '0'

# Action 63: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\Sense'

# Action 64: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\WinDefend'

# Action 65: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\MsSecCore'

# Action 66: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\wscsvc'

# Action 67: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\WdFilter'

# Action 68: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\WdBoot'

# Action 69: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\WdNisDrv'

# Action 70: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\WdNisSvc'

# Action 71: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\MsSecWfp'

# Action 72: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\MsSecFlt'

# Action 73: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\wtd'

# Action 74: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\webthreatdefusersvc'

# Action 75: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\webthreatdefsvc'

# Action 76: !registryKey
Remove-RegKey 'HKLM\SYSTEM\CurrentControlSet\Services\SecurityHealthService'

# Action 77: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components' 'ServiceEnabled' 'REG_DWORD' '0'

# Action 78: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Edge' 'SmartScreenEnabled' 'REG_SZ' '0'

# Action 79: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' 'EnableWebContentEvaluation' 'REG_DWORD' '0'

# Action 80: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled' 'REG_SZ' 'Off'

# Action 81: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows Defender\Spynet' 'SubmitSamplesConsent' 'REG_DWORD' '0'

# Action 82: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows Defender\Spynet' 'SpyNetReporting' 'REG_DWORD' '0'

# Action 83: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'SecurityHealth'

# Action 84: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'WindowsDefender'

# Action 85: !file
try { $p=Resolve-Env '%systemroot%\System32\SecurityHealthSystray.exe'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\SecurityHealthSystray.exe - $_" }

# Action 86: !file
try { $p=Resolve-Env '%systemroot%\System32\SecurityHealthService.exe'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\SecurityHealthService.exe - $_" }

# Action 87: !file
try { $p=Resolve-Env '%systemroot%\System32\SecurityHealthAgent.dll'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\SecurityHealthAgent.dll - $_" }

# Action 88: !file
try { $p=Resolve-Env '%systemroot%\System32\SecurityHealthHost.exe'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\SecurityHealthHost.exe - $_" }

# Action 89: !file
try { $p=Resolve-Env '%systemroot%\System32\SecurityHealthCore.dll'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\SecurityHealthCore.dll - $_" }

# Action 90: !file
try { $p=Resolve-Env '%systemroot%\System32\SecurityHealthProxyStub.dll'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\SecurityHealthProxyStub.dll - $_" }

# Action 91: !file
try { $p=Resolve-Env '%systemroot%\System32\SecurityHealthUdk.dll'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\SecurityHealthUdk.dll - $_" }

# Action 92: !file
try { $p=Resolve-Env '%ProgramW6432%\Windows Defender Advanced Thread Protection'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramW6432%\Windows Defender Advanced Thread Protection - $_" }

# Action 93: !file
try { $p=Resolve-Env '%ProgramW6432%\Windows Defender'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramW6432%\Windows Defender - $_" }

# Action 94: !file
try { $p=Resolve-Env '%PROGRAMFILES(x86)% \Windows Defender'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %PROGRAMFILES(x86)% \Windows Defender - $_" }

# Action 95: !file
try { $p=Resolve-Env '%ProgramData%\Microsoft\Windows Defender'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramData%\Microsoft\Windows Defender - $_" }

# Action 96: !file
try { $p=Resolve-Env '%ProgramFiles(x86)%\Windows Defender'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles(x86)%\Windows Defender - $_" }

# Action 97: !file
try { $p=Resolve-Env '%systemroot%\System32\drivers\WdNisDrv.sys'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\drivers\WdNisDrv.sys - $_" }

# Action 98: !file
try { $p=Resolve-Env '%ProgramW6432%\Windows Defender Advanced Threat Protection'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramW6432%\Windows Defender Advanced Threat Protection - $_" }

# Action 99: !file
try { $p=Resolve-Env '%SystemDrive%\ProgramData\Microsoft\Windows Defender Advanced Threat Protection'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %SystemDrive%\ProgramData\Microsoft\Windows Defender Advanced Threat Protection - $_" }

# Action 100: !file
try { $p=Resolve-Env '%ProgramW6432%\Microsoft Update Health Tools'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramW6432%\Microsoft Update Health Tools - $_" }

# Action 101: !file
try { $p=Resolve-Env '%ProgramW6432%\PCHealthCheck'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramW6432%\PCHealthCheck - $_" }

# Action 102: !file
try { $p=Resolve-Env '%systemroot%\System32\smartscreen.exe'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\smartscreen.exe - $_" }

# Action 103: !file
try { $p=Resolve-Env '%systemroot%\System32\smartscreenps.dll'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\System32\smartscreenps.dll - $_" }

# Action 104: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\UpdateHealthTools'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\UpdateHealthTools - $_" }

# Action 105: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\rempl'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\rempl - $_" }

# Action 106: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\CloudManagedUpdate'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\CloudManagedUpdate - $_" }

# Action 107: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName 'Windows Defender Cache Maintenance' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance - $_" }

# Action 108: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName 'Windows Defender Cleanup' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \Microsoft\Windows\Windows Defender\Windows Defender Cleanup - $_" }

# Action 109: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName 'Windows Defender Scheduled Scan' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan - $_" }

# Action 110: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName 'Windows Defender Verification' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \Microsoft\Windows\Windows Defender\Windows Defender Verification - $_" }

# Action 111: !registryKey
Remove-RegKey 'HKLM\SOFTWARE\Classes\*\ShellEx\ContextMenuHandlers\EPP'

# Action 112: !registryKey
Remove-RegKey 'HKLM\SOFTWARE\Classes\Drive\ShellEx\ContextMenuHandlers\EPP'

# Action 113: !registryKey
Remove-RegKey 'HKLM\SOFTWARE\Classes\Directory\ShellEx\ContextMenuHandlers\EPP'

# Action 114: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"Windows-Defender-Default-Definitions" /NoRestart'

# Action 115: !status
Write-Status 'Disabling UAC'

# Action 116: !service
try { Set-Service -Name 'luafv' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service luafv: $_" }

# Action 117: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA' 'REG_DWORD' '0'

# Action 118: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'PromptOnSecureDesktop' 'REG_DWORD' '0'

# Action 119: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin' 'REG_DWORD' '0'

# Action 120: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ValidateAdminCodeSignatures' 'REG_DWORD' '0'

# Action 121: !registryKey
try { $p=Convert-RegPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband - $_" }

# Action 122: !status
Write-Status 'Installing VC Redist 2005'

# Action 123: !download
try { $dest=Resolve-Env '%temp%\2005_86.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2005_86.exe - $_" }

# Action 124: !download
try { $dest=Resolve-Env '%temp%\2005_64.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.EXE' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2005_64.exe - $_" }

# Action 125: !cmd
Invoke-Cmd '"%temp%\2005_86.exe" /Q /C /T:%temp%\2005_86'

# Action 126: !cmd
Invoke-Cmd '"%temp%\2005_64.exe" /Q /C /T:%temp%\2005_64'

# Action 127: !cmd
Invoke-Cmd '"%temp%\2005_86\vcredist.msi" /quiet /norestart'

# Action 128: !cmd
Invoke-Cmd '"%temp%\2005_64\vcredist.msi" /quiet /norestart'

# Action 129: !file
try { $p=Resolve-Env '%temp%\2005_86'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %temp%\2005_86 - $_" }

# Action 130: !file
try { $p=Resolve-Env '%temp%\2005_64'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %temp%\2005_64 - $_" }

# Action 131: !status
Write-Status 'Installing VC Redist 2008'

# Action 132: !download
try { $dest=Resolve-Env '%temp%\2008_86.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2008_86.exe - $_" }

# Action 133: !download
try { $dest=Resolve-Env '%temp%\2008_64.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2008_64.exe - $_" }

# Action 134: !cmd
Invoke-Cmd '"%temp%\2008_86.exe" /q'

# Action 135: !cmd
Invoke-Cmd '"%temp%\2008_64.exe" /q'

# Action 136: !status
Write-Status 'Installing VC Redist 2010'

# Action 137: !download
try { $dest=Resolve-Env '%temp%\2010_86.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2010_86.exe - $_" }

# Action 138: !download
try { $dest=Resolve-Env '%temp%\2010_64.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2010_64.exe - $_" }

# Action 139: !cmd
Invoke-Cmd '"%temp%/2010_86.exe" /q'

# Action 140: !cmd
Invoke-Cmd '"%temp%/2010_64.exe" /q'

# Action 141: !status
Write-Status 'Installing VC Redist 2012'

# Action 142: !download
try { $dest=Resolve-Env '%temp%\2012_86.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2012_86.exe - $_" }

# Action 143: !download
try { $dest=Resolve-Env '%temp%\2012_64.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2012_64.exe - $_" }

# Action 144: !cmd
Invoke-Cmd '"%temp%\2012_86.exe" /install /quiet /norestart'

# Action 145: !cmd
Invoke-Cmd '"%temp%\2012_64.exe" /install /quiet /norestart'

# Action 146: !status
Write-Status 'Installing VC Redist 2013'

# Action 147: !download
try { $dest=Resolve-Env '%temp%\2013_86.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://aka.ms/highdpimfc2013x86enu' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2013_86.exe - $_" }

# Action 148: !download
try { $dest=Resolve-Env '%temp%\2013_64.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://aka.ms/highdpimfc2013x64enu' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2013_64.exe - $_" }

# Action 149: !cmd
Invoke-Cmd '"%temp%\2013_86.exe" /install /quiet /norestart'

# Action 150: !cmd
Invoke-Cmd '"%temp%\2013_64.exe" /install /quiet /norestart'

# Action 151: !status
Write-Status 'Installing VC Redist 2015-2026'

# Action 152: !download
try { $dest=Resolve-Env '%temp%\2015_2026_86.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://aka.ms/vc14/vc_redist.x86.exe' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2015_2026_86.exe - $_" }

# Action 153: !download
try { $dest=Resolve-Env '%temp%\2015_2026_64.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://aka.ms/vc14/vc_redist.x64.exe' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\2015_2026_64.exe - $_" }

# Action 154: !cmd
Invoke-Cmd '"%temp%\2015_2026_86.exe" /install /quiet /norestart'

# Action 155: !cmd
Invoke-Cmd '"%temp%\2015_2026_64.exe" /install /quiet /norestart'

# Action 156: !status
Write-Status 'Installing DirectX'

# Action 157: !download
try { $dest=Resolve-Env '%temp%\DirectX.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\DirectX.exe - $_" }

# Action 158: !cmd
Invoke-Cmd '"%temp%\DirectX.exe" /Q /C /T:%temp%\DirectX'

# Action 159: !cmd
Invoke-Cmd '"%temp%\DirectX\DXSETUP.exe" /silent'

# Action 160: !file
try { $p=Resolve-Env '%temp%\DirectX'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %temp%\DirectX - $_" }

# Action 161: !status
Write-Status 'Installing 7Zip'

# Action 162: !download
try { $rel=Invoke-RestMethod -Uri 'https://api.github.com/repos/ip7z/7zip/releases/latest' -Headers @{"User-Agent"="PowerShell"}; $asset=$rel.assets | Where-Object { $_.name -match '^7z.*-x64\.exe$' } | Select-Object -First 1; if ($asset) { $dest=Resolve-Env '%temp%\7Zip.exe'; Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -UseBasicParsing } else { Write-Warning "No matching release asset for ip7z/7zip" } } catch { Write-Warning "GitHub release download failed: $_" }

# Action 163: !cmd
Invoke-Cmd '"%temp%\7Zip.exe" /S'

# Action 164: !status
Write-Status 'Configuring 7-Zip'

# Action 165: !registryValue
Set-Reg 'HKCU\Software\7-Zip\FM\Columns' 'RootFolder' 'REG_BINARY' '0100000000000000010000000400000001000000a0000000'

# Action 166: !registryValue
Set-Reg 'HKCU\Software\7-Zip\Options' 'ContextMenu' 'REG_DWORD' '4903'

# Action 167: !registryValue
Set-Reg 'HKCU\Software\7-Zip\Options' 'ElimDupExtract' 'REG_DWORD' '0'

# Action 168: !registryValue
Set-Reg 'HKCU\Software\Classes\.001' '' 'REG_SZ' '7-Zip.001'

# Action 169: !registryValue
Set-Reg 'HKCU\Software\Classes\.7z' '' 'REG_SZ' '7-Zip.7z'

# Action 170: !registryValue
Set-Reg 'HKCU\Software\Classes\.arj' '' 'REG_SZ' '7-Zip.arj'

# Action 171: !registryValue
Set-Reg 'HKCU\Software\Classes\.bz2' '' 'REG_SZ' '7-Zip.bz2'

# Action 172: !registryValue
Set-Reg 'HKCU\Software\Classes\.bzip2' '' 'REG_SZ' '7-Zip.bzip2'

# Action 173: !registryValue
Set-Reg 'HKCU\Software\Classes\.cab' '' 'REG_SZ' '7-Zip.cab'

# Action 174: !registryValue
Set-Reg 'HKCU\Software\Classes\.cpio' '' 'REG_SZ' '7-Zip.cpio'

# Action 175: !registryValue
Set-Reg 'HKCU\Software\Classes\.deb' '' 'REG_SZ' '7-Zip.deb'

# Action 176: !registryValue
Set-Reg 'HKCU\Software\Classes\.dmg' '' 'REG_SZ' '7-Zip.dmg'

# Action 177: !registryValue
Set-Reg 'HKCU\Software\Classes\.fat' '' 'REG_SZ' '7-Zip.fat'

# Action 178: !registryValue
Set-Reg 'HKCU\Software\Classes\.gz' '' 'REG_SZ' '7-Zip.gz'

# Action 179: !registryValue
Set-Reg 'HKCU\Software\Classes\.gzip' '' 'REG_SZ' '7-Zip.gzip'

# Action 180: !registryValue
Set-Reg 'HKCU\Software\Classes\.hfs' '' 'REG_SZ' '7-Zip.hfs'

# Action 181: !registryValue
Set-Reg 'HKCU\Software\Classes\.iso' '' 'REG_SZ' '7-Zip.iso'

# Action 182: !registryValue
Set-Reg 'HKCU\Software\Classes\.lha' '' 'REG_SZ' '7-Zip.lha'

# Action 183: !registryValue
Set-Reg 'HKCU\Software\Classes\.lzh' '' 'REG_SZ' '7-Zip.lzh'

# Action 184: !registryValue
Set-Reg 'HKCU\Software\Classes\.lzma' '' 'REG_SZ' '7-Zip.lzma'

# Action 185: !registryValue
Set-Reg 'HKCU\Software\Classes\.ntfs' '' 'REG_SZ' '7-Zip.ntfs'

# Action 186: !registryValue
Set-Reg 'HKCU\Software\Classes\.rar' '' 'REG_SZ' '7-Zip.rar'

# Action 187: !registryValue
Set-Reg 'HKCU\Software\Classes\.rpm' '' 'REG_SZ' '7-Zip.rpm'

# Action 188: !registryValue
Set-Reg 'HKCU\Software\Classes\.squashfs' '' 'REG_SZ' '7-Zip.squashfs'

# Action 189: !registryValue
Set-Reg 'HKCU\Software\Classes\.swm' '' 'REG_SZ' '7-Zip.swm'

# Action 190: !registryValue
Set-Reg 'HKCU\Software\Classes\.tar' '' 'REG_SZ' '7-Zip.tar'

# Action 191: !registryValue
Set-Reg 'HKCU\Software\Classes\.taz' '' 'REG_SZ' '7-Zip.taz'

# Action 192: !registryValue
Set-Reg 'HKCU\Software\Classes\.tbz' '' 'REG_SZ' '7-Zip.tbz'

# Action 193: !registryValue
Set-Reg 'HKCU\Software\Classes\.tbz2' '' 'REG_SZ' '7-Zip.tbz2'

# Action 194: !registryValue
Set-Reg 'HKCU\Software\Classes\.tgz' '' 'REG_SZ' '7-Zip.tgz'

# Action 195: !registryValue
Set-Reg 'HKCU\Software\Classes\.tpz' '' 'REG_SZ' '7-Zip.tpz'

# Action 196: !registryValue
Set-Reg 'HKCU\Software\Classes\.txz' '' 'REG_SZ' '7-Zip.txz'

# Action 197: !registryValue
Set-Reg 'HKCU\Software\Classes\.vhd' '' 'REG_SZ' '7-Zip.vhd'

# Action 198: !registryValue
Set-Reg 'HKCU\Software\Classes\.wim' '' 'REG_SZ' '7-Zip.wim'

# Action 199: !registryValue
Set-Reg 'HKCU\Software\Classes\.xar' '' 'REG_SZ' '7-Zip.xar'

# Action 200: !registryValue
Set-Reg 'HKCU\Software\Classes\.xz' '' 'REG_SZ' '7-Zip.xz'

# Action 201: !registryValue
Set-Reg 'HKCU\Software\Classes\.z' '' 'REG_SZ' '7-Zip.z'

# Action 202: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.001' '' 'REG_SZ' '001 Archive'

# Action 203: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.001\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,9'

# Action 204: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.001\shell' '' 'REG_SZ' ''

# Action 205: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.001\shell\open' '' 'REG_SZ' ''

# Action 206: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.001\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 207: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.7z' '' 'REG_SZ' '7z Archive'

# Action 208: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.7z\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,0'

# Action 209: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.7z\shell' '' 'REG_SZ' ''

# Action 210: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.7z\shell\open' '' 'REG_SZ' ''

# Action 211: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.7z\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 212: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.arj' '' 'REG_SZ' 'arj Archive'

# Action 213: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.arj\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,4'

# Action 214: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.arj\shell' '' 'REG_SZ' ''

# Action 215: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.arj\shell\open' '' 'REG_SZ' ''

# Action 216: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.arj\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 217: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bz2' '' 'REG_SZ' 'bz2 Archive'

# Action 218: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bz2\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,2'

# Action 219: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bz2\shell' '' 'REG_SZ' ''

# Action 220: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bz2\shell\open' '' 'REG_SZ' ''

# Action 221: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bz2\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 222: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bzip2' '' 'REG_SZ' 'bzip2 Archive'

# Action 223: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bzip2\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,2'

# Action 224: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bzip2\shell' '' 'REG_SZ' ''

# Action 225: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bzip2\shell\open' '' 'REG_SZ' ''

# Action 226: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.bzip2\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 227: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cab' '' 'REG_SZ' 'cab Archive'

# Action 228: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cab\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,7'

# Action 229: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cab\shell' '' 'REG_SZ' ''

# Action 230: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cab\shell\open' '' 'REG_SZ' ''

# Action 231: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cab\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 232: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cpio' '' 'REG_SZ' 'cpio Archive'

# Action 233: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cpio\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,12'

# Action 234: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cpio\shell' '' 'REG_SZ' ''

# Action 235: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cpio\shell\open' '' 'REG_SZ' ''

# Action 236: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.cpio\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 237: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.deb' '' 'REG_SZ' 'deb Archive'

# Action 238: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.deb\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,11'

# Action 239: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.deb\shell' '' 'REG_SZ' ''

# Action 240: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.deb\shell\open' '' 'REG_SZ' ''

# Action 241: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.deb\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 242: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.dmg' '' 'REG_SZ' 'dmg Archive'

# Action 243: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.dmg\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,17'

# Action 244: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.dmg\shell' '' 'REG_SZ' ''

# Action 245: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.dmg\shell\open' '' 'REG_SZ' ''

# Action 246: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.dmg\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 247: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.fat' '' 'REG_SZ' 'fat Archive'

# Action 248: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.fat\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,21'

# Action 249: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.fat\shell' '' 'REG_SZ' ''

# Action 250: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.fat\shell\open' '' 'REG_SZ' ''

# Action 251: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.fat\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 252: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gz' '' 'REG_SZ' 'gz Archive'

# Action 253: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gz\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,14'

# Action 254: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gz\shell' '' 'REG_SZ' ''

# Action 255: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gz\shell\open' '' 'REG_SZ' ''

# Action 256: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gz\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 257: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gzip' '' 'REG_SZ' 'gzip Archive'

# Action 258: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gzip\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,14'

# Action 259: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gzip\shell' '' 'REG_SZ' ''

# Action 260: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gzip\shell\open' '' 'REG_SZ' ''

# Action 261: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.gzip\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 262: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.hfs' '' 'REG_SZ' 'hfs Archive'

# Action 263: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.hfs\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,18'

# Action 264: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.hfs\shell' '' 'REG_SZ' ''

# Action 265: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.hfs\shell\open' '' 'REG_SZ' ''

# Action 266: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.hfs\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 267: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.iso' '' 'REG_SZ' 'iso Archive'

# Action 268: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.iso\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,8'

# Action 269: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.iso\shell' '' 'REG_SZ' ''

# Action 270: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.iso\shell\open' '' 'REG_SZ' ''

# Action 271: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.iso\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 272: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lha' '' 'REG_SZ' 'lha Archive'

# Action 273: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lha\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,6'

# Action 274: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lha\shell' '' 'REG_SZ' ''

# Action 275: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lha\shell\open' '' 'REG_SZ' ''

# Action 276: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lha\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 277: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzh' '' 'REG_SZ' 'lzh Archive'

# Action 278: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzh\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,6'

# Action 279: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzh\shell' '' 'REG_SZ' ''

# Action 280: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzh\shell\open' '' 'REG_SZ' ''

# Action 281: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzh\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 282: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzma' '' 'REG_SZ' 'lzma Archive'

# Action 283: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzma\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,16'

# Action 284: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzma\shell' '' 'REG_SZ' ''

# Action 285: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzma\shell\open' '' 'REG_SZ' ''

# Action 286: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.lzma\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 287: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.ntfs' '' 'REG_SZ' 'ntfs Archive'

# Action 288: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.ntfs\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,22'

# Action 289: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.ntfs\shell' '' 'REG_SZ' ''

# Action 290: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.ntfs\shell\open' '' 'REG_SZ' ''

# Action 291: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.ntfs\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 292: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rar' '' 'REG_SZ' 'rar Archive'

# Action 293: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rar\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,3'

# Action 294: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rar\shell' '' 'REG_SZ' ''

# Action 295: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rar\shell\open' '' 'REG_SZ' ''

# Action 296: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rar\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 297: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rpm' '' 'REG_SZ' 'rpm Archive'

# Action 298: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rpm\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,10'

# Action 299: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rpm\shell' '' 'REG_SZ' ''

# Action 300: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rpm\shell\open' '' 'REG_SZ' ''

# Action 301: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.rpm\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 302: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.squashfs' '' 'REG_SZ' 'squashfs Archive'

# Action 303: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.squashfs\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,24'

# Action 304: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.squashfs\shell' '' 'REG_SZ' ''

# Action 305: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.squashfs\shell\open' '' 'REG_SZ' ''

# Action 306: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.squashfs\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 307: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.swm' '' 'REG_SZ' 'swm Archive'

# Action 308: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.swm\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,15'

# Action 309: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.swm\shell' '' 'REG_SZ' ''

# Action 310: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.swm\shell\open' '' 'REG_SZ' ''

# Action 311: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.swm\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 312: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tar' '' 'REG_SZ' 'tar Archive'

# Action 313: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tar\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,13'

# Action 314: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tar\shell' '' 'REG_SZ' ''

# Action 315: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tar\shell\open' '' 'REG_SZ' ''

# Action 316: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tar\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 317: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.taz' '' 'REG_SZ' 'taz Archive'

# Action 318: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.taz\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,5'

# Action 319: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.taz\shell' '' 'REG_SZ' ''

# Action 320: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.taz\shell\open' '' 'REG_SZ' ''

# Action 321: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.taz\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 322: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz' '' 'REG_SZ' 'tbz Archive'

# Action 323: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz2' '' 'REG_SZ' 'tbz2 Archive'

# Action 324: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz2\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,2'

# Action 325: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz2\shell' '' 'REG_SZ' ''

# Action 326: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz2\shell\open' '' 'REG_SZ' ''

# Action 327: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz2\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 328: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,2'

# Action 329: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz\shell' '' 'REG_SZ' ''

# Action 330: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz\shell\open' '' 'REG_SZ' ''

# Action 331: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tbz\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 332: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tgz' '' 'REG_SZ' 'tgz Archive'

# Action 333: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tgz\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,14'

# Action 334: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tgz\shell' '' 'REG_SZ' ''

# Action 335: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tgz\shell\open' '' 'REG_SZ' ''

# Action 336: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tgz\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 337: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tpz' '' 'REG_SZ' 'tpz Archive'

# Action 338: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tpz\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,14'

# Action 339: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tpz\shell' '' 'REG_SZ' ''

# Action 340: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tpz\shell\open' '' 'REG_SZ' ''

# Action 341: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.tpz\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 342: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.txz' '' 'REG_SZ' 'txz Archive'

# Action 343: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.txz\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,23'

# Action 344: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.txz\shell' '' 'REG_SZ' ''

# Action 345: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.txz\shell\open' '' 'REG_SZ' ''

# Action 346: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.txz\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 347: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.vhd' '' 'REG_SZ' 'vhd Archive'

# Action 348: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.vhd\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,20'

# Action 349: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.vhd\shell' '' 'REG_SZ' ''

# Action 350: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.vhd\shell\open' '' 'REG_SZ' ''

# Action 351: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.vhd\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 352: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.wim' '' 'REG_SZ' 'wim Archive'

# Action 353: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.wim\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,15'

# Action 354: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.wim\shell' '' 'REG_SZ' ''

# Action 355: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.wim\shell\open' '' 'REG_SZ' ''

# Action 356: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.wim\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 357: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xar' '' 'REG_SZ' 'xar Archive'

# Action 358: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xar\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,19'

# Action 359: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xar\shell' '' 'REG_SZ' ''

# Action 360: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xar\shell\open' '' 'REG_SZ' ''

# Action 361: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xar\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 362: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xz' '' 'REG_SZ' 'xz Archive'

# Action 363: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xz\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,23'

# Action 364: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xz\shell' '' 'REG_SZ' ''

# Action 365: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xz\shell\open' '' 'REG_SZ' ''

# Action 366: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.xz\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 367: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.z' '' 'REG_SZ' 'z Archive'

# Action 368: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.z\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,5'

# Action 369: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.z\shell' '' 'REG_SZ' ''

# Action 370: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.z\shell\open' '' 'REG_SZ' ''

# Action 371: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.z\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 372: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.zip' '' 'REG_SZ' 'zip Archive'

# Action 373: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.zip\DefaultIcon' '' 'REG_SZ' 'C:\Program Files\7-Zip\7z.dll,1'

# Action 374: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.zip\shell' '' 'REG_SZ' ''

# Action 375: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.zip\shell\open' '' 'REG_SZ' ''

# Action 376: !registryValue
Set-Reg 'HKCU\Software\Classes\7-Zip.zip\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 377: !registryValue
Set-Reg 'HKCR\Applications\7zFM.exe\shell\open\command' '' 'REG_SZ' '"C:\Program Files\7-Zip\7zFM.exe" "%1"'

# Action 378: !registryValue
Set-Reg 'HKCR\*\OpenWithList\7zFM.exe' '' 'REG_SZ' ''

# Action 379: !status
Write-Status 'Installing OpenShell'

# Action 380: !download
try { $rel=Invoke-RestMethod -Uri 'https://api.github.com/repos/Open-Shell/Open-Shell-Menu/releases/latest' -Headers @{"User-Agent"="PowerShell"}; $asset=$rel.assets | Where-Object { $_.name -match '^OpenShellSetup.*\.exe$' } | Select-Object -First 1; if ($asset) { $dest=Resolve-Env '%temp%\OpenShellSetup.exe'; Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -UseBasicParsing } else { Write-Warning "No matching release asset for Open-Shell/Open-Shell-Menu" } } catch { Write-Warning "GitHub release download failed: $_" }

# Action 381: !cmd
Invoke-Cmd '"%temp%\OpenShellSetup.exe" /qn ADDLOCAL=StartMenu'

# Action 382: !status
Write-Status 'Configuring Open-Shell'

# Action 383: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Immersive.skin'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Immersive.skin - $_" }

# Action 384: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Immersive.skin7'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Immersive.skin7 - $_" }

# Action 385: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Classic Skin.skin'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Classic Skin.skin - $_" }

# Action 386: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Classic Skin.skin7'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Classic Skin.skin7 - $_" }

# Action 387: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Full Glass.skin'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Full Glass.skin - $_" }

# Action 388: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Metallic.skin7'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Metallic.skin7 - $_" }

# Action 389: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Metro.skin'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Metro.skin - $_" }

# Action 390: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Metro.skin7'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Metro.skin7 - $_" }

# Action 391: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Midnight.skin7'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Midnight.skin7 - $_" }

# Action 392: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Smoked Glass.skin'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Smoked Glass.skin - $_" }

# Action 393: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Windows 8.skin'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Windows 8.skin - $_" }

# Action 394: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Windows 8.skin7'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Windows 8.skin7 - $_" }

# Action 395: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Windows Aero.skin'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Windows Aero.skin - $_" }

# Action 396: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Windows Aero.skin7'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Windows Aero.skin7 - $_" }

# Action 397: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Windows Basic.skin'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Windows Basic.skin - $_" }

# Action 398: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Skins\Windows XP Luna.skin'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Skins\Windows XP Luna.skin - $_" }

# Action 399: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\start screen.lnk'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\start screen.lnk - $_" }

# Action 400: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\OpenShell.chm'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\OpenShell.chm - $_" }

# Action 401: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\OpenShellReadme.rtf'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\OpenShellReadme.rtf - $_" }

# Action 402: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\PolicyDefinitions.zip'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\PolicyDefinitions.zip - $_" }

# Action 403: !file
try { $p=Resolve-Env '%ProgramFiles%\Open-Shell\Start Menu Settings.lnk'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles%\Open-Shell\Start Menu Settings.lnk - $_" }

# Action 404: !registryValue
Set-Reg 'HKCU\Software\OpenShell\ClassicExplorer' 'ShowedToolbar' 'REG_DWORD' '1'

# Action 405: !registryValue
Set-Reg 'HKCU\Software\OpenShell\ClassicExplorer' 'NewLine' 'REG_DWORD' '0'

# Action 406: !registryValue
Set-Reg 'HKCU\Software\OpenShell\OpenShell' 'LastUpdateTime' 'REG_DWORD' '371152301'

# Action 407: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu' 'ShowedStyle2' 'REG_DWORD' '1'

# Action 408: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu' 'CSettingsDlg' 'REG_BINARY' '36010000b50000000000000003000000aa0f00000000000000000000'

# Action 409: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu' 'OldItems' 'REG_BINARY' ''

# Action 410: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu' 'ItemRanks' 'REG_BINARY' '48534c430100000000000000ca72d704030000005078da013914000801000000d43fda014698a10b03000000bb43da01239e440d030000005b4dda0120f1440d0500000005b2da0142a9d20f010000006088da01af0a0d12160000006883da0112ae8a14010000006088da01d400a21401000000694dda0104c7ea1901000000a873da01a67ffb24010000004e6eda0190a363268000000008b2da018479722f020000005f4dda017f4fef2f7000000029b2da01aa307130010000000c88da01b0f1c83001000000c53cda0144cbd031140000005988da01b9f88134010000003846da012fb04239010000002243da010dd8bb3902000000b943da01278e673e020000001240da018c8ceb41040000007f82da012fec3c4501000000ca3fda01deeea04f080000003784da0115026a5003000000c47ada0144bc4657040000007288da019495135a02000000ff47da012fd3e15c0100000005b2da014e80c85e0700000003b2da01a8e9ed6105000000254dda01870dd463010000006088da0107fc1e64010000009548da01742e256507000000b486da01b6f3536601000000df85da018649d66b0b0000000fb2da01ae1b3a6d05000000474dda014cb9666d01000000963dda01fbe16c7601000000b843da012ca5637e270000000888da01fcbcd58114000000dc84da0120781785010000008e46da013304d18cc20000001b88da014896368f09000000ec7ada0166c9c89801000000207ada018467939ba2000000634dda01cd86fda101000000c14cda01e66883a20a0000004088da01f91b8ea76b00000006b2da01e7280fab0200000003b2da01615513b201000000b147da0141c467b5010000002e4dda016b9b76ba01000000bd7ada016e3439bb110000000088da011d87e5c1200000005488da011de6efc5010000001a72da01c9a4aecc080000003f47da01ab1c7dd101000000b943da010d3e7edd01000000604dda019bab6ee00d0000007188da01772cbae5040000000888da01a51b64ea010000008f44da01b262d1ec030000001b88da01e56985ee02000000ff47da01be2d91f10f0000004c7dda01060aacf1020000003747da01d0a7a8f301000000e285da011f76d4f9010000000c88da01'

# Action 411: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu' 'CEditMenuDlg7' 'REG_BINARY' 'fc010000f50100000000000000000000'

# Action 412: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'SkinOptionsW7' 'REG_MULTI_SZ' 'DARK_MAIN=0\0METRO_MAIN=0\0LIGHT_MAIN=0\0AUTOMODE_MAIN=0\0CUSTOM_MAIN=000000\0DARK_SUBMENU=0\0METRO_SUBMENU=0\0LIGHT_SUBMENU=0\0AUTOMODE_SUBMENU=1\0SUBMENU_SEPARATORS=1\0DARK_SEARCH=0\0METRO_SEARCH=0\0LIGHT_SEARCH=0\0AUTOMODE_SEARCH=1\0SEARCH_FRAME=1\0SEARCH_COLOR=1\0SMALL_SEARCH=1\0MODERN_SEARCH=1\0SEARCH_HINT=1\0SEARCH_ITALICS=0\0NONE=1\0SEPARATOR=0\0TWO_TONE=0\0CLASSIC_SELECTOR=1\0HALF_SELECTOR=0\0CURVED_MENUSEL=1\0CURVED_SUBMENU=0\0SELECTOR_REVEAL=0\0TRANSPARENT=0\0OPAQUE_SUBMENU=0\0OPAQUE_MENU=0\0OPAQUE=1\0STANDARD=0\0SMALL_MAIN2=1\0SMALL_ICONS=0\0COMPACT_SUBMENU=1\0PRESERVE_MAIN2=0\0LESS_PADDING=1\0EXTRA_PADDING=0\024_PADDING=1\0LARGE_PROGRAMS=0\0TRANSPARENT_SHUTDOWN=0\0OUTLINE_SHUTDOWN=1\0BUTTON_SHUTDOWN=0\0EXPERIMENTAL_SHUTDOWN=0\0LARGE_FONT=0\0CONNECTED_BORDER=0\0FLOATING_BORDER=1\0LARGE_SUBMENU=0\0LARGE_LISTS=0\0THIN_MAIN2=1\0EXPERIMENTAL_MAIN2=1\0USER_IMAGE=1\0USER_OUTSIDE=0\0SCALING_USER=0\056=0\064=1\0TRANSPARENT_USER=0\0UWP_SCROLLBAR=0\0MODERN_SCROLLBAR=1\0OLD_ICONS=0\0NEW_ICONS=1\0SMALL_ARROWS=1\0ICON_FRAME=0\0SEARCH_SEPARATOR=0\0NO_PROGRAMS_BUTTON=0'

# Action 413: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'MenuItems7' 'REG_MULTI_SZ' 'Item1.Command=user_files\0Item1.Settings=NOEXPAND\0Item2.Command=separator\0Item3.Command=user_documents\0Item3.Settings=NOEXPAND\0Item4.Command=user_pictures\0Item4.Settings=ITEM_DISABLED\0Item5.Command=user_music\0Item5.Settings=ITEM_DISABLED\0Item6.Command=user_videos\0Item6.Settings=NOEXPAND\0Item7.Command=downloads\0Item7.Settings=NOEXPAND\0Item8.Command=homegroup\0Item8.Settings=ITEM_DISABLED\0Item9.Command=games\0Item9.Settings=TRACK_RECENT|NOEXPAND|ITEM_DISABLED\0Item10.Command=favorites\0Item10.Settings=ITEM_DISABLED\0Item11.Command=recent_documents\0Item11.Settings=ITEM_DISABLED\0Item12.Command=computer\0Item12.Settings=NOEXPAND\0Item13.Command=network\0Item13.Settings=ITEM_DISABLED\0Item14.Command=network_connections\0Item14.Settings=ITEM_DISABLED\0Item15.Command=separator\0Item16.Command=pc_settings\0Item16.Settings=TRACK_RECENT\0Item17.Command=control_panel\0Item17.Settings=TRACK_RECENT|NOEXPAND\0Item18.Command=admin\0Item18.Settings=TRACK_RECENT|NOEXPAND\0Item19.Command=devices\0Item19.Settings=ITEM_DISABLED\0Item20.Command=defaults\0Item20.Settings=ITEM_DISABLED\0Item21.Command=help\0Item21.Settings=ITEM_DISABLED\0Item22.Command=run\0Item23.Command=apps\0Item23.Settings=ITEM_DISABLED\0Item24.Command=windows_security\0Item24.Settings=ITEM_DISABLED'

# Action 414: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'Version' 'REG_DWORD' '67371198'

# Action 415: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'SkipMetro' 'REG_DWORD' '1'

# Action 416: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'StartScreenShortcut' 'REG_DWORD' '0'

# Action 417: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'SkinW7' 'REG_SZ' 'fluent-metro'

# Action 418: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'SkinVariationW7' 'REG_SZ' ''

# Action 419: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'MenuStyle' 'REG_SZ' 'Win7'

# Action 420: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'PinnedPrograms' 'REG_SZ' 'PinnedItems'

# Action 421: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'ShiftClick' 'REG_SZ' 'ClassicMenu'

# Action 422: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'ShiftWin' 'REG_SZ' 'ClassicMenu'

# Action 423: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'ShiftRight' 'REG_DWORD' '1'

# Action 424: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'ControlPanelCategories' 'REG_DWORD' '1'

# Action 425: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'OpenPrograms' 'REG_DWORD' '0'

# Action 426: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'RecentPrograms' 'REG_SZ' 'None'

# Action 427: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'EnableJumplists' 'REG_DWORD' '0'

# Action 428: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'HighlightNew' 'REG_DWORD' '0'

# Action 429: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'EnableAccessibility' 'REG_DWORD' '0'

# Action 430: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'EnableContextMenu' 'REG_DWORD' '1'

# Action 431: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'EnableExit' 'REG_DWORD' '0'

# Action 432: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'FontSmoothing' 'REG_SZ' 'Default'

# Action 433: !registryValue
Set-Reg 'HKCU\Software\OpenShell\StartMenu\Settings' 'MinMainHeight' 'REG_DWORD' '24'

# Action 434: !taskKill
try { Stop-Process -Name 'StartMenuExperienceHost.exe' -Force -ErrorAction SilentlyContinue } catch {}

# Action 435: !taskKill
try { Stop-Process -Name 'searchapp.exe' -Force -ErrorAction SilentlyContinue } catch {}

# Action 436: !taskKill
try { Stop-Process -Name 'SearchHost.exe' -Force -ErrorAction SilentlyContinue } catch {}

# Action 437: !status
Write-Status 'Installing Firefox Dev'

# Action 438: !download
try { $dest=Resolve-Env '%temp%\FirefoxDev.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.mozilla.org/?product=firefox-devedition-latest-ssl&os=win64&lang=en-US' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\FirefoxDev.exe - $_" }

# Action 439: !cmd
Invoke-Cmd '"%temp%\FirefoxDev.exe" /S'

# Action 440: !status
Write-Status 'Installing Firefox'

# Action 441: !download
try { $dest=Resolve-Env '%temp%\Firefox.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\Firefox.exe - $_" }

# Action 442: !cmd
Invoke-Cmd '"%temp%\Firefox.exe" /S'

# Action 443: !status
Write-Status 'Installing Chrome'

# Action 444: !download
try { $dest=Resolve-Env '%temp%\Chrome.msi'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\Chrome.msi - $_" }

# Action 445: !cmd
Invoke-Cmd '"%temp%\Chrome.msi" /quiet /norestart'

# Action 446: !status
Write-Status 'Installing Brave'

# Action 447: !download
try { $dest=Resolve-Env '%temp%\Brave.exe'; $parent=Split-Path -Parent $dest; if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; Invoke-WebRequest -Uri 'https://laptop-updates.brave.com/latest/winx64' -OutFile $dest -UseBasicParsing -ErrorAction Stop } catch { Write-Warning "Download failed: %temp%\Brave.exe - $_" }

# Action 448: !cmd
Invoke-Cmd '"%temp%\Brave.exe" /silent /install'

# Action 449: !status
Write-Status 'Installing Mercury'

# Action 450: !download
try { $rel=Invoke-RestMethod -Uri 'https://api.github.com/repos/Alex313031/Mercury/releases/latest' -Headers @{"User-Agent"="PowerShell"}; $asset=$rel.assets | Where-Object { $_.name -match '^mercury.*win64.*AVX2.*.exe$' } | Select-Object -First 1; if ($asset) { $dest=Resolve-Env '%temp%\Mercury.exe'; Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -UseBasicParsing } else { Write-Warning "No matching release asset for Alex313031/Mercury" } } catch { Write-Warning "GitHub release download failed: $_" }

# Action 451: !cmd
Invoke-Cmd '"%temp%\Mercury.exe" /S'

# Action 452: !status
Write-Status 'Installing Helium'

# Action 453: !download
try { $rel=Invoke-RestMethod -Uri 'https://api.github.com/repos/imputnet/helium-windows/releases/latest' -Headers @{"User-Agent"="PowerShell"}; $asset=$rel.assets | Where-Object { $_.name -match '^helium_.*_x64-mini-installer\.exe$' } | Select-Object -First 1; if ($asset) { $dest=Resolve-Env '%temp%\Helium.exe'; Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -UseBasicParsing } else { Write-Warning "No matching release asset for imputnet/helium-windows" } } catch { Write-Warning "GitHub release download failed: $_" }

# Action 454: !cmd
Invoke-Cmd '"%temp%\Helium.exe" --silent --system-level --do-not-launch-chrome'

# Action 455: !powerShell
$__cmd = @'
$taskbar="""$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"""; rm """$taskbar\*""" -Force -EA 0; $wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut("""$taskbar\File Explorer.lnk"""); $lnk.TargetPath="""$env:systemroot\explorer.exe"""; $lnk.Save()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 456: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'FavoritesResolve' 'REG_BINARY' '340300004C0000000114020000000000C0000000000000468300800020000000202D5EE1C398DC01A59361E1C398DC0125B37A4D0584DA01970100000000000001000000000000000000000000000000A0013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B00420061007200000016000E013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C0000009D0000001C000000010000001C0000002D000000000000009C0000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46696C65204578706C6F7265722E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000'

# Action 457: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'Favorites' 'REG_BINARY' '00A40100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B004200610072000000160012013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C00260000001E00EFBE0200530079007300740065006D00500069006E006E006500640000001C000000FF'

# Action 458: !powerShell
$__cmd = @'
$taskbar="""$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"""; rm """$taskbar\*""" -Force -EA 0; $wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut("""$taskbar\File Explorer.lnk"""); $lnk.TargetPath="""$env:systemroot\explorer.exe"""; $lnk.Save(); $lnk=$wsh.CreateShortcut("""$taskbar\Firefox.lnk"""); $lnk.TargetPath="""$env:ProgramFiles\Mozilla Firefox\firefox.exe"""; $lnk.Save()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 459: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'FavoritesResolve' 'REG_BINARY' '340300004C0000000114020000000000C0000000000000468300800020000000202D5EE1C398DC01A59361E1C398DC0125B37A4D0584DA01970100000000000001000000000000000000000000000000A0013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B00420061007200000016000E013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C0000009D0000001C000000010000001C0000002D000000000000009C0000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46696C65204578706C6F7265722E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000E40200004C0000000114020000000000C000000000000046830080002000000071355333EAA4DC01A1145433EAA4DC01091D6601E5A4DC0129040000000000000100000000000000000000000000000056013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC0193C55333EAA4DC0114005600310000000000575CE28B11005461736B42617200400009000400EFBE485C5433575CE38B2E000000382A0200000003000000000000000000000000000000242096005400610073006B0042006100720000001600C400320029040000575CC086200046697265666F782E6C6E6B00480009000400EFBE575CE68B575CE68B2E0000008A600200000011000000000000000000000000000000F7E67600460069007200650066006F0078002E006C006E006B0000001A00220000001E00EFBE02005500730065007200500069006E006E006500640000001A00120000002B00EFBEA1145433EAA4DC011A002E0000001D00EFBE0200330030003800300034003600420030004100460034004100330039004300420000001A000000970000001C000000010000001C0000002D00000000000000960000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46697265666F782E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF4E2103EE2011F111B9A9000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF4E2103EE2011F111B9A9000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000'

# Action 460: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'Favorites' 'REG_BINARY' '00A40100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B004200610072000000160012013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C00260000001E00EFBE0200530079007300740065006D00500069006E006E006500640000001C00000000560100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC0193C55333EAA4DC0114005600310000000000575CE28B11005461736B42617200400009000400EFBE485C5433575CE38B2E000000382A0200000003000000000000000000000000000000242096005400610073006B0042006100720000001600C400320029040000575CC086200046697265666F782E6C6E6B00480009000400EFBE575CE68B575CE68B2E0000008A600200000011000000000000000000000000000000F7E67600460069007200650066006F0078002E006C006E006B0000001A00120000002B00EFBEA1145433EAA4DC011A002E0000001D00EFBE0200330030003800300034003600420030004100460034004100330039004300420000001A00220000001E00EFBE02005500730065007200500069006E006E006500640000001A000000FF'

# Action 461: !powerShell
$__cmd = @'
$taskbar="""$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"""; rm """$taskbar\*""" -Force -EA 0; $wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut("""$taskbar\File Explorer.lnk"""); $lnk.TargetPath="""$env:systemroot\explorer.exe"""; $lnk.Save(); $lnk=$wsh.CreateShortcut("""$taskbar\Google Chrome.lnk"""); $lnk.TargetPath="""C:\Program Files\Google\Chrome\Application\chrome.exe"""; $lnk.Save()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 462: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'FavoritesResolve' 'REG_BINARY' '340300004C0000000114020000000000C0000000000000468300800020000000202D5EE1C398DC01A59361E1C398DC0125B37A4D0584DA01970100000000000001000000000000000000000000000000A0013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B00420061007200000016000E013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C0000009D0000001C000000010000001C0000002D000000000000009C0000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46696C65204578706C6F7265722E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000E40200004C0000000114020000000000C000000000000046830080002000000089C33C33E7A4DC0104CF3D33E7A4DC01A6E26763E5A4DC01C7080000000000000100000000000000000000000000000050013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC0198173D33E7A4DC0114005600310000000000575C338911005461736B42617200400009000400EFBE485C5433575C34892E000000382A0200000003000000000000000000000000000000E43856005400610073006B0042006100720000001600BE003200C7080000575C16872000474F4F474C457E312E4C4E4B0000540009000400EFBE575C3589575C35892E000000576C02000000030000000000000000000000000000005A8B350047006F006F0067006C00650020004300680072006F006D0065002E006C006E006B0000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBE4FA43D33E7A4DC011C001A0000001D00EFBE02004300680072006F006D00650000001C0000009D0000001C000000010000001C0000002D000000000000009C0000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C476F6F676C65204368726F6D652E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BFB32003EE2011F111B9A9000C29A6860F1CF46009E731F34AA74C0247DFE2A3BFB32003EE2011F111B9A9000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000'

# Action 463: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'Favorites' 'REG_BINARY' '00A40100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B004200610072000000160012013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C00260000001E00EFBE0200530079007300740065006D00500069006E006E006500640000001C00000000500100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC0198173D33E7A4DC0114005600310000000000575C338911005461736B42617200400009000400EFBE485C5433575C34892E000000382A0200000003000000000000000000000000000000E43856005400610073006B0042006100720000001600BE003200C7080000575C16872000474F4F474C457E312E4C4E4B0000540009000400EFBE575C3589575C35892E000000576C02000000030000000000000000000000000000005A8B350047006F006F0067006C00650020004300680072006F006D0065002E006C006E006B0000001C00120000002B00EFBE4FA43D33E7A4DC011C001A0000001D00EFBE02004300680072006F006D00650000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C000000FF'

# Action 464: !powerShell
$__cmd = @'
$taskbar="""$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"""; rm """$taskbar\*""" -Force -EA 0; $wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut("""$taskbar\File Explorer.lnk"""); $lnk.TargetPath="""$env:systemroot\explorer.exe"""; $lnk.Save(); $lnk=$wsh.CreateShortcut("""$taskbar\Firefox Developer Edition.lnk"""); $lnk.TargetPath="""C:\Program Files\Firefox Developer Edition\firefox.exe"""; $lnk.Save()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 465: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'FavoritesResolve' 'REG_BINARY' '340300004C0000000114020000000000C0000000000000468300800020000000202D5EE1C398DC01A59361E1C398DC0125B37A4D0584DA01970100000000000001000000000000000000000000000000A0013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B00420061007200000016000E013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C0000009D0000001C000000010000001C0000002D000000000000009C0000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46696C65204578706C6F7265722E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F54981230000000000000000000000001C0300004C0000000114020000000000C0000000000000468300800020000000F2129F59EAA4DC0123C59F59EAA4DC014AB9FCD5E4A4DC016F04000000000000010000000000000000000000000000007C013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC018B6E9F59EAA4DC0114005600310000000000575C048C11005461736B42617200400009000400EFBE485C5433575C058C2E000000382A0200000003000000000000000000000000000000D94984005400610073006B0042006100720000001600EA0032006F040000575C9886200046495245464F7E312E4C4E4B00006C0009000400EFBE575C088C575C088C2E000000956C0200000068000000000000000000000000000000B6F6F500460069007200650066006F007800200044006500760065006C006F007000650072002000450064006900740069006F006E002E006C006E006B0000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBE23C59F59EAA4DC011C002E0000001D00EFBE0200430041003900340032003200370031003100410045003100410038003100430000001C000000A90000001C000000010000001C0000002D00000000000000A80000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46697265666F7820446576656C6F7065722045646974696F6E2E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF702103EE2011F111B9A9000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF702103EE2011F111B9A9000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000'

# Action 466: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'Favorites' 'REG_BINARY' '00A40100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B004200610072000000160012013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C00260000001E00EFBE0200530079007300740065006D00500069006E006E006500640000001C000000007C0100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC018B6E9F59EAA4DC0114005600310000000000575C048C11005461736B42617200400009000400EFBE485C5433575C058C2E000000382A0200000003000000000000000000000000000000D94984005400610073006B0042006100720000001600EA0032006F040000575C9886200046495245464F7E312E4C4E4B00006C0009000400EFBE575C088C575C088C2E000000956C0200000068000000000000000000000000000000B6F6F500460069007200650066006F007800200044006500760065006C006F007000650072002000450064006900740069006F006E002E006C006E006B0000001C00120000002B00EFBE23C59F59EAA4DC011C002E0000001D00EFBE0200430041003900340032003200370031003100410045003100410038003100430000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C000000FF'

# Action 467: !powerShell
$__cmd = @'
$taskbar="""$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"""; rm """$taskbar\*""" -Force -EA 0; $wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut("""$taskbar\File Explorer.lnk"""); $lnk.TargetPath="""$env:systemroot\explorer.exe"""; $lnk.Save(); $lnk=$wsh.CreateShortcut("""$taskbar\Brave.lnk"""); $lnk.TargetPath="""C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"""; $lnk.Save()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 468: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'FavoritesResolve' 'REG_BINARY' '340300004C0000000114020000000000C0000000000000468300800020000000202D5EE1C398DC01A59361E1C398DC0125B37A4D0584DA01970100000000000001000000000000000000000000000000A0013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B00420061007200000016000E013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C0000009D0000001C000000010000001C0000002D000000000000009C0000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46696C65204578706C6F7265722E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000C60200004C0000000114020000000000C0000000000000468300800020000000ABD1E689EAA4DC01B4D8E789EAA4DC0118A6D81FE5A4DC018409000000000000010000000000000000000000000000003A013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC010F64E789EAA4DC0114005600310000000000575C1B8C11005461736B42617200400009000400EFBE485C5433575C1D8C2E000000382A0200000003000000000000000000000000000000F46D00005400610073006B0042006100720000001600A800320084090000575CDA86200042726176652E6C6E6B00440009000400EFBE575C328C575C328C2E0000008D640200000009000000000000000000000000000000E8EF0201420072006100760065002E006C006E006B0000001800220000001E00EFBE02005500730065007200500069006E006E006500640000001800120000002B00EFBE2AB1E789EAA4DC011800180000001D00EFBE020042007200610076006500000018000000950000001C000000010000001C0000002D00000000000000940000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C42726176652E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BFA12103EE2011F111B9A9000C29A6860F1CF46009E731F34AA74C0247DFE2A3BFA12103EE2011F111B9A9000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000'

# Action 469: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'Favorites' 'REG_BINARY' '00A40100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B004200610072000000160012013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C00260000001E00EFBE0200530079007300740065006D00500069006E006E006500640000001C000000003A0100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC010F64E789EAA4DC0114005600310000000000575C1B8C11005461736B42617200400009000400EFBE485C5433575C1D8C2E000000382A0200000003000000000000000000000000000000F46D00005400610073006B0042006100720000001600A800320084090000575CDA86200042726176652E6C6E6B00440009000400EFBE575C328C575C328C2E0000008D640200000009000000000000000000000000000000E8EF0201420072006100760065002E006C006E006B0000001800120000002B00EFBE2AB1E789EAA4DC011800180000001D00EFBE02004200720061007600650000001800220000001E00EFBE02005500730065007200500069006E006E0065006400000018000000FF'

# Action 470: !powerShell
$__cmd = @'
$taskbar="""$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"""; rm """$taskbar\*""" -Force -EA 0; $wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut("""$taskbar\File Explorer.lnk"""); $lnk.TargetPath="""$env:systemroot\explorer.exe"""; $lnk.Save(); $lnk=$wsh.CreateShortcut("""$taskbar\Helium.lnk"""); $lnk.TargetPath="""$env:ProgramFiles\imput\Helium\Application\chrome.exe"""; $lnk.Save()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 471: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'FavoritesResolve' 'REG_BINARY' '320300004C0000000114020000000000C0000000000000468300800020000000DEF0F8CDBB44DD018F89FFCDBB44DD01127658BE864DDC01970100000000000001000000000000000000000000000000A0013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE12000000A952B7AABB44DD015ACDAAB9BB44DD01E334FDCDBB44DD01140056003100000000002F5D451511005461736B42617200400009000400EFBE2F5D32152F5D45152E000000134B0200000005000000000000000000000000000000BB8035005400610073006B00420061007200000016000E01320097010000645BC263200046494C4545587E312E4C4E4B00007C0009000400EFBE2F5D45152F5D45152E000000554C0200000005000000000000000000520000000000EE77AC00460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBE8F89FFCDBB44DD011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C0000009B0000001C000000010000001C0000002D000000000000009A00000011000000030000002E2AD7661000000000433A5C55736572735C557365725C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46696C65204578706C6F7265722E6C6E6B000060000000030000A058000000000000006465736B746F702D6362723967716A00842C2ADB76B764488A9107B1930E64EDE1AA70A7AEB0F111B194000C2911C35B842C2ADB76B764488A9107B1930E64EDE1AA70A7AEB0F111B194000C2911C35B45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000AF99F0F709285B4C8006F31C896D8450000000000000000000000000CB0200004C0000000114020000000000C00000000000004683008000200000006C00F9F8BB44DD01A0A5FAF8BB44DD01B975A79FBB44DD0104090000000000000100000000000000000000000000000040013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE12000000A952B7AABB44DD015ACDAAB9BB44DD01C613FAF8BB44DD01140056003100000000002F5D451511005461736B42617200400009000400EFBE2F5D32152F5D45152E000000134B0200000005000000000000000000000000000000BB8035005400610073006B0042006100720000001600AE003200040900002F5D1A15200048656C69756D2E6C6E6B0000460009000400EFBE2F5D6B152F5D6B152E0000009C490200000006000000000000000000000000000000479C0D00480065006C00690075006D002E006C006E006B0000001A00220000001E00EFBE02005500730065007200500069006E006E006500640000001A00120000002B00EFBE375DFAF8BB44DD011A001A0000001D00EFBE0200480065006C00690075006D0000001A000000940000001C000000010000001C0000002D000000000000009300000011000000030000002E2AD7661000000000433A5C55736572735C557365725C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C48656C69756D2E6C6E6B000060000000030000A058000000000000006465736B746F702D6362723967716A00842C2ADB76B764488A9107B1930E64ED2EAB70A7AEB0F111B194000C2911C35B842C2ADB76B764488A9107B1930E64ED2EAB70A7AEB0F111B194000C2911C35B45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000AF99F0F709285B4C8006F31C896D8450000000000000000000000000'

# Action 472: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'Favorites' 'REG_BINARY' '00A00100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE120000007B0F0399A844DD015E7AA9AAA844DD01F8BACA3EA944DD01140056003100000000002F5DAA0311005461736B42617200400009000400EFBE2F5D25032F5DAA032E000000F342020000000500000000000000000000000000000008B5EA005400610073006B00420061007200000016000E013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE2F5D25032F5DAA032E000000DF430200000005000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00120000002B00EFBE50EECB3EA944DD011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00000000760100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE120000007B0F0399A844DD015E7AA9AAA844DD015BF65243A944DD01140056003100000000002F5DAA0311005461736B42617200400009000400EFBE2F5D25032F5DAA032E000000F342020000000500000000000000000000000000000008B5EA005400610073006B0042006100720000001600E4003200B60900002F5DA203200048656C69756D2E6C6E6B0000460009000400EFBE2F5DAE032F5DAE032E000000FA4E020000000300000000000000000000000000000009131E01480065006C00690075006D002E006C006E006B0000001A00120000002B00EFBEA5575343A944DD011A00500000001D00EFBE0200480065006C00690075006D002E00470047005500510043005200510053004C00350057004F004B00480059004A0057005800510048005300410058004E004F00490000001A00220000001E00EFBE02005500730065007200500069006E006E006500640000001A000000FF'

# Action 473: !powerShell
$__cmd = @'
$taskbar="""$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"""; rm """$taskbar\*""" -Force -EA 0; $wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut("""$taskbar\File Explorer.lnk"""); $lnk.TargetPath="""$env:systemroot\explorer.exe"""; $lnk.Save(); $lnk=$wsh.CreateShortcut("""$taskbar\Mercury.lnk"""); $lnk.TargetPath="""$env:ProgramFiles\Mercury\mercury.exe"""; $lnk.Save()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 474: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'FavoritesResolve' 'REG_BINARY' '340300004C0000000114020000000000C0000000000000468300800020000000202D5EE1C398DC01A59361E1C398DC0125B37A4D0584DA01970100000000000001000000000000000000000000000000A0013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B00420061007200000016000E013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C0000009D0000001C000000010000001C0000002D000000000000009C0000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46696C65204578706C6F7265722E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000E40200004C0000000114020000000000C0000000000000468300800020000000486F25C7EAA4DC01D9CB26C7EAA4DC0172B68F52E4A4DC01B3030000000000000100000000000000000000000000000056013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01486F25C7EAA4DC0114005600310000000000575C618C11005461736B42617200400009000400EFBE485C5433575C628C2E000000382A020000000300000000000000000000000000000007A3F3005400610073006B0042006100720000001600C4003200B3030000575C238620004D6572637572792E6C6E6B00480009000400EFBE575C6A8C575C6A8C2E00000033B300000000040000000000000000000000000000008E7610004D006500720063007500720079002E006C006E006B0000001A00220000001E00EFBE02005500730065007200500069006E006E006500640000001A00120000002B00EFBE259B26C7EAA4DC011A002E0000001D00EFBE0200310037003300460037003100320035004100320041004300300037003800460000001A000000970000001C000000010000001C0000002D00000000000000960000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C4D6572637572792E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BFE02103EE2011F111B9A9000C29A6860F1CF46009E731F34AA74C0247DFE2A3BFE02103EE2011F111B9A9000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000'

# Action 475: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'Favorites' 'REG_BINARY' '00A40100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B004200610072000000160012013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C00260000001E00EFBE0200530079007300740065006D00500069006E006E006500640000001C00000000560100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01486F25C7EAA4DC0114005600310000000000575C618C11005461736B42617200400009000400EFBE485C5433575C628C2E000000382A020000000300000000000000000000000000000007A3F3005400610073006B0042006100720000001600C4003200B3030000575C238620004D6572637572792E6C6E6B00480009000400EFBE575C6A8C575C6A8C2E00000033B300000000040000000000000000000000000000008E7610004D006500720063007500720079002E006C006E006B0000001A00120000002B00EFBE259B26C7EAA4DC011A002E0000001D00EFBE0200310037003300460037003100320035004100320041004300300037003800460000001A00220000001E00EFBE02005500730065007200500069006E006E006500640000001A000000FF'

# Action 476: !powerShell
$__cmd = @'
$taskbar="""$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"""; rm """$taskbar\*""" -Force -EA 0; $wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut("""$taskbar\File Explorer.lnk"""); $lnk.TargetPath="""$env:systemroot\explorer.exe"""; $lnk.Save(); $lnk=$wsh.CreateShortcut("""$taskbar\Microsoft Edge.lnk"""); $lnk.TargetPath="""$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe"""; $lnk.Save()
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 477: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'FavoritesResolve' 'REG_BINARY' '340300004C0000000114020000000000C0000000000000468300800020000000202D5EE1C398DC01A59361E1C398DC0125B37A4D0584DA01970100000000000001000000000000000000000000000000A0013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B00420061007200000016000E013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C0000009D0000001C000000010000001C0000002D000000000000009C0000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C46696C65204578706C6F7265722E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF12442CB2B604F111B9A6000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000E70200004C0000000114020000000000C00000000000004683008000200000000026E9DBEAA4DC01C61AEADBEAA4DC01290975192EA5DC0186090000000000000100000000000000000000000000000052013A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01EF75E9DBEAA4DC0114005600310000000000575C798C11005461736B42617200400009000400EFBE485C5433575C7A8C2E000000382A0200000003000000000000000000000000000000180B2D015400610073006B0042006100720000001600C000320086090000585CA70C20004D4943524F537E312E4C4E4B0000560009000400EFBE575C7B8C575C7B8C2E000000A96D0200000002000000000000000000000000000000D737B0004D006900630072006F0073006F0066007400200045006400670065002E006C006E006B0000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C00120000002B00EFBED3EFE9DBEAA4DC011C001A0000001D00EFBE02004D005300450064006700650000001C0000009E0000001C000000010000001C0000002D000000000000009D0000001100000003000000A4FF866C1000000000433A5C55736572735C5573657220315C417070446174615C526F616D696E675C4D6963726F736F66745C496E7465726E6574204578706C6F7265725C517569636B204C61756E63685C557365722050696E6E65645C5461736B4261725C4D6963726F736F667420456467652E6C6E6B000060000000030000A058000000000000006465736B746F702D69626A70753165001CF46009E731F34AA74C0247DFE2A3BF022203EE2011F111B9A9000C29A6860F1CF46009E731F34AA74C0247DFE2A3BF022203EE2011F111B9A9000C29A6860F45000000090000A03900000031535053B1166D44AD8D7048A748402EA43D788C1D000000680000000048000000EC20B4B621D12B478E81BF11F5498123000000000000000000000000'

# Action 478: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' 'Favorites' 'REG_BINARY' '00A40100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01BCE460E1C398DC0114005600310000000000485C543311005461736B42617200400009000400EFBE485C5433485C54332E000000382A020000000300000000000000000000000000000044AB19015400610073006B004200610072000000160012013200970100008158C43A200046494C4545587E312E4C4E4B00007C0009000400EFBE485C5433485C54332E000000392A0200000003000000000000000000520000000000DBDC9100460069006C00650020004500780070006C006F007200650072002E006C006E006B00000040007300680065006C006C00330032002E0064006C006C002C002D003200320030003600370000001C00120000002B00EFBEA59361E1C398DC011C00420000001D00EFBE02004D006900630072006F0073006F00660074002E00570069006E0064006F00770073002E004500780070006C006F0072006500720000001C00260000001E00EFBE0200530079007300740065006D00500069006E006E006500640000001C00000000520100003A001F80C827341F105C1042AA032EE45287D668260001002600EFBE1200000007471CB9C398DC01FC115DE1C398DC01EF75E9DBEAA4DC0114005600310000000000575C798C11005461736B42617200400009000400EFBE485C5433575C7A8C2E000000382A0200000003000000000000000000000000000000180B2D015400610073006B0042006100720000001600C000320086090000585CA70C20004D4943524F537E312E4C4E4B0000560009000400EFBE575C7B8C575C7B8C2E000000A96D0200000002000000000000000000000000000000D737B0004D006900630072006F0073006F0066007400200045006400670065002E006C006E006B0000001C00120000002B00EFBED3EFE9DBEAA4DC011C001A0000001D00EFBE02004D005300450064006700650000001C00220000001E00EFBE02005500730065007200500069006E006E006500640000001C000000FF'

# Action 479: !status
Write-Status 'Configuring Start Menu'

# Action 480: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"SearchEngine-Client-Package" /NoRestart'

# Action 481: !service
try { Set-Service -Name 'wsearch' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service wsearch: $_" }

# Action 482: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 'REG_DWORD' '0'

# Action 483: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsAADCloudSearchEnabled' 'REG_DWORD' '0'

# Action 484: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDeviceSearchHistoryEnabled' 'REG_DWORD' '0'

# Action 485: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsMSACloudSearchEnabled' 'REG_DWORD' '0'

# Action 486: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' 'SafeSearchMode' 'REG_DWORD' '0'

# Action 487: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' 'REG_DWORD' '0'

# Action 488: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 'REG_DWORD' '1'

# Action 489: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'EnableDynamicContentInWSB' 'REG_DWORD' '0'

# Action 490: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 'REG_DWORD' '1'

# Action 491: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 'REG_DWORD' '0'

# Action 492: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 'REG_DWORD' '0'

# Action 493: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoStartMenuMFUprogramsList' 'REG_DWORD' '1'

# Action 494: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'ShowOrHideMostUsedApps' 'REG_DWORD' '2'

# Action 495: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecentlyAddedApps' 'REG_DWORD' '1'

# Action 496: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecommendedPersonalizedSites' 'REG_DWORD' '1'

# Action 497: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'HideFastUserSwitching' 'REG_DWORD' '1'

# Action 498: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 'REG_DWORD' '0'

# Action 499: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_AccountNotifications' 'REG_DWORD' '0'

# Action 500: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoNetworkConnections' 'REG_DWORD' '1'

# Action 501: !powerShell
$__cmd = @'
$p=\"$env:LOCALAPPDATA\Packages\"; Get-ChildItem $p -Directory | Where-Object{$_.Name -match \"Microsoft.Windows.StartMenuExperienceHost\"} | ForEach-Object{ Get-ChildItem \"$p\$($_.Name)\LocalState\" -Filter \"start*.bin\" -ErrorAction SilentlyContinue | Remove-Item -Force }; Get-ChildItem \"HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\" -Recurse -ErrorAction SilentlyContinue | Where-Object{$_.Name -match \"start.tilegrid\"} | Remove-Item -Force; Remove-ItemProperty -Path \"HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Start\" -Name Config -Force -ErrorAction SilentlyContinue
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 502: !status
Write-Status 'Restoring old notepad'

# Action 503: !registryKey
try { $p=Convert-RegPath 'HKCR\*\OpenWithList\notepad.exe'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\*\OpenWithList\notepad.exe - $_" }

# Action 504: !registryValue
Remove-RegValue 'HKCR\Applications\notepad.exe' 'NoOpenWith'

# Action 505: !registryValue
Set-Reg 'HKCR\Applications\notepad.exe\DefaultIcon' '' 'REG_EXPAND_SZ' '%SystemRoot%\System32\imageres.dll,-102'

# Action 506: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Notepad' 'ShowStoreBanner' 'REG_DWORD' '0'

# Action 507: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Notepad' 'fWrapAround' 'REG_DWORD' '1'

# Action 508: !registryValue
Set-Reg 'HKCR\.txt\ShellNew' 'ItemName' 'REG_EXPAND_SZ' '@%SystemRoot%\System32\notepad.exe,-470'

# Action 509: !registryValue
Set-Reg 'HKCR\.txt\ShellNew' 'NullFile' 'REG_SZ' ''

# Action 510: !registryValue
Set-Reg 'HKCR\txtfilelegacy' '' 'REG_SZ' 'Text Document'

# Action 511: !registryValue
Set-Reg 'HKCR\txtfilelegacy' 'EditFlags' 'REG_DWORD' '2162688'

# Action 512: !registryValue
Set-Reg 'HKCR\txtfilelegacy' 'FriendlyTypeName' 'REG_EXPAND_SZ' '@%SystemRoot%\System32\notepad.exe,-469'

# Action 513: !registryValue
Set-Reg 'HKCR\txtfilelegacy\DefaultIcon' '' 'REG_EXPAND_SZ' '%SystemRoot%\System32\imageres.dll,-102'

# Action 514: !registryValue
Set-Reg 'HKCR\txtfilelegacy\Shell\Open\Command' '' 'REG_EXPAND_SZ' '%SystemRoot%\System32\notepad.exe %1'

# Action 515: !registryValue
Set-Reg 'HKCR\inifile' '' 'REG_SZ' 'Configuration Settings'

# Action 516: !registryValue
Set-Reg 'HKCR\inifile' 'EditFlags' 'REG_DWORD' '2097152'

# Action 517: !registryValue
Set-Reg 'HKCR\inifile' 'FriendlyTypeName' 'REG_SZ' '@%SystemRoot%\System32\shell32.dll,-10151'

# Action 518: !registryValue
Set-Reg 'HKCR\inifile\DefaultIcon' '' 'REG_EXPAND_SZ' '%SystemRoot%\System32\imageres.dll,-69'

# Action 519: !registryValue
Set-Reg 'HKCR\inifile\Shell\Edit\Command' '' 'REG_EXPAND_SZ' '%SystemRoot%\System32\notepad.exe %1'

# Action 520: !registryValue
Set-Reg 'HKCR\inifile\Shell\Open\Command' '' 'REG_EXPAND_SZ' '%SystemRoot%\System32\notepad.exe %1'

# Action 521: !registryValue
Set-Reg 'HKCR\.ini' '' 'REG_SZ' 'inifile'

# Action 522: !registryValue
Set-Reg 'HKCR\inffile' '' 'REG_SZ' 'Setup Information'

# Action 523: !registryValue
Set-Reg 'HKCR\inffile' 'FriendlyTypeName' 'REG_EXPAND_SZ' '@%SystemRoot%\System32\setupapi.dll,-2000'

# Action 524: !registryValue
Set-Reg 'HKCR\inffile\DefaultIcon' '' 'REG_EXPAND_SZ' '%SystemRoot%\System32\imageres.dll,-69'

# Action 525: !registryValue
Set-Reg 'HKCR\inffile\Shell\Open\Command' '' 'REG_EXPAND_SZ' '%SystemRoot%\System32\notepad.exe %1'

# Action 526: !registryValue
Set-Reg 'HKCR\.inf' '' 'REG_SZ' 'inffile'

# Action 527: !registryValue
Set-Reg 'HKCR\.log' '' 'REG_SZ' 'txtfilelegacy'

# Action 528: !registryValue
Set-Reg 'HKCR\.scp' '' 'REG_SZ' 'txtfilelegacy'

# Action 529: !registryValue
Set-Reg 'HKCR\.wtx' '' 'REG_SZ' 'txtfilelegacy'

# Action 530: !registryValue
Set-Reg 'HKCR\Microsoft.PowerShellScript.1\Shell\Edit\Command' '' 'REG_SZ' '"C:\Windows\System32\notepad.exe" "%1"'

# Action 531: !status
Write-Status 'Enabling DirectPlay'

# Action 532: !run
Invoke-Native 'DISM.exe' '/Online /Enable-Feature /FeatureName:"DirectPlay" /NoRestart /All'

# Action 533: !status
Write-Status 'Disabling StepsRecorder'

# Action 534: !run
Invoke-Native 'DISM.exe' '/Online /Remove-Capability /CapabilityName:"App.StepsRecorder~~~~0.0.1.0" /NoRestart'

# Action 535: !status
Write-Status 'Disabling Legacy Media Player'

# Action 536: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"WindowsMediaPlayer" /NoRestart'

# Action 537: !run
Invoke-Native 'DISM.exe' '/Online /Remove-Capability /CapabilityName:"Media.WindowsMediaPlayer~~~~0.0.12.0" /NoRestart'

# Action 538: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"MediaPlayback" /NoRestart'

# Action 539: !status
Write-Status 'Disabling SMBDirect'

# Action 540: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"SMBDirect" /NoRestart'

# Action 541: !status
Write-Status 'Disabling RDC'

# Action 542: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"MSRDC-Infrastructure" /NoRestart'

# Action 543: !status
Write-Status 'Disabling Workfolders Client'

# Action 544: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"Workfolders-client" /NoRestart'

# Action 545: !status
Write-Status 'Disabling WCF services & portsharing'

# Action 546: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"WCF-Services45" /NoRestart'

# Action 547: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"WCF-TCP-PortSharing45" /NoRestart'

# Action 548: !status
Write-Status 'Removing OneDrive'

# Action 549: !cmd
Invoke-Cmd 'OneDriveSetup /uninstall'

# Action 550: !file
try { $p=Resolve-Env '%ProgramData%\Microsoft OneDrive'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramData%\Microsoft OneDrive - $_" }

# Action 551: !file
try { $p=Resolve-Env '%UserProfile%\OneDrive'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %UserProfile%\OneDrive - $_" }

# Action 552: !file
try { $p=Resolve-Env '%LocalAppdata%\Microsoft\OneDrive'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %LocalAppdata%\Microsoft\OneDrive - $_" }

# Action 553: !file
try { $p=Resolve-Env '%SystemRoot%\System32\OneDriveSetup.exe'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %SystemRoot%\System32\OneDriveSetup.exe - $_" }

# Action 554: !file
try { $p=Resolve-Env '%SystemRoot%\SysWOW64\OneDriveSetup.exe'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %SystemRoot%\SysWOW64\OneDriveSetup.exe - $_" }

# Action 555: !registryKey
try { $p=Convert-RegPath 'HKCU\Software\Microsoft\OneDrive'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCU\Software\Microsoft\OneDrive - $_" }

# Action 556: !registryKey
try { $p=Convert-RegPath 'HKCU\Software\WOW6432Node\Microsoft\OneDrive'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCU\Software\WOW6432Node\Microsoft\OneDrive - $_" }

# Action 557: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\BannerStore'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\BannerStore - $_" }

# Action 558: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\BannerStore'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\BannerStore - $_" }

# Action 559: !registryValue
Remove-RegValue 'HKCU\Environment' 'OneDrive'

# Action 560: !powerShell
$__cmd = @'
Get-ScheduledTask | Where-Object { $_.TaskName -like '*Oned*' } | ForEach-Object { Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 561: !status
Write-Status 'Removing Microsoft Edge'

# Action 562: !service

# Action 563: !service

# Action 564: !service

# Action 565: !file
try { $p=Resolve-Env '%ProgramFiles(x86)%\Microsoft\EdgeUpdate'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles(x86)%\Microsoft\EdgeUpdate - $_" }

# Action 566: !file
try { $p=Resolve-Env '%ProgramFiles(x86)%\Microsoft\EdgeCore'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles(x86)%\Microsoft\EdgeCore - $_" }

# Action 567: !file
try { $p=Resolve-Env '%ProgramFiles(x86)%\Microsoft\Edge'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles(x86)%\Microsoft\Edge - $_" }

# Action 568: !file
try { $p=Resolve-Env '%ProgramFiles(x86)%\Microsoft\EdgeWebView'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramFiles(x86)%\Microsoft\EdgeWebView - $_" }

# Action 569: !file
try { $p=Resolve-Env '%LocalAppdata%\Microsoft\Edge'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %LocalAppdata%\Microsoft\Edge - $_" }

# Action 570: !file
try { $p=Resolve-Env '%ProgramData%\Microsoft\EdgeUpdate'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramData%\Microsoft\EdgeUpdate - $_" }

# Action 571: !file
try { $p=Resolve-Env '%SystemRoot%\system32\Tasks\MicrosoftEdge*'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %SystemRoot%\system32\Tasks\MicrosoftEdge* - $_" }

# Action 572: !file
try { $p=Resolve-Env '%SystemRoot%\System32\config\systemprofile\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %SystemRoot%\System32\config\systemprofile\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk - $_" }

# Action 573: !file
try { $p=Resolve-Env '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %ProgramData%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk - $_" }

# Action 574: !file
try { $p=Resolve-Env '%SystemDrive%\Users\Public\Desktop\Microsoft Edge.lnk'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %SystemDrive%\Users\Public\Desktop\Microsoft Edge.lnk - $_" }

# Action 575: !file
try { $p=Resolve-Env '%Appdata%\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %Appdata%\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk - $_" }

# Action 576: !file
try { $p=Resolve-Env '%Appdata%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %Appdata%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk - $_" }

# Action 577: !registryKey
try { $p=Convert-RegPath 'HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\Edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\Edge - $_" }

# Action 578: !registryKey
try { $p=Convert-RegPath 'HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\edgeupdate'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\edgeupdate - $_" }

# Action 579: !registryKey
try { $p=Convert-RegPath 'HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\edgeupdatem'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\edgeupdatem - $_" }

# Action 580: !registryKey
try { $p=Convert-RegPath 'HKCR\AppID\ie_to_edge_bho.dll'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\AppID\ie_to_edge_bho.dll - $_" }

# Action 581: !registryKey
try { $p=Convert-RegPath 'HKCR\AppID\{1FCBE96C-1697-43AF-9140-2897C7C69767}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\AppID\{1FCBE96C-1697-43AF-9140-2897C7C69767} - $_" }

# Action 582: !registryKey
try { $p=Convert-RegPath 'HKCR\AppID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\AppID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5} - $_" }

# Action 583: !registryKey
try { $p=Convert-RegPath 'HKCR\AppID\{31575964-95F7-414B-85E4-0E9A93699E13}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\AppID\{31575964-95F7-414B-85E4-0E9A93699E13} - $_" }

# Action 584: !registryKey
try { $p=Convert-RegPath 'HKCR\CLSID\{1FCBE96C-1697-43AF-9140-2897C7C69767}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\CLSID\{1FCBE96C-1697-43AF-9140-2897C7C69767} - $_" }

# Action 585: !registryKey
try { $p=Convert-RegPath 'HKCR\CLSID\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\CLSID\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C} - $_" }

# Action 586: !registryKey
try { $p=Convert-RegPath 'HKCR\CLSID\{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\CLSID\{3A84F9C2-6164-485C-A7D9-4B27F8AC009E} - $_" }

# Action 587: !registryKey
try { $p=Convert-RegPath 'HKCR\CLSID\{4A749F25-A9E2-4CBE-9859-CF7B15255E14}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\CLSID\{4A749F25-A9E2-4CBE-9859-CF7B15255E14} - $_" }

# Action 588: !registryKey
try { $p=Convert-RegPath 'HKCR\CLSID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\CLSID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5} - $_" }

# Action 589: !registryKey
try { $p=Convert-RegPath 'HKCR\CLSID\{B54934CD-71A6-4698-BDC2-AFEA5B86504C}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\CLSID\{B54934CD-71A6-4698-BDC2-AFEA5B86504C} - $_" }

# Action 590: !registryKey
try { $p=Convert-RegPath 'HKCR\https\shell'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\https\shell - $_" }

# Action 591: !registryKey
try { $p=Convert-RegPath 'HKCR\http\shell'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\http\shell - $_" }

# Action 592: !registryKey
try { $p=Convert-RegPath 'HKCR\ie_to_edge_bho.IEToEdgeBHO'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\ie_to_edge_bho.IEToEdgeBHO - $_" }

# Action 593: !registryKey
try { $p=Convert-RegPath 'HKCR\ie_to_edge_bho.IEToEdgeBHO.1'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\ie_to_edge_bho.IEToEdgeBHO.1 - $_" }

# Action 594: !registryKey
try { $p=Convert-RegPath 'HKCR\Interface\{C9C2B807-7731-4F34-81B7-44FF7779522B}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Interface\{C9C2B807-7731-4F34-81B7-44FF7779522B} - $_" }

# Action 595: !registryKey
try { $p=Convert-RegPath 'HKCR\microsoft-edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\microsoft-edge - $_" }

# Action 596: !registryKey
try { $p=Convert-RegPath 'HKCR\MSEdgeHTM'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\MSEdgeHTM - $_" }

# Action 597: !registryKey
try { $p=Convert-RegPath 'HKCR\MSEdgeMHT'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\MSEdgeMHT - $_" }

# Action 598: !registryKey
try { $p=Convert-RegPath 'HKCR\MSEdgePDF'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\MSEdgePDF - $_" }

# Action 599: !registryKey
try { $p=Convert-RegPath 'HKCR\TypeLib\{C9C2B807-7731-4F34-81B7-44FF7779522B}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\TypeLib\{C9C2B807-7731-4F34-81B7-44FF7779522B} - $_" }

# Action 600: !registryKey
try { $p=Convert-RegPath 'HKCR\.pdf\ShellEx\{8895b1c6-b41f-4c1c-a562-0d564250836f}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\.pdf\ShellEx\{8895b1c6-b41f-4c1c-a562-0d564250836f} - $_" }

# Action 601: !registryKey
try { $p=Convert-RegPath 'HKCU\Software\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCU\Software\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE} - $_" }

# Action 602: !registryKey
try { $p=Convert-RegPath 'HKCU\Software\Microsoft\Edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCU\Software\Microsoft\Edge - $_" }

# Action 603: !registryKey
try { $p=Convert-RegPath 'HKCU\Software\Microsoft\EdgeUpdate'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCU\Software\Microsoft\EdgeUpdate - $_" }

# Action 604: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Clients\StartMenuInternet\Microsoft Edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Clients\StartMenuInternet\Microsoft Edge - $_" }

# Action 605: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE} - $_" }

# Action 606: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Edge - $_" }

# Action 607: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\EdgeUpdate'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\EdgeUpdate - $_" }

# Action 608: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Internet Explorer\EdgeIntegration'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Internet Explorer\EdgeIntegration - $_" }

# Action 609: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{c9abcf16-8dc2-4a95-bae3-24fd98f2ed29}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{c9abcf16-8dc2-4a95-bae3-24fd98f2ed29} - $_" }

# Action 610: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Internet Explorer\ProtocolExecute\microsoft-edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Internet Explorer\ProtocolExecute\microsoft-edge - $_" }

# Action 611: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\MediaPlayer\ShimInclusionList\msedge.exe'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\MediaPlayer\ShimInclusionList\msedge.exe - $_" }

# Action 612: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe - $_" }

# Action 613: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C} - $_" }

# Action 614: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Ext\PreApproved\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Ext\PreApproved\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C} - $_" }

# Action 615: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge - $_" }

# Action 616: !registryValue
Remove-RegValue 'HKCR\.html\OpenWithProgIds' 'MSEdgeHTM'

# Action 617: !registryValue
Remove-RegValue 'HKCR\.htm\OpenWithProgIds' 'MSEdgeHTM'

# Action 618: !registryValue
Remove-RegValue 'HKCR\.shtml\OpenWithProgIds' 'MSEdgeHTM'

# Action 619: !registryValue
Remove-RegValue 'HKCR\.svg\OpenWithProgIds' 'MSEdgeHTM'

# Action 620: !registryValue
Remove-RegValue 'HKCR\.webp\OpenWithProgIds' 'MSEdgeHTM'

# Action 621: !registryValue
Remove-RegValue 'HKCR\.xhtml\OpenWithProgIds' 'MSEdgeHTM'

# Action 622: !registryValue
Remove-RegValue 'HKCR\.xht\OpenWithProgIds' 'MSEdgeHTM'

# Action 623: !registryValue
Remove-RegValue 'HKCR\.xml\OpenWithProgIds' 'MSEdgeHTM'

# Action 624: !registryValue
Remove-RegValue 'HKCU\Software\RegisteredApplications' 'Microsoft Edge'

# Action 625: !registryValue
Remove-RegValue 'HKCU\Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts' 'MSEdgeHTM_microsoft-edge'

# Action 626: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\EdgeUpdate' 'IsEdgeStableUninstalled' 'REG_DWORD' '1'

# Action 627: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\Microsoft\Internet Explorer\Capabilities\UrlAssociations' 'https'

# Action 628: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\Microsoft\Internet Explorer\Capabilities\UrlAssociations' 'http'

# Action 629: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\Microsoft\Internet Explorer\Main\EnterpriseMode ' 'MSEdgePath'

# Action 630: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts' 'MSEdgeHTM_microsoft-edge'

# Action 631: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Media Center' '{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}'

# Action 632: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Ext\CLSID' '{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}'

# Action 633: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PreviewHandlers' '{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}'

# Action 634: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\RegisteredApplications' 'Microsoft Edge'

# Action 635: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\AppID\ie_to_edge_bho.dll'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\AppID\ie_to_edge_bho.dll - $_" }

# Action 636: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\AppID\{1FCBE96C-1697-43AF-9140-2897C7C69767}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\AppID\{1FCBE96C-1697-43AF-9140-2897C7C69767} - $_" }

# Action 637: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\AppID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\AppID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5} - $_" }

# Action 638: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\AppID\{31575964-95F7-414B-85E4-0E9A93699E13}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\AppID\{31575964-95F7-414B-85E4-0E9A93699E13} - $_" }

# Action 639: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\CLSID\{1FCBE96C-1697-43AF-9140-2897C7C69767}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\CLSID\{1FCBE96C-1697-43AF-9140-2897C7C69767} - $_" }

# Action 640: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\CLSID\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\CLSID\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C} - $_" }

# Action 641: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\CLSID\{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\CLSID\{3A84F9C2-6164-485C-A7D9-4B27F8AC009E} - $_" }

# Action 642: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\CLSID\{4A749F25-A9E2-4CBE-9859-CF7B15255E14}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\CLSID\{4A749F25-A9E2-4CBE-9859-CF7B15255E14} - $_" }

# Action 643: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\CLSID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\CLSID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5} - $_" }

# Action 644: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\CLSID\{B54934CD-71A6-4698-BDC2-AFEA5B86504C}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\CLSID\{B54934CD-71A6-4698-BDC2-AFEA5B86504C} - $_" }

# Action 645: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\https\shell'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\https\shell - $_" }

# Action 646: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\http\shell'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\http\shell - $_" }

# Action 647: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\ie_to_edge_bho.IEToEdgeBHO'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\ie_to_edge_bho.IEToEdgeBHO - $_" }

# Action 648: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\ie_to_edge_bho.IEToEdgeBHO.1'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\ie_to_edge_bho.IEToEdgeBHO.1 - $_" }

# Action 649: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\Interface\{C9C2B807-7731-4F34-81B7-44FF7779522B}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\Interface\{C9C2B807-7731-4F34-81B7-44FF7779522B} - $_" }

# Action 650: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\microsoft-edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\microsoft-edge - $_" }

# Action 651: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\MSEdgeHTM'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\MSEdgeHTM - $_" }

# Action 652: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\MSEdgeMHT'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\MSEdgeMHT - $_" }

# Action 653: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\MSEdgePDF'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\MSEdgePDF - $_" }

# Action 654: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\TypeLib\{C9C2B807-7731-4F34-81B7-44FF7779522B}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\TypeLib\{C9C2B807-7731-4F34-81B7-44FF7779522B} - $_" }

# Action 655: !registryKey
try { $p=Convert-RegPath 'HKCR\WOW6432Node\.pdf\ShellEx\{8895b1c6-b41f-4c1c-a562-0d564250836f}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WOW6432Node\.pdf\ShellEx\{8895b1c6-b41f-4c1c-a562-0d564250836f} - $_" }

# Action 656: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Clients\StartMenuInternet\Microsoft Edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Clients\StartMenuInternet\Microsoft Edge - $_" }

# Action 657: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE} - $_" }

# Action 658: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Edge - $_" }

# Action 659: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate - $_" }

# Action 660: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\EdgeIntegration'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\EdgeIntegration - $_" }

# Action 661: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{c9abcf16-8dc2-4a95-bae3-24fd98f2ed29}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{c9abcf16-8dc2-4a95-bae3-24fd98f2ed29} - $_" }

# Action 662: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\ProtocolExecute\microsoft-edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\ProtocolExecute\microsoft-edge - $_" }

# Action 663: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\MediaPlayer\ShimInclusionList\msedge.exe'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\MediaPlayer\ShimInclusionList\msedge.exe - $_" }

# Action 664: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe - $_" }

# Action 665: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C} - $_" }

# Action 666: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Ext\PreApproved\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Ext\PreApproved\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C} - $_" }

# Action 667: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge - $_" }

# Action 668: !registryValue
Remove-RegValue 'HKCR\WOW6432Node\.html\OpenWithProgIds' 'MSEdgeHTM'

# Action 669: !registryValue
Remove-RegValue 'HKCR\WOW6432Node\.htm\OpenWithProgIds' 'MSEdgeHTM'

# Action 670: !registryValue
Remove-RegValue 'HKCR\WOW6432Node\.shtml\OpenWithProgIds' 'MSEdgeHTM'

# Action 671: !registryValue
Remove-RegValue 'HKCR\WOW6432Node\.svg\OpenWithProgIds' 'MSEdgeHTM'

# Action 672: !registryValue
Remove-RegValue 'HKCR\WOW6432Node\.webp\OpenWithProgIds' 'MSEdgeHTM'

# Action 673: !registryValue
Remove-RegValue 'HKCR\WOW6432Node\.xhtml\OpenWithProgIds' 'MSEdgeHTM'

# Action 674: !registryValue
Remove-RegValue 'HKCR\WOW6432Node\.xht\OpenWithProgIds' 'MSEdgeHTM'

# Action 675: !registryValue
Remove-RegValue 'HKCR\WOW6432Node\.xml\OpenWithProgIds' 'MSEdgeHTM'

# Action 676: !registryValue
Set-Reg 'HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate' 'IsEdgeStableUninstalled' 'REG_DWORD' '1'

# Action 677: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Capabilities\UrlAssociations' 'https'

# Action 678: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Capabilities\UrlAssociations' 'http'

# Action 679: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Main\EnterpriseMode ' 'MSEdgePath'

# Action 680: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts' 'MSEdgeHTM_microsoft-edge'

# Action 681: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Media Center' '{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}'

# Action 682: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Ext\CLSID' '{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}'

# Action 683: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\PreviewHandlers' '{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}'

# Action 684: !registryValue
Remove-RegValue 'HKLM\SOFTWARE\WOW6432Node\RegisteredApplications' 'Microsoft Edge'

# Action 685: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Edge.GameAssist*' -or $_.PackageFullName -like '*Edge.GameAssist*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Edge.GameAssist*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Edge.GameAssist*: $_" }

# Action 686: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*MicrosoftEdgeDevToolsClient*' -or $_.PackageFullName -like '*MicrosoftEdgeDevToolsClient*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*MicrosoftEdgeDevToolsClient*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *MicrosoftEdgeDevToolsClient*: $_" }

# Action 687: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*MicrosoftEdge.Stable*' -or $_.PackageFullName -like '*MicrosoftEdge.Stable*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*MicrosoftEdge.Stable*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *MicrosoftEdge.Stable*: $_" }

# Action 688: !powerShell
$__cmd = @'
Get-ScheduledTask | Where-Object { $_.TaskName -like '*MicrosoftEdgeUpdate*' } | ForEach-Object { Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 689: !registryKey
Remove-RegKey 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate'

# Action 690: !registryKey
Remove-RegKey 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\EdgeUpdate'

# Action 691: !registryKey
Remove-RegKey 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate'

# Action 692: !registryKey
Remove-RegKey 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\CrossDeviceUpdate'

# Action 693: !powerShell
$__cmd = @'
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' | % { $_.PSObject.Properties | ? { $_.Name -like 'MicrosoftEdge*' } | % { Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $_.Name } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 694: !status
Write-Status 'Removing AppX Packages'

# Action 695: !powerShell
$__cmd = @'
(Get-AppxPackage).PackageFamilyName | Out-File """$([Environment]::GetFolderPath('Windows'))\oldpackages.txt"""
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 696: !taskKill
try { Stop-Process -Name 'msteams*' -Force -ErrorAction SilentlyContinue } catch {}

# Action 697: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications' 'ConfigureChatAutoInstall' 'REG_DWORD' '0'

# Action 698: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.AVCEncoderVideoExtension*' -or $_.PackageFullName -like 'Microsoft.AVCEncoderVideoExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.AVCEncoderVideoExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.AVCEncoderVideoExtension*: $_" }

# Action 699: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.AV1VideoExtension*' -or $_.PackageFullName -like 'Microsoft.AV1VideoExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.AV1VideoExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.AV1VideoExtension*: $_" }

# Action 700: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftWindows.UndockedDevKit*' -or $_.PackageFullName -like 'MicrosoftWindows.UndockedDevKit*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftWindows.UndockedDevKit*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftWindows.UndockedDevKit*: $_" }

# Action 701: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.MPEG2VideoExtension*' -or $_.PackageFullName -like 'Microsoft.MPEG2VideoExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.MPEG2VideoExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.MPEG2VideoExtension*: $_" }

# Action 702: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.ApplicationCompatibilityEnhancements*' -or $_.PackageFullName -like 'Microsoft.ApplicationCompatibilityEnhancements*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.ApplicationCompatibilityEnhancements*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.ApplicationCompatibilityEnhancements*: $_" }

# Action 703: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Windows.StartMenuExperienceHost*' -or $_.PackageFullName -like 'Microsoft.Windows.StartMenuExperienceHost*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.Windows.StartMenuExperienceHost*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.Windows.StartMenuExperienceHost*: $_" }

# Action 704: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*CortanaUI*' -or $_.PackageFullName -like '*CortanaUI*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*CortanaUI*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *CortanaUI*: $_" }

# Action 705: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*CortanaUIFullTrustApp*' -or $_.PackageFullName -like '*CortanaUIFullTrustApp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*CortanaUIFullTrustApp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *CortanaUIFullTrustApp*: $_" }

# Action 706: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.HEIFImageExtension*' -or $_.PackageFullName -like 'Microsoft.HEIFImageExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.HEIFImageExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.HEIFImageExtension*: $_" }

# Action 707: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.HEVCVideoExtension*' -or $_.PackageFullName -like 'Microsoft.HEVCVideoExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.HEVCVideoExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.HEVCVideoExtension*: $_" }

# Action 708: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.VP9VideoExtensions*' -or $_.PackageFullName -like 'Microsoft.VP9VideoExtensions*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.VP9VideoExtensions*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.VP9VideoExtensions*: $_" }

# Action 709: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftTeams*' -or $_.PackageFullName -like 'MicrosoftTeams*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftTeams*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftTeams*: $_" }

# Action 710: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MSTeams*' -or $_.PackageFullName -like 'MSTeams*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MSTeams*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MSTeams*: $_" }

# Action 711: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.Copilot*' -or $_.PackageFullName -like '*Microsoft.Copilot*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.Copilot*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.Copilot*: $_" }

# Action 712: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*StartExperiencesApp*' -or $_.PackageFullName -like '*StartExperiencesApp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*StartExperiencesApp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *StartExperiencesApp*: $_" }

# Action 713: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Clipchamp.Clipchamp*' -or $_.PackageFullName -like 'Clipchamp.Clipchamp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Clipchamp.Clipchamp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Clipchamp.Clipchamp*: $_" }

# Action 714: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.WindowsTerminal*' -or $_.PackageFullName -like 'Microsoft.WindowsTerminal*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.WindowsTerminal*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.WindowsTerminal*: $_" }

# Action 715: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftWindows.LKG.AccountsService*' -or $_.PackageFullName -like 'MicrosoftWindows.LKG.AccountsService*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftWindows.LKG.AccountsService*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftWindows.LKG.AccountsService*: $_" }

# Action 716: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftWindows.LKG.RulesEngine*' -or $_.PackageFullName -like 'MicrosoftWindows.LKG.RulesEngine*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftWindows.LKG.RulesEngine*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftWindows.LKG.RulesEngine*: $_" }

# Action 717: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftWindows.LKG.TwinSxS*' -or $_.PackageFullName -like 'MicrosoftWindows.LKG.TwinSxS*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftWindows.LKG.TwinSxS*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftWindows.LKG.TwinSxS*: $_" }

# Action 718: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftWindows.LKG.Search*' -or $_.PackageFullName -like 'MicrosoftWindows.LKG.Search*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftWindows.LKG.Search*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftWindows.LKG.Search*: $_" }

# Action 719: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.WebpImageExtension*' -or $_.PackageFullName -like 'Microsoft.WebpImageExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.WebpImageExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.WebpImageExtension*: $_" }

# Action 720: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.WebMediaExtensions*' -or $_.PackageFullName -like 'Microsoft.WebMediaExtensions*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.WebMediaExtensions*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.WebMediaExtensions*: $_" }

# Action 721: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.RawImageExtension*' -or $_.PackageFullName -like 'Microsoft.RawImageExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.RawImageExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.RawImageExtension*: $_" }

# Action 722: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.HEIFImageExtension*' -or $_.PackageFullName -like 'Microsoft.HEIFImageExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.HEIFImageExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.HEIFImageExtension*: $_" }

# Action 723: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*WidgetsPlatformRuntime*' -or $_.PackageFullName -like '*WidgetsPlatformRuntime*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*WidgetsPlatformRuntime*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *WidgetsPlatformRuntime*: $_" }

# Action 724: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*MicrosoftWindows.LKG.DesktopSpotlight*' -or $_.PackageFullName -like '*MicrosoftWindows.LKG.DesktopSpotlight*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*MicrosoftWindows.LKG.DesktopSpotlight*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *MicrosoftWindows.LKG.DesktopSpotlight*: $_" }

# Action 725: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Windows.AugLoop.CBS*' -or $_.PackageFullName -like 'Microsoft.Windows.AugLoop.CBS*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.Windows.AugLoop.CBS*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.Windows.AugLoop.CBS*: $_" }

# Action 726: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*MicrosoftWindows.LKG.IrisService*' -or $_.PackageFullName -like '*MicrosoftWindows.LKG.IrisService*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*MicrosoftWindows.LKG.IrisService*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *MicrosoftWindows.LKG.IrisService*: $_" }

# Action 727: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*MicrosoftWindows.LKG.SpeechRuntime*' -or $_.PackageFullName -like '*MicrosoftWindows.LKG.SpeechRuntime*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*MicrosoftWindows.LKG.SpeechRuntime*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *MicrosoftWindows.LKG.SpeechRuntime*: $_" }

# Action 728: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*ContentDeliveryManager*' -or $_.PackageFullName -like '*ContentDeliveryManager*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*ContentDeliveryManager*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *ContentDeliveryManager*: $_" }

# Action 729: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.ECApp*' -or $_.PackageFullName -like '*Microsoft.ECApp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.ECApp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.ECApp*: $_" }

# Action 730: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Windows.CBSPreview*' -or $_.PackageFullName -like '*Windows.CBSPreview*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Windows.CBSPreview*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Windows.CBSPreview*: $_" }

# Action 731: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Tasbar*' -or $_.PackageFullName -like '*Tasbar*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Tasbar*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Tasbar*: $_" }

# Action 732: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.Lockapp*' -or $_.PackageFullName -like '*Microsoft.Lockapp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.Lockapp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.Lockapp*: $_" }

# Action 733: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.BioEnrollment*' -or $_.PackageFullName -like '*Microsoft.BioEnrollment*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.BioEnrollment*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.BioEnrollment*: $_" }

# Action 734: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*c5e2524a-ea46-4f67-841f-6a9465d9d515*' -or $_.PackageFullName -like '*c5e2524a-ea46-4f67-841f-6a9465d9d515*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*c5e2524a-ea46-4f67-841f-6a9465d9d515*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *c5e2524a-ea46-4f67-841f-6a9465d9d515*: $_" }

# Action 735: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE*' -or $_.PackageFullName -like '*F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE*: $_" }

# Action 736: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.Windows.SecureAssessmentBrowser*' -or $_.PackageFullName -like '*Microsoft.Windows.SecureAssessmentBrowser*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.Windows.SecureAssessmentBrowser*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.Windows.SecureAssessmentBrowser*: $_" }

# Action 737: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.Windows.AssignedAccessLockApp*' -or $_.PackageFullName -like '*Microsoft.Windows.AssignedAccessLockApp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.Windows.AssignedAccessLockApp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.Windows.AssignedAccessLockApp*: $_" }

# Action 738: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*NarratorQuickStart*' -or $_.PackageFullName -like '*NarratorQuickStart*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*NarratorQuickStart*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *NarratorQuickStart*: $_" }

# Action 739: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.AsyncTextService*' -or $_.PackageFullName -like '*Microsoft.AsyncTextService*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.AsyncTextService*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.AsyncTextService*: $_" }

# Action 740: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*XGpuEjectDialog*' -or $_.PackageFullName -like '*XGpuEjectDialog*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*XGpuEjectDialog*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *XGpuEjectDialog*: $_" }

# Action 741: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*PeopleExperienceHost*' -or $_.PackageFullName -like '*PeopleExperienceHost*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*PeopleExperienceHost*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *PeopleExperienceHost*: $_" }

# Action 742: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*MicrosoftWindows.Client.AIX*' -or $_.PackageFullName -like '*MicrosoftWindows.Client.AIX*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*MicrosoftWindows.Client.AIX*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *MicrosoftWindows.Client.AIX*: $_" }

# Action 743: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*ParentalControls*' -or $_.PackageFullName -like '*ParentalControls*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*ParentalControls*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *ParentalControls*: $_" }

# Action 744: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.Windows.CallingShellApp*' -or $_.PackageFullName -like '*Microsoft.Windows.CallingShellApp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.Windows.CallingShellApp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.Windows.CallingShellApp*: $_" }

# Action 745: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*MicrosoftWindows.CrossDevice*' -or $_.PackageFullName -like '*MicrosoftWindows.CrossDevice*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*MicrosoftWindows.CrossDevice*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *MicrosoftWindows.CrossDevice*: $_" }

# Action 746: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'OutlookForWindows*' -or $_.PackageFullName -like 'OutlookForWindows*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'OutlookForWindows*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for OutlookForWindows*: $_" }

# Action 747: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftCorporationII.QuickAssist*' -or $_.PackageFullName -like 'MicrosoftCorporationII.QuickAssist*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftCorporationII.QuickAssist*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftCorporationII.QuickAssist*: $_" }

# Action 748: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.ScreenSketch*' -or $_.PackageFullName -like 'Microsoft.ScreenSketch*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.ScreenSketch*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.ScreenSketch*: $_" }

# Action 749: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Disney.37853FC22B2CE*' -or $_.PackageFullName -like 'Disney.37853FC22B2CE*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Disney.37853FC22B2CE*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Disney.37853FC22B2CE*: $_" }

# Action 750: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'SpotifyAB.SpotifyMusic*' -or $_.PackageFullName -like 'SpotifyAB.SpotifyMusic*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'SpotifyAB.SpotifyMusic*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for SpotifyAB.SpotifyMusic*: $_" }

# Action 751: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.549981C3F5F10*' -or $_.PackageFullName -like 'Microsoft.549981C3F5F10*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.549981C3F5F10*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.549981C3F5F10*: $_" }

# Action 752: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'microsoft.windowscommunicationsapps*' -or $_.PackageFullName -like 'microsoft.windowscommunicationsapps*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'microsoft.windowscommunicationsapps*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for microsoft.windowscommunicationsapps*: $_" }

# Action 753: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.MSPaint*' -or $_.PackageFullName -like 'Microsoft.MSPaint*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.MSPaint*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.MSPaint*: $_" }

# Action 754: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Getstarted*' -or $_.PackageFullName -like 'Microsoft.Getstarted*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.Getstarted*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.Getstarted*: $_" }

# Action 755: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.ZuneVideo*' -or $_.PackageFullName -like 'Microsoft.ZuneVideo*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.ZuneVideo*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.ZuneVideo*: $_" }

# Action 756: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftCorporationII.MicrosoftFamily*' -or $_.PackageFullName -like 'MicrosoftCorporationII.MicrosoftFamily*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftCorporationII.MicrosoftFamily*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftCorporationII.MicrosoftFamily*: $_" }

# Action 757: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.MixedReality.Portal*' -or $_.PackageFullName -like 'Microsoft.MixedReality.Portal*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.MixedReality.Portal*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.MixedReality.Portal*: $_" }

# Action 758: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Windows.DevHome*' -or $_.PackageFullName -like 'Microsoft.Windows.DevHome*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.Windows.DevHome*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.Windows.DevHome*: $_" }

# Action 759: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.BingWeather*' -or $_.PackageFullName -like 'Microsoft.BingWeather*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.BingWeather*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.BingWeather*: $_" }

# Action 760: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.BingSearch*' -or $_.PackageFullName -like 'Microsoft.BingSearch*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.BingSearch*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.BingSearch*: $_" }

# Action 761: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Windows.Photos*' -or $_.PackageFullName -like 'Microsoft.Windows.Photos*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.Windows.Photos*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.Windows.Photos*: $_" }

# Action 762: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.BingNews*' -or $_.PackageFullName -like 'Microsoft.BingNews*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.BingNews*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.BingNews*: $_" }

# Action 763: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.OutlookForWindows*' -or $_.PackageFullName -like 'Microsoft.OutlookForWindows*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.OutlookForWindows*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.OutlookForWindows*: $_" }

# Action 764: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.GetHelp*' -or $_.PackageFullName -like 'Microsoft.GetHelp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.GetHelp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.GetHelp*: $_" }

# Action 765: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Microsoft3DViewer*' -or $_.PackageFullName -like 'Microsoft.Microsoft3DViewer*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.Microsoft3DViewer*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.Microsoft3DViewer*: $_" }

# Action 766: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.MicrosoftOfficeHub*' -or $_.PackageFullName -like 'Microsoft.MicrosoftOfficeHub*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.MicrosoftOfficeHub*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.MicrosoftOfficeHub*: $_" }

# Action 767: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.MicrosoftSolitaireCollection*' -or $_.PackageFullName -like 'Microsoft.MicrosoftSolitaireCollection*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.MicrosoftSolitaireCollection*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.MicrosoftSolitaireCollection*: $_" }

# Action 768: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.MicrosoftStickyNotes*' -or $_.PackageFullName -like 'Microsoft.MicrosoftStickyNotes*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.MicrosoftStickyNotes*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.MicrosoftStickyNotes*: $_" }

# Action 769: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Office.OneNote*' -or $_.PackageFullName -like 'Microsoft.Office.OneNote*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.Office.OneNote*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.Office.OneNote*: $_" }

# Action 770: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.People*' -or $_.PackageFullName -like 'Microsoft.People*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.People*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.People*: $_" }

# Action 771: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.PowerAutomateDesktop*' -or $_.PackageFullName -like 'Microsoft.PowerAutomateDesktop*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.PowerAutomateDesktop*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.PowerAutomateDesktop*: $_" }

# Action 772: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.SkypeApp*' -or $_.PackageFullName -like 'Microsoft.SkypeApp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.SkypeApp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.SkypeApp*: $_" }

# Action 773: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.Todos*' -or $_.PackageFullName -like 'Microsoft.Todos*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.Todos*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.Todos*: $_" }

# Action 774: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftWindows.CrossDevice*' -or $_.PackageFullName -like 'MicrosoftWindows.CrossDevice*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftWindows.CrossDevice*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftWindows.CrossDevice*: $_" }

# Action 775: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.WindowsAlarms*' -or $_.PackageFullName -like 'Microsoft.WindowsAlarms*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.WindowsAlarms*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.WindowsAlarms*: $_" }

# Action 776: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.WindowsCamera*' -or $_.PackageFullName -like 'Microsoft.WindowsCamera*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.WindowsCamera*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.WindowsCamera*: $_" }

# Action 777: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.WindowsFeedbackHub*' -or $_.PackageFullName -like 'Microsoft.WindowsFeedbackHub*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.WindowsFeedbackHub*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.WindowsFeedbackHub*: $_" }

# Action 778: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.WindowsMaps*' -or $_.PackageFullName -like 'Microsoft.WindowsMaps*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.WindowsMaps*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.WindowsMaps*: $_" }

# Action 779: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.WindowsSoundRecorder*' -or $_.PackageFullName -like 'Microsoft.WindowsSoundRecorder*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.WindowsSoundRecorder*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.WindowsSoundRecorder*: $_" }

# Action 780: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Microsoft.*MicrosoftWindows.Client.AIX*' -or $_.PackageFullName -like 'Microsoft.*MicrosoftWindows.Client.AIX*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.*MicrosoftWindows.Client.AIX*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for Microsoft.*MicrosoftWindows.Client.AIX*: $_" }

# Action 781: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftWindows.Client.CoreAI*' -or $_.PackageFullName -like 'MicrosoftWindows.Client.CoreAI*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftWindows.Client.CoreAI*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftWindows.Client.CoreAI*: $_" }

# Action 782: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Livtop*' -or $_.PackageFullName -like '*Livtop*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Livtop*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Livtop*: $_" }

# Action 783: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*InpApp*' -or $_.PackageFullName -like '*InpApp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*InpApp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *InpApp*: $_" }

# Action 784: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Speion*' -or $_.PackageFullName -like '*Speion*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Speion*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Speion*: $_" }

# Action 785: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Voiess*' -or $_.PackageFullName -like '*Voiess*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Voiess*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Voiess*: $_" }

# Action 786: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Filons*' -or $_.PackageFullName -like '*Filons*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Filons*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Filons*: $_" }

# Action 787: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MicrosoftWindows.Client.WebExperience*' -or $_.PackageFullName -like 'MicrosoftWindows.Client.WebExperience*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'MicrosoftWindows.Client.WebExperience*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for MicrosoftWindows.Client.WebExperience*: $_" }

# Action 788: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*CredDialogHost*' -or $_.PackageFullName -like '*CredDialogHost*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*CredDialogHost*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *CredDialogHost*: $_" }

# Action 789: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*AsyncTextService*' -or $_.PackageFullName -like '*AsyncTextService*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*AsyncTextService*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *AsyncTextService*: $_" }

# Action 790: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*PinningConfirmationDialog*' -or $_.PackageFullName -like '*PinningConfirmationDialog*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*PinningConfirmationDialog*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *PinningConfirmationDialog*: $_" }

# Action 791: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*client.oobe*' -or $_.PackageFullName -like '*client.oobe*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*client.oobe*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *client.oobe*: $_" }

# Action 792: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*client.photon*' -or $_.PackageFullName -like '*client.photon*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*client.photon*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *client.photon*: $_" }

# Action 793: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*OOBENetworkCaptivePortal*' -or $_.PackageFullName -like '*OOBENetworkCaptivePortal*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*OOBENetworkCaptivePortal*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *OOBENetworkCaptivePortal*: $_" }

# Action 794: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*OOBENetworkConnectionFlow*' -or $_.PackageFullName -like '*OOBENetworkConnectionFlow*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*OOBENetworkConnectionFlow*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *OOBENetworkConnectionFlow*: $_" }

# Action 795: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*CapturePicker*' -or $_.PackageFullName -like '*CapturePicker*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*CapturePicker*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *CapturePicker*: $_" }

# Action 796: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*ScreenClipping*' -or $_.PackageFullName -like '*ScreenClipping*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*ScreenClipping*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *ScreenClipping*: $_" }

# Action 797: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*WindowsBackup*' -or $_.PackageFullName -like '*WindowsBackup*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*WindowsBackup*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *WindowsBackup*: $_" }

# Action 798: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*DesktopSpotlight*' -or $_.PackageFullName -like '*DesktopSpotlight*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*DesktopSpotlight*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *DesktopSpotlight*: $_" }

# Action 799: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*IrisService*' -or $_.PackageFullName -like '*IrisService*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*IrisService*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *IrisService*: $_" }

# Action 800: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*CopilotNudges*' -or $_.PackageFullName -like '*CopilotNudges*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*CopilotNudges*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *CopilotNudges*: $_" }

# Action 801: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*CrossDeviceResume*' -or $_.PackageFullName -like '*CrossDeviceResume*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*CrossDeviceResume*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *CrossDeviceResume*: $_" }

# Action 802: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*FamilyValueProp*' -or $_.PackageFullName -like '*FamilyValueProp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*FamilyValueProp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *FamilyValueProp*: $_" }

# Action 803: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*WebExperienceHost*' -or $_.PackageFullName -like '*WebExperienceHost*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*WebExperienceHost*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *WebExperienceHost*: $_" }

# Action 804: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*PackageMetadata' -or $_.PackageFullName -like '*PackageMetadata' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*PackageMetadata' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *PackageMetadata: $_" }

# Action 805: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.AppListBackup*' -or $_.PackageFullName -like '*Global.AppListBackup*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.AppListBackup*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.AppListBackup*: $_" }

# Action 806: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.DesktopStickerEditor*' -or $_.PackageFullName -like '*Global.DesktopStickerEditor*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.DesktopStickerEditor*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.DesktopStickerEditor*: $_" }

# Action 807: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*DesktopStickerEditorCentennial*' -or $_.PackageFullName -like '*DesktopStickerEditorCentennial*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*DesktopStickerEditorCentennial*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *DesktopStickerEditorCentennial*: $_" }

# Action 808: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.DesktopVisual*' -or $_.PackageFullName -like '*Global.DesktopVisual*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.DesktopVisual*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.DesktopVisual*: $_" }

# Action 809: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.LiveCaptionsDesktop*' -or $_.PackageFullName -like '*Global.LiveCaptionsDesktop*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.LiveCaptionsDesktop*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.LiveCaptionsDesktop*: $_" }

# Action 810: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*LogonWebHost*' -or $_.PackageFullName -like '*LogonWebHost*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*LogonWebHost*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *LogonWebHost*: $_" }

# Action 811: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*VisualAssist*' -or $_.PackageFullName -like '*VisualAssist*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*VisualAssist*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *VisualAssist*: $_" }

# Action 812: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.FeatureDiscoverability*' -or $_.PackageFullName -like '*Global.FeatureDiscoverability*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.FeatureDiscoverability*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.FeatureDiscoverability*: $_" }

# Action 813: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.MicrosoftGraphRecentItemsManager*' -or $_.PackageFullName -like '*Global.MicrosoftGraphRecentItemsManager*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.MicrosoftGraphRecentItemsManager*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.MicrosoftGraphRecentItemsManager*: $_" }

# Action 814: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.PersonaCardManager*' -or $_.PackageFullName -like '*Global.PersonaCardManager*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.PersonaCardManager*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.PersonaCardManager*: $_" }

# Action 815: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.RulesEngine*' -or $_.PackageFullName -like '*Global.RulesEngine*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.RulesEngine*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.RulesEngine*: $_" }

# Action 816: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.WindowsMigration*' -or $_.PackageFullName -like '*Global.WindowsMigration*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.WindowsMigration*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.WindowsMigration*: $_" }

# Action 817: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*MiniSearchUI*' -or $_.PackageFullName -like '*MiniSearchUI*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*MiniSearchUI*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *MiniSearchUI*: $_" }

# Action 818: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*FESearchUI*' -or $_.PackageFullName -like '*FESearchUI*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*FESearchUI*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *FESearchUI*: $_" }

# Action 819: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.SpeechRecognizerExtension*' -or $_.PackageFullName -like '*Global.SpeechRecognizerExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.SpeechRecognizerExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.SpeechRecognizerExtension*: $_" }

# Action 820: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.TwinSxS*' -or $_.PackageFullName -like '*Global.TwinSxS*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.TwinSxS*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.TwinSxS*: $_" }

# Action 821: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.SpeechSynthesizerExtension*' -or $_.PackageFullName -like '*Global.SpeechSynthesizerExtension*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.SpeechSynthesizerExtension*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.SpeechSynthesizerExtension*: $_" }

# Action 822: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.ValueBanner*' -or $_.PackageFullName -like '*Global.ValueBanner*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.ValueBanner*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.ValueBanner*: $_" }

# Action 823: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.WindowsPeopleExperience*' -or $_.PackageFullName -like '*Global.WindowsPeopleExperience*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.WindowsPeopleExperience*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.WindowsPeopleExperience*: $_" }

# Action 824: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.ExperienceExtensions*' -or $_.PackageFullName -like '*Global.ExperienceExtensions*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.ExperienceExtensions*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.ExperienceExtensions*: $_" }

# Action 825: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.WsxPackManager*' -or $_.PackageFullName -like '*Global.WsxPackManager*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.WsxPackManager*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.WsxPackManager*: $_" }

# Action 826: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.BackupBanner*' -or $_.PackageFullName -like '*Global.BackupBanner*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.BackupBanner*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.BackupBanner*: $_" }

# Action 827: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.VoiceAccessHost*' -or $_.PackageFullName -like '*Global.VoiceAccessHost*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.VoiceAccessHost*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.VoiceAccessHost*: $_" }

# Action 828: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.VoiceAccessPlugin*' -or $_.PackageFullName -like '*Global.VoiceAccessPlugin*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.VoiceAccessPlugin*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.VoiceAccessPlugin*: $_" }

# Action 829: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*CrossDeviceResumeApp*' -or $_.PackageFullName -like '*CrossDeviceResumeApp*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*CrossDeviceResumeApp*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *CrossDeviceResumeApp*: $_" }

# Action 830: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.DragTray*' -or $_.PackageFullName -like '*Global.DragTray*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.DragTray*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.DragTray*: $_" }

# Action 831: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.LockCanvas*' -or $_.PackageFullName -like '*Global.LockCanvas*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.LockCanvas*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.LockCanvas*: $_" }

# Action 832: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.WidgetDataModel*' -or $_.PackageFullName -like '*Global.WidgetDataModel*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.WidgetDataModel*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.WidgetDataModel*: $_" }

# Action 833: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.WidgetPicker*' -or $_.PackageFullName -like '*Global.WidgetPicker*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.WidgetPicker*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.WidgetPicker*: $_" }

# Action 834: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.WidgetViewUWP*' -or $_.PackageFullName -like '*Global.WidgetViewUWP*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.WidgetViewUWP*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.WidgetViewUWP*: $_" }

# Action 835: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.WidgetViewWinUI3*' -or $_.PackageFullName -like '*Global.WidgetViewWinUI3*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.WidgetViewWinUI3*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.WidgetViewWinUI3*: $_" }

# Action 836: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.wsw*' -or $_.PackageFullName -like '*Global.wsw*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.wsw*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.wsw*: $_" }

# Action 837: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*ActionRuntime*' -or $_.PackageFullName -like '*ActionRuntime*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*ActionRuntime*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *ActionRuntime*: $_" }

# Action 838: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.ActionUI*' -or $_.PackageFullName -like '*Global.ActionUI*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.ActionUI*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.ActionUI*: $_" }

# Action 839: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.ActionUi.Common*' -or $_.PackageFullName -like '*Global.ActionUi.Common*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.ActionUi.Common*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.ActionUi.Common*: $_" }

# Action 840: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*SoftLanding*' -or $_.PackageFullName -like '*SoftLanding*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*SoftLanding*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *SoftLanding*: $_" }

# Action 841: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*DiscoveryHub*' -or $_.PackageFullName -like '*DiscoveryHub*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*DiscoveryHub*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *DiscoveryHub*: $_" }

# Action 842: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*DiscoveryHubWidgetHost*' -or $_.PackageFullName -like '*DiscoveryHubWidgetHost*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*DiscoveryHubWidgetHost*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *DiscoveryHubWidgetHost*: $_" }

# Action 843: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.PeopleExperiencePlatform*' -or $_.PackageFullName -like '*Global.PeopleExperiencePlatform*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.PeopleExperiencePlatform*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.PeopleExperiencePlatform*: $_" }

# Action 844: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.PeopleWidget*' -or $_.PackageFullName -like '*Global.PeopleWidget*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.PeopleWidget*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.PeopleWidget*: $_" }

# Action 845: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.WindowsPersonaCard*' -or $_.PackageFullName -like '*Global.WindowsPersonaCard*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.WindowsPersonaCard*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.WindowsPersonaCard*: $_" }

# Action 846: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.AccountDialog*' -or $_.PackageFullName -like '*Global.AccountDialog*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.AccountDialog*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.AccountDialog*: $_" }

# Action 847: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.Accounts*' -or $_.PackageFullName -like '*Global.Accounts*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.Accounts*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.Accounts*: $_" }

# Action 848: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*SettingsModelService*' -or $_.PackageFullName -like '*SettingsModelService*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*SettingsModelService*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *SettingsModelService*: $_" }

# Action 849: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Global.StartMenu*' -or $_.PackageFullName -like '*Global.StartMenu*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Global.StartMenu*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Global.StartMenu*: $_" }

# Action 850: !powerShell
$__cmd = @'
Get-AppxPackage Microsoft.YourPhone* | Remove-AppxPackage; Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'Microsoft.YourPhone' } | Remove-AppxProvisionedPackage -Online
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 851: !powerShell
$__cmd = @'
Get-AppxPackage MicrosoftTeams* | Remove-AppxPackage; Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'MicrosoftTeams' } | Remove-AppxProvisionedPackage -Online
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 852: !powerShell
$__cmd = @'
Get-AppxPackage Microsoft.Windows.DevHome* | Remove-AppxPackage; Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'Microsoft.Windows.DevHome' } | Remove-AppxProvisionedPackage -Online
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 853: !powerShell
$__cmd = @'
Get-AppxPackage MicrosoftWindows.CrossDevice* | Remove-AppxPackage; Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'MicrosoftWindows.CrossDevice' } | Remove-AppxProvisionedPackage -Online
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 854: !powerShell
$__cmd = @'
$a = """$([Environment]::GetFolderPath('Windows'))\\oldpackages.txt"""; (diff (gc $a) ((Get-AppxPackage).PackageFamilyName)).InputObject | Foreach-Object { New-Item -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Appx\\AppxAllUserStore\\Deprovisioned' -Name $_ -Force | Out-Null }; Remove-Item $a -Force
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 855: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*MicrosoftWindows.Client.CBS*' -or $_.PackageFullName -like '*MicrosoftWindows.Client.CBS*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*MicrosoftWindows.Client.CBS*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *MicrosoftWindows.Client.CBS*: $_" }

# Action 856: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.Windows.Search*' -or $_.PackageFullName -like '*Microsoft.Windows.Search*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.Windows.Search*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.Windows.Search*: $_" }

# Action 857: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Microsoft.Windows.SecHealthUI*' -or $_.PackageFullName -like '*Microsoft.Windows.SecHealthUI*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Microsoft.Windows.SecHealthUI*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *Microsoft.Windows.SecHealthUI*: $_" }

# Action 858: !appx
try { Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*StartMenuExperienceHost*' -or $_.PackageFullName -like '*StartMenuExperienceHost*' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*StartMenuExperienceHost*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null } } catch { Write-Warning "Appx removal failed for *StartMenuExperienceHost*: $_" }

# Action 859: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\MicrosoftWindows.Client.CBS_cw5n1h2txyewy' 'Disabled' 'REG_DWORD' '1'

# Action 860: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\MicrosoftWindows.Client.CBS_cw5n1h2txyewy' 'DisabledByUser' 'REG_DWORD' '1'

# Action 861: !status
Write-Status 'Configuring Services'

# Action 862: !service
try { Set-Service -Name 'BDESVC' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service BDESVC: $_" }

# Action 863: !service
try { Set-Service -Name 'CldFlt' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service CldFlt: $_" }

# Action 864: !service
try { Set-Service -Name 'UCPD' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service UCPD: $_" }

# Action 865: !service
try { Set-Service -Name 'onesyncsvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service onesyncsvc: $_" }

# Action 866: !service
try { Set-Service -Name 'ShellHWDetection' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service ShellHWDetection: $_" }

# Action 867: !service
try { Set-Service -Name 'sysmain' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service sysmain: $_" }

# Action 868: !service
try { Set-Service -Name 'themes' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service themes: $_" }

# Action 869: !service
try { Set-Service -Name 'Beep' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service Beep: $_" }

# Action 870: !service
try { Set-Service -Name 'CloudIdSvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service CloudIdSvc: $_" }

# Action 871: !service
try { Set-Service -Name 'WPCMonSvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service WPCMonSvc: $_" }

# Action 872: !service
try { Set-Service -Name 'MapsBroker' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service MapsBroker: $_" }

# Action 873: !service
try { Set-Service -Name 'CloudBackupRestoreSvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service CloudBackupRestoreSvc: $_" }

# Action 874: !service
try { Set-Service -Name 'fhsvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service fhsvc: $_" }

# Action 875: !service
try { Set-Service -Name 'semgrsvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service semgrsvc: $_" }

# Action 876: !service
try { Set-Service -Name 'wisvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service wisvc: $_" }

# Action 877: !service
try { Set-Service -Name 'Telemetry' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service Telemetry: $_" }

# Action 878: !service
try { Set-Service -Name 'WdiSystemHost' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service WdiSystemHost: $_" }

# Action 879: !service
try { Set-Service -Name 'WdiServiceHost' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service WdiServiceHost: $_" }

# Action 880: !service
try { Set-Service -Name 'troubleshootingsvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service troubleshootingsvc: $_" }

# Action 881: !service
try { Set-Service -Name 'diagnosticshub.standardcollector.service' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service diagnosticshub.standardcollector.service: $_" }

# Action 882: !service
try { Set-Service -Name 'diagsvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service diagsvc: $_" }

# Action 883: !service
try { Set-Service -Name 'intelpmt' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service intelpmt: $_" }

# Action 884: !service
try { Set-Service -Name 'pla' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service pla: $_" }

# Action 885: !service
try { Set-Service -Name 'WerSvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service WerSvc: $_" }

# Action 886: !service
try { Set-Service -Name 'svsvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service svsvc: $_" }

# Action 887: !service
try { Set-Service -Name 'diagtrack' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service diagtrack: $_" }

# Action 888: !service
try { Set-Service -Name 'wercplsupport' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service wercplsupport: $_" }

# Action 889: !service
try { Set-Service -Name 'kdnic' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service kdnic: $_" }

# Action 890: !service
try { Set-Service -Name 'Wecsvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service Wecsvc: $_" }

# Action 891: !service
try { Set-Service -Name 'dps' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service dps: $_" }

# Action 892: !service
try { Set-Service -Name 'pcasvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service pcasvc: $_" }

# Action 893: !service
try { Set-Service -Name 'dusmsvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service dusmsvc: $_" }

# Action 894: !service
try { Set-Service -Name 'ndu' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service ndu: $_" }

# Action 895: !service
try { Set-Service -Name 'DSSvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service DSSvc: $_" }

# Action 896: !service
try { Set-Service -Name 'acpipagr' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service acpipagr: $_" }

# Action 897: !service
try { Set-Service -Name 'GpuEnergyDrv' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service GpuEnergyDrv: $_" }

# Action 898: !service
try { Set-Service -Name 'AcpiPmi' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service AcpiPmi: $_" }

# Action 899: !service
try { Set-Service -Name 'PRM' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service PRM: $_" }

# Action 900: !service
try { Set-Service -Name 'acpitime' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service acpitime: $_" }

# Action 901: !service
try { Set-Service -Name 'bam' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service bam: $_" }

# Action 902: !service
try { Set-Service -Name 'dam' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service dam: $_" }

# Action 903: !service
try { Set-Service -Name 'spooler' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service spooler: $_" }

# Action 904: !service
try { Set-Service -Name 'printworkflowusersvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service printworkflowusersvc: $_" }

# Action 905: !service
try { Set-Service -Name 'stisvc' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service stisvc: $_" }

# Action 906: !service
try { Set-Service -Name 'PrintNotify' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service PrintNotify: $_" }

# Action 907: !service
try { Set-Service -Name 'usbprint' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service usbprint: $_" }

# Action 908: !service
try { Set-Service -Name 'McpManagementService' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service McpManagementService: $_" }

# Action 909: !service
try { Set-Service -Name 'PrintScanBrokerService' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service PrintScanBrokerService: $_" }

# Action 910: !service
try { Set-Service -Name 'PrintDeviceConfigurationService' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service PrintDeviceConfigurationService: $_" }

# Action 911: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"Printing-PrintToPDFServices-Features" /NoRestart'

# Action 912: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"Printing-Foundation-Features" /NoRestart'

# Action 913: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"Printing-Foundation-InternetPrinting-Client" /NoRestart'

# Action 914: !status
Write-Status 'Configuring BCDEDIT'

# Action 915: !run
Invoke-Native 'bcdedit' '/set {current} description "hexa"'

# Action 916: !run
Invoke-Native 'bcdedit' '/set bootmenupolicy Legacy'

# Action 917: !run
Invoke-Native 'bcdedit' '/set disabledynamictick yes'

# Action 918: !run
Invoke-Native 'bcdedit' '/deletevalue useplatformclock'

# Action 919: !run
Invoke-Native 'bcdedit' '/deletevalue useplatformtick'

# Action 920: !run
Invoke-Native 'bcdedit' '/set {current} nx optin'

# Action 921: !run
Invoke-Native 'bcdedit' '/set {current} recoveryenabled no'

# Action 922: !run
Invoke-Native 'bcdedit' '/set {current} disableelamdrivers yes'

# Action 923: !run
Invoke-Native 'bcdedit' '/set {current} integrityservices disable'

# Action 924: !run
Invoke-Native 'powercfg' '-h off'

# Action 925: !run
Invoke-Native 'label' '%systemdrive% hexa'

# Action 926: !status
Write-Status 'Disabling HyperV'

# Action 927: !service
try { Set-Service -Name 'vmbushid' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmbushid: $_" }

# Action 928: !service
try { Set-Service -Name 'HvHost' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service HvHost: $_" }

# Action 929: !service
try { Set-Service -Name 'vmickvpexchange' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmickvpexchange: $_" }

# Action 930: !service
try { Set-Service -Name 'storflt' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service storflt: $_" }

# Action 931: !service
try { Set-Service -Name 'Vid' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service Vid: $_" }

# Action 932: !service
try { Set-Service -Name 'hvservice' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service hvservice: $_" }

# Action 933: !service
try { Set-Service -Name 'vmbus' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmbus: $_" }

# Action 934: !service
try { Set-Service -Name 'HyperVideo' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service HyperVideo: $_" }

# Action 935: !service
try { Set-Service -Name 'gencounter' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service gencounter: $_" }

# Action 936: !service
try { Set-Service -Name 'vmicguestinterface' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmicguestinterface: $_" }

# Action 937: !service
try { Set-Service -Name 'vmicshutdown' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmicshutdown: $_" }

# Action 938: !service
try { Set-Service -Name 'hyperkbd' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service hyperkbd: $_" }

# Action 939: !service
try { Set-Service -Name 'bttflt' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service bttflt: $_" }

# Action 940: !service
try { Set-Service -Name 'vmgid' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmgid: $_" }

# Action 941: !service
try { Set-Service -Name 'vmicheartbeat' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmicheartbeat: $_" }

# Action 942: !service
try { Set-Service -Name 'vmicvmsession' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmicvmsession: $_" }

# Action 943: !service
try { Set-Service -Name 'vmicrdv' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmicrdv: $_" }

# Action 944: !service
try { Set-Service -Name 'vmictimesync' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmictimesync: $_" }

# Action 945: !service
try { Set-Service -Name 'vmicvss' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vmicvss: $_" }

# Action 946: !service
try { Set-Service -Name 'vpci' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service vpci: $_" }

# Action 947: !service
try { Set-Service -Name 'storqosflt' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service storqosflt: $_" }

# Action 948: !service
try { Set-Service -Name 'ndisvirtualbus' -StartupType Disabled -ErrorAction Stop } catch { Write-Warning "Could not change service ndisvirtualbus: $_" }

# Action 949: !run
Invoke-Native 'bcdedit' '/set hypervisorlaunchtype off'

# Action 950: !run
Invoke-Native 'bcdedit' '/set vm no'

# Action 951: !run
Invoke-Native 'bcdedit' '/set vsmlaunchtype Off'

# Action 952: !run
Invoke-Native 'DISM.exe' '/Online /Disable-Feature /FeatureName:"Microsoft-Hyper-V-All" /NoRestart'

# Action 953: !powerShell
$__cmd = @'
Get-PnpDevice -FriendlyName 'NDIS Virtual Network Adapter Enumerator' -ErrorAction Ignore | Disable-PnpDevice -Confirm:$False -ErrorAction Ignore
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 954: !powerShell
$__cmd = @'
Get-PnpDevice -FriendlyName 'Microsoft Hyper-V Virtualization Infrastructure Driver' -ErrorAction Ignore | Disable-PnpDevice -Confirm:$False -ErrorAction Ignore
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 955: !powerShell
$__cmd = @'
Get-PnpDevice -FriendlyName 'Microsoft Hypervisor Service' -ErrorAction Ignore | Disable-PnpDevice -Confirm:$False -ErrorAction Ignore
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 956: !status
Write-Status 'Applying tweaks'

# Action 957: !powerShell
$__cmd = @'
$v=[byte[]](0,0,0,0); Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}' -EA 0 | Get-ChildItem -Inc 'PowerSettings' -EA 0 | %{ $p=$_.PSPath; 'IdlePowerState','PerformanceIdleTime','ConservationIdleTime' | %{ Set-ItemProperty -Path $p -Name $_ -Value $v -Type Binary -EA 0 } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 958: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Wdf' 'WdfGlobalLogsDisabled' 'REG_DWORD' '1'

# Action 959: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Wdf' 'WdfGlobalSleepStudyDisabled' 'REG_DWORD' '1'

# Action 960: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' 'RITdemonTimerPowerSaveElapse' 'REG_DWORD' '0'

# Action 961: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' 'RITdemonTimerPowerSaveCoalescing' 'REG_DWORD' '0'

# Action 962: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' 'ProcessDCEsInUseThreshold' 'REG_DWORD' '0'

# Action 963: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' 'DesktopHeapLogging' 'REG_DWORD' '0'

# Action 964: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\Dwm' 'DisableProjectedShadowsRendering' 'REG_DWORD' '1'

# Action 965: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 'REG_DWORD' '10'

# Action 966: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 'REG_DWORD' '36'

# Action 967: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\usbflags' 'DisableHCS0Idle' 'REG_DWORD' '1'

# Action 968: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\usbflags' 'Allow64KLowOrFullSpeedControlTransfers' 'REG_DWORD' '1'

# Action 969: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\BamThrottling' 'DisableWindowHinting' 'REG_DWORD' '1'

# Action 970: !powerShell
$__cmd = @'
Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi | ForEach-Object { $_.enable = $false; $_.psbase.put() } 2>$null | Out-Null
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 971: !powerShell
$__cmd = @'
Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Control\usbflags | Where-Object { $_.PSChildName.Length -eq 12 } | ForEach-Object { Set-ItemProperty $_.PSPath DisableLPM 1 -Type DWord -Force }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 972: !powerShell
$__cmd = @'
Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Enum -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $p = $_.PSPath; try { $props = Get-ItemProperty $p -ErrorAction Stop; if($props) { $props.PSObject.Properties | ForEach-Object { if ($_.Name -in 'EnhancedPowerManagementEnabled','AllowIdleIrpInD3','DeviceSelectiveSuspended','DeviceResetNotificationEnabled','EnableSelectiveSuspend','SelectiveSuspendEnabled','SelectiveSuspendOn','SelectiveSuspendTimeout','WaitWakeEnabled','WakeEnabled','D3ColdSupported','DisableD3Cold','WdfDirectedPowerTransitionEnable','EnableIdlePowerManagement','IdleInWorkingState','IdleTimeoutInMS','IdleTimeoutPeriodInMilliSec','MinimumIdleTimeoutInMS','EnableHIPM','EnableHDDParking','EnableDIPM','SuppressInputInCS','SystemInputSuppressionEnabled','WdfDefaultIdleInWorkingState','WdfDirectedPowerTransitionChildrenOptional','WdfUseWdfTimerForPofx','SleepstudyState') { try { Set-ItemProperty $p $_.Name 0 -Type DWord -Force -ErrorAction Stop } catch {} } elseif ($_.Name -in 'DisableIdlePowerManagement','DisableRuntimePowerManagement','EnhancedPowerManagementUseMonitor') { try { Set-ItemProperty $p $_.Name 1 -Type DWord -Force -ErrorAction Stop } catch {} } } } } catch {} }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 973: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'EnergyEstimationEnabled' 'REG_DWORD' '0'

# Action 974: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'EventProcessorEnabled' 'REG_DWORD' '0'

# Action 975: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'FxAccountingTelemetryDisabled' 'REG_DWORD' '1'

# Action 976: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'DeepIoCoalescingEnabled' 'REG_DWORD' '0'

# Action 977: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'ThermalTelemetryVerbosity' 'REG_DWORD' '0'

# Action 978: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'StandbyConnectivityGracePeriod' 'REG_DWORD' '0'

# Action 979: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'EnforceAusterityMode' 'REG_DWORD' '0'

# Action 980: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'HeteroMultiClassParkingEnabled' 'REG_DWORD' '0'

# Action 981: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabledDefault' 'REG_DWORD' '0'

# Action 982: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'SleepstudyAccountingEnabled' 'REG_DWORD' '0'

# Action 983: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'SkipHibernateMemoryMapValidation' 'REG_DWORD' '1'

# Action 984: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'HiberbootEnabled' 'REG_DWORD' '0'

# Action 985: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'CoalescingFlushInterval' 'REG_DWORD' '0'

# Action 986: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'CoalescingTimerInterval' 'REG_DWORD' '0'

# Action 987: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'MSDisabled' 'REG_DWORD' '1'

# Action 988: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'IdleProcessorsRequireQosManagement' 'REG_DWORD' '0'

# Action 989: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'DisableInboxPepGeneratedConstraints' 'REG_DWORD' '1'

# Action 990: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'IgnoreCsComplianceCheck' 'REG_DWORD' '1'

# Action 991: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'PowerWatchdogRequestQueueTimeoutMsec' 'REG_DWORD' '0'

# Action 992: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'PowerWatchdogPoCalloutTimeoutMsec' 'REG_DWORD' '0'

# Action 993: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'PowerWatchdogPowerOnGdiTimeoutMsec' 'REG_DWORD' '0'

# Action 994: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'PowerWatchdogDwmSyncFlushTimeoutMsec' 'REG_DWORD' '0'

# Action 995: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Power' 'PowerWatchdogDrvSetMonitorTimeoutMsec' 'REG_DWORD' '0'

# Action 996: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device' 'IdlePowerMode' 'REG_DWORD' '0'

# Action 997: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device' 'DisableDSTThrottle' 'REG_DWORD' '1'

# Action 998: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Storage' 'StorageD3InModernStandby' 'REG_DWORD' '0'

# Action 999: !cmd
Invoke-Cmd '(for /f "tokens=*" %s in (''reg query "HKLM\SYSTEM\CurrentControlSet\Enum" /s /f "StorPort" ^| findstr /e "StorPort" '') do Reg.exe add "%s" /v "EnableIdlePowerManagement" /t REG_DWORD /d "0" /f & Reg.exe add "%s" /v "DisableD3Cold" /t REG_DWORD /d "1" /f)'

# Action 1000: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWpbtExecution' 'REG_DWORD' '1'

# Action 1001: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'AlwaysTrackIoBoosting' 'REG_DWORD' '0'

# Action 1002: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'ForceBugcheckForDpcWatchdog' 'REG_DWORD' '0'

# Action 1003: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'EnableWerUserReporting' 'REG_DWORD' '0'

# Action 1004: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'SeLpacEnableWatsonReporting' 'REG_DWORD' '0'

# Action 1005: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'SerializeTimerExpiration' 'REG_DWORD' '1'

# Action 1006: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'EnablePerCpuClockTickScheduling' 'REG_DWORD' '1'

# Action 1007: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'TimerCheckFlags' 'REG_DWORD' '0'

# Action 1008: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'InterruptSteeringFlags' 'REG_DWORD' '1'

# Action 1009: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'ForceParkingRequested' 'REG_DWORD' '0'

# Action 1010: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'CacheAwareScheduling' 'REG_DWORD' '39'

# Action 1011: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager' 'SelfHealingEnabled' 'REG_DWORD' '0'

# Action 1012: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager' 'VirtualizationEnabled' 'REG_DWORD' '0'

# Action 1013: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager' 'FastBoot' 'REG_DWORD' '0'

# Action 1014: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager' 'BugcheckRecoveryEnabled' 'REG_DWORD' '0'

# Action 1015: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'DisablePagingExecutive' 'REG_DWORD' '1'

# Action 1016: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'DisablePageCombining' 'REG_DWORD' '1'

# Action 1017: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'TrackLockedPages' 'REG_DWORD' '0'

# Action 1018: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'PowerSettingProfile' 'REG_DWORD' '0'

# Action 1019: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'WatchdogResumeTimeout' 'REG_DWORD' '0'

# Action 1020: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'WatchdogSleepTimeout' 'REG_DWORD' '0'

# Action 1021: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'Win32CalloutWatchdogBugcheckEnabled' 'REG_DWORD' '0'

# Action 1022: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'IdleScanInterval' 'REG_DWORD' '0'

# Action 1023: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'SkipTickOverride' 'REG_DWORD' '0'

# Action 1024: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System' 'DisableDiskCounters' 'REG_DWORD' '1'

# Action 1025: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System' 'IoAllowLoadCrashDumpDriver' 'REG_DWORD' '0'

# Action 1026: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Executive' 'ForceEnableMutantAutoboost' 'REG_DWORD' '1'

# Action 1027: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows\Input\DelayZonePalmRejection' 'RejectionEnabled' 'REG_DWORD' '0'

# Action 1028: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows\Input\DelayZonePalmRejection' 'DisableTimeThreshold' 'REG_DWORD' '0'

# Action 1029: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows\Input\DelayZonePalmRejection' 'DelayZonePalmRejectionExtensionSizeDips' 'REG_DWORD' '0'

# Action 1030: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows\Input\DelayZonePalmRejection' 'DelayZonePalmRejectionThresholdMS' 'REG_DWORD' '0'

# Action 1031: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters' 'TrackNblOwner' 'REG_DWORD' '0'

# Action 1032: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters' 'DisableNDISWatchDog' 'REG_DWORD' '1'

# Action 1033: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters' 'DisableNaps' 'REG_DWORD' '1'

# Action 1034: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters' 'NoPauseOnSuspend' 'REG_DWORD' '1'

# Action 1035: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters' 'DebugLoggingMode' 'REG_DWORD' '0'

# Action 1036: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters' 'DisableWDIWatchdogForceBugcheck' 'REG_DWORD' '1'

# Action 1037: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters' 'DisableReenumerationTimeoutBugcheck' 'REG_DWORD' '1'

# Action 1038: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters' 'EnableNicAutoPowerSaverInSleepStudy' 'REG_DWORD' '0'

# Action 1039: !registryValue
Set-Reg 'HKCU\Control Panel\Mouse' 'RawMouseThrottleEnabled' 'REG_DWORD' '1'

# Action 1040: !registryValue
Set-Reg 'HKCU\Control Panel\Mouse' 'RawMouseThrottleForced' 'REG_DWORD' '1'

# Action 1041: !registryValue
Set-Reg 'HKCU\Control Panel\Mouse' 'RawMouseThrottleDuration' 'REG_DWORD' '20'

# Action 1042: !registryValue
Set-Reg 'HKCU\Control Panel\Mouse' 'RawMouseThrottleLeeway' 'REG_DWORD' '0'

# Action 1043: !registryValue
Set-Reg 'HKLM\Software\Microsoft\Input' 'InputServiceEnabled' 'REG_DWORD' '0'

# Action 1044: !registryValue
Set-Reg 'HKLM\Software\Microsoft\Input' 'InputServiceEnabledForCCI' 'REG_DWORD' '0'

# Action 1045: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile' 'DisableNotifications' 'REG_DWORD' '1'

# Action 1046: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile' 'DisableNotifications' 'REG_DWORD' '1'

# Action 1047: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile' 'DisableNotifications' 'REG_DWORD' '1'

# Action 1048: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile\Logging' 'LogDroppedPackets' 'REG_DWORD' '0'

# Action 1049: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile\Logging' 'LogSuccessfulConnections' 'REG_DWORD' '0'

# Action 1050: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging' 'LogDroppedPackets' 'REG_DWORD' '0'

# Action 1051: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging' 'LogSuccessfulConnections' 'REG_DWORD' '0'

# Action 1052: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile\Logging' 'LogDroppedPackets' 'REG_DWORD' '0'

# Action 1053: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile\Logging' 'LogSuccessfulConnections' 'REG_DWORD' '0'

# Action 1054: !registryKey
Remove-RegKey 'HKLM\System\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules'

# Action 1055: !registryKey
try { $p=Convert-RegPath 'HKLM\System\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\System\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules - $_" }

# Action 1056: !registryValue
Set-Reg 'HKLM\SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules' 'Block SearchApp' 'REG_SZ' 'v2.32|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=%SystemRoot%\SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy\SearchApp.exe|Name=Block SearchApp|Desc=Block Cortana Outbound UDP/TCP Traffic|'

# Action 1057: !registryValue
Set-Reg 'HKLM\SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules' 'Block SearchHost' 'REG_SZ' 'v2.32|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=%SystemRoot%\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\SearchHost.exe|Name=Block SearchHost|Desc=Block Cortana Outbound UDP/TCP Traffic|'

# Action 1058: !registryValue
Set-Reg 'HKLM\SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules' 'Block StartMenuExperienceHost' 'REG_SZ' 'v2.32|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=%SystemRoot%\SystemApps\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\StartMenuExperienceHost.exe|Name=Block StartMenuExperienceHost|Desc=Block Cortana Outbound UDP/TCP Traffic|'

# Action 1059: !registryValue
Set-Reg 'HKLM\SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules' 'Block SystemSettings' 'REG_SZ' 'v2.32|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=%SystemRoot%\ImmersiveControlPanel\SystemSettings.exe|Name=Block SystemSettings|Desc=Block Windows Settings Outbound UDP/TCP Traffic|'

# Action 1060: !registryValue
Set-Reg 'HKLM\SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules' 'Block Explorer' 'REG_SZ' 'v2.32|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=%SystemRoot%\explorer.exe|Name=Block Explorer|Desc=Block Explorer Outbound UDP/TCP Traffic|'

# Action 1061: !powerShell
$__cmd = @'
Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\FTH" -Name "Enabled" -Value 0 -Type DWORD; rundll32.exe fthsvc.dll,FthSysprepSpecialize
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1062: !registryValue
Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_Enabled' 'REG_DWORD' '1'

# Action 1063: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 'REG_DWORD' '0'

# Action 1064: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\GameBar' 'GamePanelStartupTipIndex' 'REG_DWORD' '3'

# Action 1065: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\GameBar' 'ShowStartupPanel' 'REG_DWORD' '0'

# Action 1066: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 'REG_DWORD' '0'

# Action 1067: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter' 'ActivationType' 'REG_DWORD' '0'

# Action 1068: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 'REG_DWORD' '0'

# Action 1069: !registryValue
Set-Reg 'HKCR\ms-gamebar' '' 'REG_SZ' 'URL:ms-gamebar'

# Action 1070: !registryValue
Set-Reg 'HKCR\ms-gamebar' 'URL Protocol' 'REG_SZ' ''

# Action 1071: !registryValue
Set-Reg 'HKCR\ms-gamebar' 'NoOpenWith' 'REG_SZ' ''

# Action 1072: !registryValue
Set-Reg 'HKCR\ms-gamebar\shell\open\command' '' 'REG_EXPAND_SZ' '%systemroot%\System32\systray.exe'

# Action 1073: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\GameBar' 'AllowAutoGameMode' 'REG_DWORD' '0'

# Action 1074: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\GameBar' 'AutoGameModeEnabled' 'REG_DWORD' '0'

# Action 1075: !cmd
Invoke-Cmd 'ren %systemroot%\system32\mobsync.exe mobsync.old'

# Action 1076: !run
Invoke-Native 'taskkill' '/im mobsync.exe /f '

# Action 1077: !status
Write-Status 'Disabling scheduled tasks'

# Action 1078: !scheduledTask

# Action 1079: !scheduledTask

# Action 1080: !scheduledTask

# Action 1081: !scheduledTask

# Action 1082: !scheduledTask

# Action 1083: !scheduledTask

# Action 1084: !scheduledTask

# Action 1085: !scheduledTask

# Action 1086: !scheduledTask

# Action 1087: !scheduledTask

# Action 1088: !scheduledTask

# Action 1089: !scheduledTask

# Action 1090: !scheduledTask

# Action 1091: !scheduledTask

# Action 1092: !scheduledTask

# Action 1093: !scheduledTask

# Action 1094: !scheduledTask

# Action 1095: !scheduledTask

# Action 1096: !scheduledTask

# Action 1097: !scheduledTask

# Action 1098: !scheduledTask

# Action 1099: !scheduledTask

# Action 1100: !scheduledTask

# Action 1101: !scheduledTask

# Action 1102: !scheduledTask

# Action 1103: !scheduledTask

# Action 1104: !scheduledTask

# Action 1105: !scheduledTask

# Action 1106: !scheduledTask

# Action 1107: !scheduledTask

# Action 1108: !scheduledTask

# Action 1109: !scheduledTask

# Action 1110: !scheduledTask

# Action 1111: !scheduledTask

# Action 1112: !scheduledTask

# Action 1113: !scheduledTask

# Action 1114: !scheduledTask

# Action 1115: !scheduledTask

# Action 1116: !scheduledTask

# Action 1117: !scheduledTask

# Action 1118: !scheduledTask

# Action 1119: !scheduledTask

# Action 1120: !scheduledTask

# Action 1121: !scheduledTask

# Action 1122: !scheduledTask

# Action 1123: !scheduledTask

# Action 1124: !scheduledTask

# Action 1125: !scheduledTask

# Action 1126: !scheduledTask

# Action 1127: !scheduledTask

# Action 1128: !scheduledTask

# Action 1129: !scheduledTask

# Action 1130: !scheduledTask

# Action 1131: !scheduledTask

# Action 1132: !scheduledTask

# Action 1133: !scheduledTask

# Action 1134: !scheduledTask

# Action 1135: !scheduledTask

# Action 1136: !scheduledTask

# Action 1137: !scheduledTask

# Action 1138: !scheduledTask

# Action 1139: !scheduledTask

# Action 1140: !scheduledTask

# Action 1141: !scheduledTask

# Action 1142: !scheduledTask

# Action 1143: !scheduledTask

# Action 1144: !scheduledTask

# Action 1145: !scheduledTask

# Action 1146: !scheduledTask

# Action 1147: !scheduledTask

# Action 1148: !scheduledTask

# Action 1149: !scheduledTask

# Action 1150: !scheduledTask

# Action 1151: !scheduledTask

# Action 1152: !scheduledTask

# Action 1153: !scheduledTask

# Action 1154: !scheduledTask

# Action 1155: !scheduledTask

# Action 1156: !scheduledTask

# Action 1157: !scheduledTask

# Action 1158: !scheduledTask

# Action 1159: !scheduledTask

# Action 1160: !scheduledTask

# Action 1161: !scheduledTask

# Action 1162: !scheduledTask

# Action 1163: !scheduledTask

# Action 1164: !scheduledTask

# Action 1165: !scheduledTask

# Action 1166: !scheduledTask

# Action 1167: !scheduledTask

# Action 1168: !scheduledTask

# Action 1169: !scheduledTask

# Action 1170: !scheduledTask

# Action 1171: !scheduledTask

# Action 1172: !scheduledTask

# Action 1173: !scheduledTask

# Action 1174: !scheduledTask

# Action 1175: !scheduledTask

# Action 1176: !scheduledTask

# Action 1177: !scheduledTask

# Action 1178: !scheduledTask

# Action 1179: !scheduledTask

# Action 1180: !scheduledTask

# Action 1181: !scheduledTask

# Action 1182: !scheduledTask

# Action 1183: !scheduledTask

# Action 1184: !scheduledTask

# Action 1185: !scheduledTask

# Action 1186: !scheduledTask

# Action 1187: !scheduledTask

# Action 1188: !scheduledTask

# Action 1189: !scheduledTask

# Action 1190: !scheduledTask

# Action 1191: !scheduledTask

# Action 1192: !scheduledTask

# Action 1193: !scheduledTask

# Action 1194: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\Microsoft\Windows\Application Experience\' -TaskName 'MareBackup' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \Microsoft\Windows\Application Experience\MareBackup - $_" }

# Action 1195: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\Microsoft\Windows\UpdateOrchestrator\' -TaskName 'USO_UxBroker' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \Microsoft\Windows\UpdateOrchestrator\USO_UxBroker - $_" }

# Action 1196: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\Microsoft\Windows\Customer Experience Improvement Program\' -TaskName 'UsbCeip' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \Microsoft\Windows\Customer Experience Improvement Program\UsbCeip - $_" }

# Action 1197: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\Microsoft\Windows\Customer Experience Improvement Program\' -TaskName 'Consolidator' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \Microsoft\Windows\Customer Experience Improvement Program\Consolidator - $_" }

# Action 1198: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\' -TaskName 'MicrosoftEdgeUpdateTaskMachineCore' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \MicrosoftEdgeUpdateTaskMachineCore - $_" }

# Action 1199: !scheduledTask
try { Unregister-ScheduledTask -TaskPath '\' -TaskName 'MicrosoftEdgeUpdateTaskMachineUA' -Confirm:$false -ErrorAction Stop } catch { Write-Warning "Scheduled task removal failed: \MicrosoftEdgeUpdateTaskMachineUA - $_" }

# Action 1200: !status
Write-Status 'Applying Tweaks'

# Action 1201: !registryValue
Set-Reg 'HKLM\SYSTEM\ControlSet001\Control' 'SvcHostSplitThresholdInKB' 'REG_DWORD' '4294967295'

# Action 1202: !run
Invoke-Native 'wevtutil.exe' 'set-log "Microsoft-Windows-SleepStudy/Diagnostic" /e:false'

# Action 1203: !run
Invoke-Native 'wevtutil.exe' 'set-log "Microsoft-Windows-Kernel-Processor-Power/Diagnostic" /e:false'

# Action 1204: !run
Invoke-Native 'wevtutil.exe' 'set-log "Microsoft-Windows-UserModePowerService/Diagnostic" /e:false'

# Action 1205: !scheduledTask

# Action 1206: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'SleepStudyDisabled' 'REG_DWORD' '1'

# Action 1207: !registryValue
Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_DSEBehavior' 'REG_DWORD' '2'

# Action 1208: !registryValue
Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 'REG_DWORD' '0'

# Action 1209: !registryValue
Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_FSEBehavior' 'REG_DWORD' '2'

# Action 1210: !registryValue
Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_FSEBehaviorMode' 'REG_DWORD' '1'

# Action 1211: !registryValue
Set-Reg 'HKCU\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode' 'REG_DWORD' '1'

# Action 1212: !run
Invoke-Native 'fsutil' 'behavior set disablelastaccess 1'

# Action 1213: !run
Invoke-Native 'fsutil' 'behavior set disable8dot3 1'

# Action 1214: !run
Invoke-Native 'fsutil' 'behavior set disabledeletenotify 0'

# Action 1215: !run
Invoke-Native 'fsutil' 'behavior set encryptpagingfile 0'

# Action 1216: !run
Invoke-Native 'fsutil' 'behavior set disablecompression 1'

# Action 1217: !run
Invoke-Native 'fsutil' 'behavior set enablenonpagedntfs 1'

# Action 1218: !run
Invoke-Native 'fsutil' 'behavior set MemoryUsage 2'

# Action 1219: !run
Invoke-Native 'fsutil' 'usn deletejournal /d C:'

# Action 1220: !registryValue
Set-Reg 'HKCU\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings' 'REG_SZ' 'SwapEffectUpgradeEnable=1;'

# Action 1221: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 'REG_DWORD' '2'

# Action 1222: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchTreatExperimentalAsStable' 'REG_DWORD' '1'

# Action 1223: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'REG_SZ' 'Deny'

# Action 1224: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam' 'Value' 'REG_SZ' 'Allow'

# Action 1225: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone' 'Value' 'REG_SZ' 'Allow'

# Action 1226: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userNotificationListener' 'Value' 'REG_SZ' 'Deny'

# Action 1227: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\activity' 'Value' 'REG_SZ' 'Deny'

# Action 1228: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation' 'Value' 'REG_SZ' 'Deny'

# Action 1229: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks' 'Value' 'REG_SZ' 'Deny'

# Action 1230: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat' 'Value' 'REG_SZ' 'Deny'

# Action 1231: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\radios' 'Value' 'REG_SZ' 'Deny'

# Action 1232: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\bluetoothSync' 'Value' 'REG_SZ' 'Deny'

# Action 1233: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics' 'Value' 'REG_SZ' 'Deny'

# Action 1234: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess' 'Value' 'REG_SZ' 'Deny'

# Action 1235: !registryValue
Set-Reg 'HKLM\Software\Microsoft\Windows\CurrentVersion\Search' 'BackgroundAppGlobalToggle' 'REG_DWORD' '0'

# Action 1236: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableSettingSync' 'REG_DWORD' '2'

# Action 1237: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableSettingSyncUserOverride' 'REG_DWORD' '1'

# Action 1238: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableSyncOnPaidNetwork' 'REG_DWORD' '1'

# Action 1239: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableWindowsSettingSync' 'REG_DWORD' '2'

# Action 1240: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableApplicationSettingSync' 'REG_DWORD' '2'

# Action 1241: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableApplicationSettingSyncUserOverride' 'REG_DWORD' '1'

# Action 1242: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableWebBrowserSettingSync' 'REG_DWORD' '2'

# Action 1243: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableWebBrowserSettingSyncUserOverride' 'REG_DWORD' '1'

# Action 1244: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableDesktopThemeSettingSync' 'REG_DWORD' '2'

# Action 1245: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableDesktopThemeSettingSyncUserOverride' 'REG_DWORD' '1'

# Action 1246: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableCredentialsSettingSync' 'REG_DWORD' '2'

# Action 1247: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableCredentialsSettingSyncUserOverride' 'REG_DWORD' '1'

# Action 1248: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisablePersonalizationSettingSync' 'REG_DWORD' '2'

# Action 1249: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisablePersonalizationSettingSyncUserOverride' 'REG_DWORD' '1'

# Action 1250: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableStartLayoutSettingSync' 'REG_DWORD' '2'

# Action 1251: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync' 'DisableStartLayoutSettingSyncUserOverride' 'REG_DWORD' '1'

# Action 1252: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Personalization' 'Enabled' 'REG_DWORD' '0'

# Action 1253: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings' 'Enabled' 'REG_DWORD' '0'

# Action 1254: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Credentials' 'Enabled' 'REG_DWORD' '0'

# Action 1255: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Accessibility' 'Enabled' 'REG_DWORD' '0'

# Action 1256: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Windows' 'Enabled' 'REG_DWORD' '0'

# Action 1257: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync' 'SyncPolicy' 'REG_DWORD' '5'

# Action 1258: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Cellcore' 'Start' 'REG_DWORD' '0'

# Action 1259: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\CimFSUnionFS-Filter' 'Start' 'REG_DWORD' '0'

# Action 1260: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Circular Kernel Context Logger' 'Start' 'REG_DWORD' '0'

# Action 1261: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\CloudExperienceHostOOBE' 'Start' 'REG_DWORD' '0'

# Action 1262: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger' 'Start' 'REG_DWORD' '0'

# Action 1263: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger' 'Start' 'REG_DWORD' '0'

# Action 1264: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Diaglog' 'Start' 'REG_DWORD' '0'

# Action 1265: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Diagtrack-Listener' 'Start' 'REG_DWORD' '0'

# Action 1266: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\FaceTel' 'Start' 'REG_DWORD' '0'

# Action 1267: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\FilterMgr-Logger' 'Start' 'REG_DWORD' '0'

# Action 1268: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\HolographicDevice' 'Start' 'REG_DWORD' '0'

# Action 1269: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\LwtNetLog' 'Start' 'REG_DWORD' '0'

# Action 1270: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Mellanox-Kernel' 'Start' 'REG_DWORD' '0'

# Action 1271: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Microsoft-Windows-AssignedAccess-Trace' 'Start' 'REG_DWORD' '0'

# Action 1272: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Microsoft-Windows-Rdp-Graphics-RdpIdd-Trace' 'Start' 'REG_DWORD' '0'

# Action 1273: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Microsoft-Windows-Setup' 'Start' 'REG_DWORD' '0'

# Action 1274: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\NBSMLOGGER' 'Start' 'REG_DWORD' '0'

# Action 1275: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\NetCore' 'Start' 'REG_DWORD' '0'

# Action 1276: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\NtfsLog' 'Start' 'REG_DWORD' '0'

# Action 1277: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\PEAuthLog' 'Start' 'REG_DWORD' '0'

# Action 1278: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\RadioMgr' 'Start' 'REG_DWORD' '0'

# Action 1279: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\RdrLog' 'Start' 'REG_DWORD' '0'

# Action 1280: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\ReadyBoot' 'Start' 'REG_DWORD' '0'

# Action 1281: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\ReFSLog' 'Start' 'REG_DWORD' '0'

# Action 1282: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SetupPlatform' 'Start' 'REG_DWORD' '0'

# Action 1283: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SetupPlatformTel' 'Start' 'REG_DWORD' '0'

# Action 1284: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SpoolerLogger' 'Start' 'REG_DWORD' '0'

# Action 1285: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SQMLogger' 'Start' 'REG_DWORD' '0'

# Action 1286: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\TCPIPLOGGER' 'Start' 'REG_DWORD' '0'

# Action 1287: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\TileStore' 'Start' 'REG_DWORD' '0'

# Action 1288: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Tpm' 'Start' 'REG_DWORD' '0'

# Action 1289: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\UBPM' 'Start' 'REG_DWORD' '0'

# Action 1290: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WdiContextLog' 'Start' 'REG_DWORD' '0'

# Action 1291: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WFP-IPsec Trace' 'Start' 'REG_DWORD' '0'

# Action 1292: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiDriverHVSession' 'Start' 'REG_DWORD' '0'

# Action 1293: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiDriverHVSessionRepro' 'Start' 'REG_DWORD' '0'

# Action 1294: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiDriverIHVSession' 'Start' 'REG_DWORD' '0'

# Action 1295: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiDriverIHVSessionRepro' 'Start' 'REG_DWORD' '0'

# Action 1296: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiSession' 'Start' 'REG_DWORD' '0'

# Action 1297: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WMI_Traces' 'Start' 'REG_DWORD' '0'

# Action 1298: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\EventLog\Setup' 'Enabled' 'REG_DWORD' '0'

# Action 1299: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\EventLog\ProtectedEventLogging' 'EnableProtectedEventLogging' 'REG_DWORD' '0'

# Action 1300: !service

# Action 1301: !cmd
Invoke-Cmd 'w32tm /config /syncfromflags:manual /manualpeerlist:"0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org" >nul 2>&1'

# Action 1302: !cmd
Invoke-Cmd 'w32tm /config /update >nul 2>&1'

# Action 1303: !cmd
Invoke-Cmd 'w32tm /resync >nul 2>&1'

# Action 1304: !registryValue
Set-Reg 'HKCU\Control Panel\Mouse' 'MouseSpeed' 'REG_SZ' '0'

# Action 1305: !registryValue
Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold1' 'REG_SZ' '0'

# Action 1306: !registryValue
Set-Reg 'HKCU\Control Panel\Mouse' 'MouseThreshold2' 'REG_SZ' '0'

# Action 1307: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'LimitEnhancedDiagnosticDataWindowsAnalytics' 'REG_DWORD' '1'

# Action 1308: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'LimitDumpCollection' 'REG_DWORD' '1'

# Action 1309: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'LimitDiagnosticLogCollection' 'REG_DWORD' '1'

# Action 1310: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\DataCollection' 'DisableDiagnosticDataViewer' 'REG_DWORD' '1'

# Action 1311: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack' 'ShowedToastAtLevel' 'REG_DWORD' '1'

# Action 1312: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 'REG_DWORD' '0'

# Action 1313: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 'REG_DWORD' '1'

# Action 1314: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\PolicyManager\default\System\AllowTelemetry' 'value' 'REG_DWORD' '0'

# Action 1315: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchPrivacy' 'REG_DWORD' '3'

# Action 1316: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey' 'EnableEventTranscript' 'REG_DWORD' '0'

# Action 1317: !cmd
Invoke-Cmd 'setx DOTNET_CLI_TELEMETRY_OPTOUT 1 >nul'

# Action 1318: !cmd
Invoke-Cmd 'setx DOTNET_TRY_CLI_TELEMETRY_OPTOUT 1 >nul'

# Action 1319: !cmd
Invoke-Cmd 'setx CLOUDSDK_CORE_DISABLE_PROMPTS 1 >nul'

# Action 1320: !cmd
Invoke-Cmd 'setx DOCKER_CLI_TELEMETRY_OPTOUT 1 >nul'

# Action 1321: !cmd
Invoke-Cmd 'setx npm_config_loglevel silent >nul'

# Action 1322: !cmd
Invoke-Cmd 'setx VS_TELEMETRY_OPT_OUT 1 >nul'

# Action 1323: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters' 'RestrictNullSessAccess' 'REG_DWORD' '1'

# Action 1324: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 'REG_DWORD' '0'

# Action 1325: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WMDRM' 'DisableOnline' 'REG_DWORD' '1'

# Action 1326: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'NoLockScreenCamera' 'REG_DWORD' '1'

# Action 1327: !registryValue
Set-Reg 'HKCU\Control Panel\International\User Profile' 'HttpAcceptLanguageOptOut' 'REG_DWORD' '1'

# Action 1328: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata' 'PreventDeviceMetadataFromNetwork' 'REG_DWORD' '1'

# Action 1329: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'NoConnectedUser' 'REG_DWORD' '1'

# Action 1330: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Messaging' 'AllowMessageSync' 'REG_DWORD' '0'

# Action 1331: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WDI\{9c5a40da-b965-4fc3-8781-88dd50a6299d}' 'ScenarioExecutionEnabled' 'REG_DWORD' '0'

# Action 1332: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings' 'DisableSendGenericDriverNotFoundToWER' 'REG_DWORD' '1'

# Action 1333: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings' 'DisableSendRequestAdditionalSoftwareToWER' 'REG_DWORD' '1'

# Action 1334: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled' 'REG_DWORD' '1'

# Action 1335: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled' 'REG_DWORD' '1'

# Action 1336: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'DontShowUI' 'REG_DWORD' '1'

# Action 1337: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting\Consent' 'value' 'REG_SZ' '0'

# Action 1338: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'DontSendAdditionalData' 'REG_DWORD' '1'

# Action 1339: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'DontSendAdditionalData' 'REG_DWORD' '1'

# Action 1340: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'LoggingDisabled' 'REG_DWORD' '1'

# Action 1341: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'LoggingDisabled' 'REG_DWORD' '1'

# Action 1342: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting' 'DoReport' 'REG_DWORD' '0'

# Action 1343: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance' 'DisableDiagnosticTracing' 'REG_DWORD' '1'

# Action 1344: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 'REG_DWORD' '0'

# Action 1345: !registryValue
Remove-RegValue 'HKCU\SOFTWARE\Microsoft\Siuf\Rules' 'PeriodInNanoSeconds'

# Action 1346: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'DoNotShowFeedbackNotifications' 'REG_DWORD' '1'

# Action 1347: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\CDP\SettingsPage' 'BluetoothLastDisabledNearShare' 'REG_DWORD' '0'

# Action 1348: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\CDP' 'NearShareChannelUserAuthzPolicy' 'REG_DWORD' '0'

# Action 1349: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\CDP' 'CdpSessionUserAuthzPolicy' 'REG_DWORD' '1'

# Action 1350: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 'REG_DWORD' '1'

# Action 1351: !registryValue
Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 'REG_DWORD' '1'

# Action 1352: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\AppV\CEIP' 'CEIPEnable' 'REG_DWORD' '0'

# Action 1353: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows' 'CEIPEnable' 'REG_DWORD' '0'

# Action 1354: !run
Invoke-Native 'taskkill' '/im CompatTelRunner.exe /f '

# Action 1355: !file
try { $p=Resolve-Env '%systemroot%\system32\CompatTelRunner.exe'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\system32\CompatTelRunner.exe - $_" }

# Action 1356: !run
Invoke-Native 'taskkill' '/im AggregatorHost.exe /f '

# Action 1357: !file
try { $p=Resolve-Env '%systemroot%\system32\AggregatorHost.exe'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %systemroot%\system32\AggregatorHost.exe - $_" }

# Action 1358: !scheduledTask

# Action 1359: !scheduledTask

# Action 1360: !powerShell
$__cmd = @'
Get-ScheduledTask | Where-Object { $_.TaskName -like '*Microsoft Compatibility Appraiser Exp*' } | ForEach-Object { Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1361: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 'REG_DWORD' '1'

# Action 1362: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 'REG_DWORD' '1'

# Action 1363: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 'REG_DWORD' '0'

# Action 1364: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightFeatures' 'REG_DWORD' '1'

# Action 1365: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightWindowsWelcomeExperience' 'REG_DWORD' '1'

# Action 1366: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightOnActionCenter' 'REG_DWORD' '1'

# Action 1367: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightOnSettings' 'REG_DWORD' '1'

# Action 1368: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableThirdPartySuggestions' 'REG_DWORD' '1'

# Action 1369: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSpotlightCollectionOnDesktop' 'REG_DWORD' '1'

# Action 1370: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'AITEnable' 'REG_DWORD' '0'

# Action 1371: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'AllowTelemetry' 'REG_DWORD' '0'

# Action 1372: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisableEngine' 'REG_DWORD' '1'

# Action 1373: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisableInventory' 'REG_DWORD' '1'

# Action 1374: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisablePCA' 'REG_DWORD' '1'

# Action 1375: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisablePCA' 'REG_DWORD' '1'

# Action 1376: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisableUAR' 'REG_DWORD' '1'

# Action 1377: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'SbEnable' 'REG_DWORD' '0'

# Action 1378: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisablePcaUI' 'REG_DWORD' '0'

# Action 1379: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoInstrumentation' 'REG_DWORD' '1'

# Action 1380: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' 'LoggingEnabled' 'REG_DWORD' '0'

# Action 1381: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\SettingSync' 'EnableWindowsBackup' 'REG_DWORD' '0'

# Action 1382: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 'REG_DWORD' '1'

# Action 1383: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'RSoPLogging' 'REG_DWORD' '0'

# Action 1384: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\SlateLaunch' 'LaunchAT' 'REG_DWORD' '0'

# Action 1385: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableSensors' 'REG_DWORD' '1'

# Action 1386: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableSensors' 'REG_DWORD' '1'

# Action 1387: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableWindowsLocationProvider' 'REG_DWORD' '1'

# Action 1388: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocationScripting' 'REG_DWORD' '1'

# Action 1389: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocationScripting' 'REG_DWORD' '1'

# Action 1390: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 'REG_DWORD' '1'

# Action 1391: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 'REG_DWORD' '1'

# Action 1392: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\FindMyDevice' 'AllowFindMyDevice' 'REG_DWORD' '0'

# Action 1393: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\FindMyDevice' 'LocationSyncEnabled' 'REG_DWORD' '0'

# Action 1394: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowSearchToUseLocation' 'REG_DWORD' '0'

# Action 1395: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymousSAM' 'REG_DWORD' '1'

# Action 1396: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableCdp' 'REG_DWORD' '0'

# Action 1397: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform' 'NoGenTicket' 'REG_DWORD' '1'

# Action 1398: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 'REG_DWORD' '0'

# Action 1399: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 'REG_DWORD' '0'

# Action 1400: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 'REG_DWORD' '0'

# Action 1401: !registryValue
Set-Reg 'HKCU\SOFTWARE\Classes\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 'REG_DWORD' '0'

# Action 1402: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 'REG_DWORD' '1'

# Action 1403: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\AdvertisingInfo' 'DisableGraphRecentItems' 'REG_DWORD' '1'

# Action 1404: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 'REG_DWORD' '0'

# Action 1405: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\DeviceHealthAttestationService' 'EnableDeviceHealthAttestationService' 'REG_DWORD' '0'

# Action 1406: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs' 'REG_DWORD' '0'

# Action 1407: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\EdgeUI' 'DisableMFUTracking' 'REG_DWORD' '1'

# Action 1408: !registryValue
Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\EdgeUI' 'TurnOffBackstack' 'REG_DWORD' '1'

# Action 1409: !registryValue
Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\EdgeUI' 'DisableRecentApps' 'REG_DWORD' '1'

# Action 1410: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Input\Settings' 'InsightsEnabled' 'REG_DWORD' '0'

# Action 1411: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Input\TIPC' 'Enabled' 'REG_SZ' '0'

# Action 1412: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput' 'AllowLinguisticDataCollection' 'REG_DWORD' '0'

# Action 1413: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 'REG_DWORD' '1'

# Action 1414: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 'REG_DWORD' '1'

# Action 1415: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\InkingAndTypingPersonalization' 'Value' 'REG_DWORD' '0'

# Action 1416: !registryValue
Set-Reg 'HKLM\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 'REG_DWORD' '0'

# Action 1417: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 'REG_DWORD' '0'

# Action 1418: !registryValue
Set-Reg 'HKCU\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 'REG_DWORD' '0'

# Action 1419: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft' 'InputPersonalization' 'REG_DWORD' '0'

# Action 1420: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft' 'InputPersonalization' 'REG_DWORD' '0'

# Action 1421: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'ContentDeliveryAllowed' 'REG_DWORD' '0'

# Action 1422: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'FeatureManagementEnabled' 'REG_DWORD' '0'

# Action 1423: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContentEnabled' 'REG_DWORD' '0'

# Action 1424: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'OemPreInstalledAppsEnabled' 'REG_DWORD' '0'

# Action 1425: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEnabled' 'REG_DWORD' '0'

# Action 1426: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEverEnabled' 'REG_DWORD' '0'

# Action 1427: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 'REG_DWORD' '0'

# Action 1428: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-310093Enabled' 'REG_DWORD' '0'

# Action 1429: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338393Enabled' 'REG_DWORD' '0'

# Action 1430: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353694Enabled' 'REG_DWORD' '0'

# Action 1431: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353696Enabled' 'REG_DWORD' '0'

# Action 1432: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 'REG_DWORD' '0'

# Action 1433: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338387Enabled' 'REG_DWORD' '0'

# Action 1434: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenOverlayEnabled' 'REG_DWORD' '0'

# Action 1435: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled' 'REG_DWORD' '0'

# Action 1436: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 'REG_DWORD' '0'

# Action 1437: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 'REG_DWORD' '0'

# Action 1438: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' 'EnableAccountNotifications' 'REG_DWORD' '0'

# Action 1439: !registryValue
Set-Reg 'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell' 'Logo' 'REG_SZ' 'imageres.dll,-3'

# Action 1440: !cmd
Invoke-Cmd 'DEL /F /S /Q /A %LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db >nul 2>&1'

# Action 1441: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Search\Preferences' 'WholeFileSystem' 'REG_DWORD' '1'

# Action 1442: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 'REG_DWORD' '0'

# Action 1443: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'SecurityLayer' 'REG_DWORD' '0'

# Action 1444: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'UserAuthentication' 'REG_DWORD' '0'

# Action 1445: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance' 'Enabled' 'REG_DWORD' '0'

# Action 1446: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.BackupReminder' 'Enabled' 'REG_DWORD' '0'

# Action 1447: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\StorageSense' 'AllowStorageSenseGlobal' 'REG_DWORD' '0'

# Action 1448: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '04' 'REG_DWORD' '0'

# Action 1449: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 'REG_DWORD' '0'

# Action 1450: !registryValue
Set-Reg 'HKCU\Software\Classes\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 'REG_DWORD' '0'

# Action 1451: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\ValueBanner.IdealStateFeatureControlProvider' 'ActivationType' 'REG_DWORD' '0'

# Action 1452: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\HighContrast' 'Flags' 'REG_DWORD' '0'

# Action 1453: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\Keyboard Response' 'Flags' 'REG_DWORD' '0'

# Action 1454: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\MouseKeys' 'Flags' 'REG_DWORD' '0'

# Action 1455: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\StickyKeys' 'Flags' 'REG_DWORD' '0'

# Action 1456: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\ToggleKeys' 'Flags' 'REG_DWORD' '0'

# Action 1457: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\TimeOut' 'Flags' 'REG_DWORD' '0'

# Action 1458: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\SoundSentry' 'Flags' 'REG_DWORD' '0'

# Action 1459: !registryValue
Set-Reg 'HKCU\Control Panel\Keyboard' 'KeyboardDelay' 'REG_SZ' '0'

# Action 1460: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Ease of Access' 'selfscan' 'REG_DWORD' '0'

# Action 1461: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Ease of Access' 'selfvoice' 'REG_DWORD' '0'

# Action 1462: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\SoundSentry' 'WindowsEffect' 'REG_SZ' '0'

# Action 1463: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility' 'Warning Sounds' 'REG_DWORD' '0'

# Action 1464: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility' 'Sound on Activation' 'REG_DWORD' '0'

# Action 1465: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\MouseKeys' 'MaximumSpeed' 'REG_SZ' ''

# Action 1466: !registryValue
Set-Reg 'HKCU\Control Panel\Accessibility\MouseKeys' 'TimeToMaximumSpeed' 'REG_SZ' ''

# Action 1467: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\TabletTip\1.7' 'DisablePrediction' 'REG_DWORD' '1'

# Action 1468: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\TabletTip\1.7' 'DisablePrediction' 'REG_DWORD' '1'

# Action 1469: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' 'AllowSuggestedAppsInWindowsInkWorkspace' 'REG_DWORD' '0'

# Action 1470: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction' 'Enable' 'REG_SZ' 'N'

# Action 1471: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OptimalLayout' 'EnableAutoLayout' 'REG_DWORD' '0'

# Action 1472: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 'REG_DWORD' '0'

# Action 1473: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'HungAppTimeout' 'REG_SZ' '2000'

# Action 1474: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'WaitToKillAppTimeOut' 'REG_SZ' '2000'

# Action 1475: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' 'REG_SZ' '2000'

# Action 1476: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'DisableAutomaticRestartSignOn' 'REG_DWORD' '1'

# Action 1477: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'WindowArrangementActive' 'REG_SZ' '0'

# Action 1478: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Multimedia\Audio' 'UserDuckingPreference' 'REG_DWORD' '3'

# Action 1479: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates' 'ShortcutNameTemplate' 'REG_SZ' '"%s.lnk"'

# Action 1480: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 'REG_DWORD' '0'

# Action 1481: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'DelayedDesktopSwitchTimeout' 'REG_DWORD' '0'

# Action 1482: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Kernel DMA Protection' 'DeviceEnumerationPolicy' 'REG_DWORD' '0'

# Action 1483: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\BitLocker' 'PreventDeviceEncryption' 'REG_DWORD' '1'

# Action 1484: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Appx' 'AllowAutomaticAppArchiving' 'REG_DWORD' '0'

# Action 1485: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 'REG_DWORD' '1'

# Action 1486: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BackgroundAppGlobalToggle' 'REG_DWORD' '0'

# Action 1487: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Associations' 'LowRiskFileTypes' 'REG_SZ' '.avi;.bat;.cmd;.exe;.htm;.html;.lnk;.mpg;.mpeg;.mov;.mp3;.mp4;.mkv;.msi;.m3u;.rar;.reg;.txt;.vbs;.wav;.zip;.7z;.ps1'

# Action 1488: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments' 'SaveZoneInformation' 'REG_DWORD' '1'

# Action 1489: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3' '1806' 'REG_DWORD' '0'

# Action 1490: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\PolicyManager\default\Settings\AllowOnlineTips' 'value' 'REG_DWORD' '0'

# Action 1491: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'AllowOnlineTips' 'REG_DWORD' '0'

# Action 1492: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'DisableBandwidthThrottling' 'REG_DWORD' '1'

# Action 1493: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\FileHistory' 'Disabled' 'REG_DWORD' '1'

# Action 1494: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 'REG_DWORD' '1'

# Action 1495: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\EdgeUI' 'DisableHelpSticker' 'REG_DWORD' '1'

# Action 1496: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'AllowOnlineTips' 'REG_DWORD' '0'

# Action 1497: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\EditionOverrides' 'UserSetting_DisableStartupSound' 'REG_DWORD' '1'

# Action 1498: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'MaintenanceDisabled' 'REG_DWORD' '1'

# Action 1499: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Task Scheduler\Maintenance' 'WakeUp' 'REG_DWORD' '0'

# Action 1500: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\ScheduledDiagnostics' 'EnabledExecution' 'REG_DWORD' '0'

# Action 1501: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'verbosestatus' 'REG_DWORD' '1'

# Action 1502: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'AutoEndTasks' 'REG_SZ' '1'

# Action 1503: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'MultiTaskingAltTabFilter' 'REG_DWORD' '3'

# Action 1504: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoAutorun' 'REG_DWORD' '1'

# Action 1505: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' 'DisableAutoplay' 'REG_DWORD' '1'

# Action 1506: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun' 'REG_DWORD' '255'

# Action 1507: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'NoAutoplayfornonVolume' 'REG_DWORD' '1'

# Action 1508: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'DisallowShaking' 'REG_DWORD' '1'

# Action 1509: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoLowDiskSpaceChecks' 'REG_DWORD' '1'

# Action 1510: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'MenuShowDelay' 'REG_SZ' '0'

# Action 1511: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 'REG_DWORD' '1'

# Action 1512: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' 'REG_DWORD' '1'

# Action 1513: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 'REG_DWORD' '1'

# Action 1514: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\WindowsMitigation' 'UserPreference' 'REG_DWORD' '1'

# Action 1515: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableGraphRecentItems' 'REG_DWORD' '1'

# Action 1516: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'DisablePreviewDesktop' 'REG_DWORD' '1'

# Action 1517: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' 'REG_DWORD' '0'

# Action 1518: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 'REG_DWORD' '0'

# Action 1519: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'SharingWizardOn' 'REG_DWORD' '0'

# Action 1520: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ImmersiveShell' 'SignInMode' 'REG_DWORD' '1'

# Action 1521: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat' 'ChatIcon' 'REG_DWORD' '3'

# Action 1522: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn' 'REG_DWORD' '0'

# Action 1523: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 'REG_DWORD' '1'

# Action 1524: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'HideSCAMeetNow' 'REG_DWORD' '1'

# Action 1525: !registryValue
Remove-RegValue 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MultiTaskingView\AllUpView' 'Enabled'

# Action 1526: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton' 'REG_DWORD' '0'

# Action 1527: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAl' 'REG_DWORD' '0'

# Action 1528: !registryValue
Remove-RegValue 'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell' 'FolderType'

# Action 1529: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'AutoCheckSelect' 'REG_DWORD' '0'

# Action 1530: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoResolveSearch' 'REG_DWORD' '1'

# Action 1531: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoResolveTrack' 'REG_DWORD' '1'

# Action 1532: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowCloudFilesInQuickAccess' 'REG_DWORD' '0'

# Action 1533: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'MultipleInvokePromptMinimum' 'REG_DWORD' '100'

# Action 1534: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'ShowFrequent' 'REG_DWORD' '0'

# Action 1535: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'ShowRecent' 'REG_DWORD' '0'

# Action 1536: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackDocs' 'REG_DWORD' '0'

# Action 1537: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'ClearRecentDocsOnExit' 'REG_DWORD' '1'

# Action 1538: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoRecentDocsHistory' 'REG_DWORD' '1'

# Action 1539: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'NoRemoteDestinations' 'REG_DWORD' '1'

# Action 1540: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'MouseHoverTime' 'REG_SZ' '0'

# Action 1541: !registryKey
try { $p=Convert-RegPath 'HKCR\*\shellex\ContextMenuHandlers\Sharing'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\*\shellex\ContextMenuHandlers\Sharing - $_" }

# Action 1542: !registryKey
try { $p=Convert-RegPath 'HKCR\Directory\Background\shellex\ContextMenuHandlers\Sharing'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Directory\Background\shellex\ContextMenuHandlers\Sharing - $_" }

# Action 1543: !registryKey
try { $p=Convert-RegPath 'HKCR\Directory\shellex\ContextMenuHandlers\Sharing'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Directory\shellex\ContextMenuHandlers\Sharing - $_" }

# Action 1544: !registryKey
try { $p=Convert-RegPath 'HKCR\Drive\shellex\ContextMenuHandlers\Sharing'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Drive\shellex\ContextMenuHandlers\Sharing - $_" }

# Action 1545: !registryKey
try { $p=Convert-RegPath 'HKCR\LibraryFolder\background\shellex\ContextMenuHandlers\Sharing'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\LibraryFolder\background\shellex\ContextMenuHandlers\Sharing - $_" }

# Action 1546: !registryKey
try { $p=Convert-RegPath 'HKCR\UserLibraryFolder\shellex\ContextMenuHandlers\Sharing'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\UserLibraryFolder\shellex\ContextMenuHandlers\Sharing - $_" }

# Action 1547: !registryKey
try { $p=Convert-RegPath 'HKCR\Folder\ShellEx\ContextMenuHandlers\Library Location'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Folder\ShellEx\ContextMenuHandlers\Library Location - $_" }

# Action 1548: !registryKey
try { $p=Convert-RegPath 'HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\ModernSharing'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\ModernSharing - $_" }

# Action 1549: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense' 'REG_DWORD' '1'

# Action 1550: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Multimedia\Audio\DeviceCpl' 'ShowDisconnectedDevices' 'REG_DWORD' '0'

# Action 1551: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Multimedia\Audio\DeviceCpl' 'ShowHiddenDevices' 'REG_DWORD' '0'

# Action 1552: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83} - $_" }

# Action 1553: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager' 'EnthusiastMode' 'REG_DWORD' '1'

# Action 1554: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' 'FullPath' 'REG_DWORD' '1'

# Action 1555: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoInternetOpenWith' 'REG_DWORD' '1'

# Action 1556: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoInternetOpenWith' 'REG_DWORD' '1'

# Action 1557: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\SearchCompanion' 'DisableContentFileUpdates' 'REG_DWORD' '1'

# Action 1558: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'LaunchTo' 'REG_DWORD' '1'

# Action 1559: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\CrashControl' 'AutoReboot' 'REG_DWORD' '0'

# Action 1560: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\CrashControl' 'CrashDumpEnabled' 'REG_DWORD' '0'

# Action 1561: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\CrashControl' 'LogEvent' 'REG_DWORD' '0'

# Action 1562: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\CrashControl' 'DisplayParameters' 'REG_DWORD' '1'

# Action 1563: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\CrashControl\StorageTelemetry' 'DeviceDumpEnabled' 'REG_DWORD' '0'

# Action 1564: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\image\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\image\shell\print - $_" }

# Action 1565: !registryKey
try { $p=Convert-RegPath 'HKCR\batfile\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\batfile\shell\print - $_" }

# Action 1566: !registryKey
try { $p=Convert-RegPath 'HKCR\fonfile\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\fonfile\shell\print - $_" }

# Action 1567: !registryKey
try { $p=Convert-RegPath 'HKCR\cmdfile\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\cmdfile\shell\print - $_" }

# Action 1568: !registryKey
try { $p=Convert-RegPath 'HKCR\htmlfile\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\htmlfile\shell\print - $_" }

# Action 1569: !registryKey
try { $p=Convert-RegPath 'HKCR\JSEFile\Shell\Print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\JSEFile\Shell\Print - $_" }

# Action 1570: !registryKey
try { $p=Convert-RegPath 'HKCR\otffile\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\otffile\shell\print - $_" }

# Action 1571: !registryKey
try { $p=Convert-RegPath 'HKCR\pfmfile\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\pfmfile\shell\print - $_" }

# Action 1572: !registryKey
try { $p=Convert-RegPath 'HKCR\regfile\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\regfile\shell\print - $_" }

# Action 1573: !registryKey
try { $p=Convert-RegPath 'HKCR\ttcfile\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\ttcfile\shell\print - $_" }

# Action 1574: !registryKey
try { $p=Convert-RegPath 'HKCR\ttffile\shell\print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\ttffile\shell\print - $_" }

# Action 1575: !registryKey
try { $p=Convert-RegPath 'HKCR\VBEFile\Shell\Print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\VBEFile\Shell\Print - $_" }

# Action 1576: !registryKey
try { $p=Convert-RegPath 'HKCR\VBSFile\Shell\Print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\VBSFile\Shell\Print - $_" }

# Action 1577: !registryKey
try { $p=Convert-RegPath 'HKCR\WSFFile\Shell\Print'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\WSFFile\Shell\Print - $_" }

# Action 1578: !registryKey
try { $p=Convert-RegPath 'HKCR\Folder\shellex\ContextMenuHandlers\PintoStartScreen'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Folder\shellex\ContextMenuHandlers\PintoStartScreen - $_" }

# Action 1579: !registryKey
try { $p=Convert-RegPath 'HKCR\exefile\shellex\ContextMenuHandlers\PintoStartScreen'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\exefile\shellex\ContextMenuHandlers\PintoStartScreen - $_" }

# Action 1580: !registryKey
try { $p=Convert-RegPath 'HKCR\Microsoft.Website\ShellEx\ContextMenuHandlers\PintoStartScreen'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Microsoft.Website\ShellEx\ContextMenuHandlers\PintoStartScreen - $_" }

# Action 1581: !registryKey
try { $p=Convert-RegPath 'HKCR\mscfile\shellex\ContextMenuHandlers\PintoStartScreen'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\mscfile\shellex\ContextMenuHandlers\PintoStartScreen - $_" }

# Action 1582: !registryKey
try { $p=Convert-RegPath 'HKCR\*\shell\pintohomefile'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\*\shell\pintohomefile - $_" }

# Action 1583: !registryKey
try { $p=Convert-RegPath 'HKCR\Folder\shell\pintohome'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Folder\shell\pintohome - $_" }

# Action 1584: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked' '{1d27f844-3a1f-4410-85ac-14651078412d}' 'REG_SZ' ''

# Action 1585: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.3mf\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.3mf\Shell\3D Edit - $_" }

# Action 1586: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.bmp\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.bmp\Shell\3D Edit - $_" }

# Action 1587: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.fbx\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.fbx\Shell\3D Edit - $_" }

# Action 1588: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.gif\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.gif\Shell\3D Edit - $_" }

# Action 1589: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.jfif\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.jfif\Shell\3D Edit - $_" }

# Action 1590: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.jpe\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.jpe\Shell\3D Edit - $_" }

# Action 1591: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.jpeg\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.jpeg\Shell\3D Edit - $_" }

# Action 1592: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.jpg\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.jpg\Shell\3D Edit - $_" }

# Action 1593: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.png\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.png\Shell\3D Edit - $_" }

# Action 1594: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.tif\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.tif\Shell\3D Edit - $_" }

# Action 1595: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.tiff\Shell\3D Edit'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.tiff\Shell\3D Edit - $_" }

# Action 1596: !registryValue
Set-Reg 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '' 'REG_SZ' ''

# Action 1597: !registryKey
try { $p=Convert-RegPath 'HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153} - $_" }

# Action 1598: !registryKey
try { $p=Convert-RegPath 'HKCR\CLSID\{450D8FBA-AD25-11D0-98A8-0800361B1103}\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\CLSID\{450D8FBA-AD25-11D0-98A8-0800361B1103}\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153} - $_" }

# Action 1599: !registryKey
try { $p=Convert-RegPath 'HKCR\Directory\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Directory\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153} - $_" }

# Action 1600: !registryKey
try { $p=Convert-RegPath 'HKCR\Drive\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Drive\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153} - $_" }

# Action 1601: !registryKey
try { $p=Convert-RegPath 'HKCR\AllFilesystemObjects\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\AllFilesystemObjects\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153} - $_" }

# Action 1602: !registryKey
try { $p=Convert-RegPath 'HKCR\CLSID\{450D8FBA-AD25-11D0-98A8-0800361B1103}\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\CLSID\{450D8FBA-AD25-11D0-98A8-0800361B1103}\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153} - $_" }

# Action 1603: !registryKey
try { $p=Convert-RegPath 'HKCR\Directory\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Directory\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153} - $_" }

# Action 1604: !registryKey
try { $p=Convert-RegPath 'HKCR\Drive\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\Drive\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153} - $_" }

# Action 1605: !registryValue
Remove-RegValue 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'NoPreviousVersionsPage'

# Action 1606: !registryValue
Remove-RegValue 'HKCU\SOFTWARE\Policies\Microsoft\PreviousVersions' 'DisableLocalPage'

# Action 1607: !registryValue
Set-Reg 'HKCU\Software\Classes\CLSID\{2aa9162e-c906-4dd9-ad0b-3d24a8eef5a0}' '' 'REG_SZ' 'CLSID_ItemsViewAdapter'

# Action 1608: !registryValue
Set-Reg 'HKCU\Software\Classes\CLSID\{2aa9162e-c906-4dd9-ad0b-3d24a8eef5a0}\InProcServer32' '' 'REG_SZ' 'C:\Windows\System32\Windows.UI.FileExplorer.dll_'

# Action 1609: !registryValue
Set-Reg 'HKCU\Software\Classes\CLSID\{2aa9162e-c906-4dd9-ad0b-3d24a8eef5a0}\InProcServer32' 'ThreadingModel' 'REG_SZ' 'Apartment'

# Action 1610: !registryValue
Set-Reg 'HKCU\Software\Classes\CLSID\{6480100b-5a83-4d1e-9f69-8ae5a88e9a33}' '' 'REG_SZ' 'File Explorer Xaml Island View Adapter'

# Action 1611: !registryValue
Set-Reg 'HKCU\Software\Classes\CLSID\{6480100b-5a83-4d1e-9f69-8ae5a88e9a33}\InProcServer32' '' 'REG_SZ' 'C:\Windows\System32\Windows.UI.FileExplorer.dll_'

# Action 1612: !registryValue
Set-Reg 'HKCU\Software\Classes\CLSID\{6480100b-5a83-4d1e-9f69-8ae5a88e9a33}\InProcServer32' 'ThreadingModel' 'REG_SZ' 'Apartment'

# Action 1613: !registryValue
Set-Reg 'HKCU\SOFTWARE\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}' 'System.IsPinnedToNameSpaceTree' 'REG_DWORD' '0'

# Action 1614: !registryValue
Set-Reg 'HKLM\SOFTWARE\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}' 'System.IsPinnedToNameSpaceTree' 'REG_DWORD' '0'

# Action 1615: !registryKey
Remove-RegKey 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'

# Action 1616: !registryValue
Set-Reg 'HKCU\SOFTWARE\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' 'System.IsPinnedToNameSpaceTree' 'REG_DWORD' '0'

# Action 1617: !registryKey
Remove-RegKey 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}'

# Action 1618: !registryValue
Set-Reg 'HKCU\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}' 'System.IsPinnedToNameSpaceTree' 'REG_DWORD' '0'

# Action 1619: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{31C0DD25-9439-4F12-BF41-7FF4EDA38722}\PropertyBag' 'ThisPCPolicy' 'REG_SZ' 'Hide'

# Action 1620: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag' 'ThisPCPolicy' 'REG_SZ' 'Hide'

# Action 1621: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag' 'ThisPCPolicy' 'REG_SZ' 'Hide'

# Action 1622: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag' 'ThisPCPolicy' 'REG_SZ' 'Hide'

# Action 1623: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag' 'ThisPCPolicy' 'REG_SZ' 'Hide'

# Action 1624: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag' 'ThisPCPolicy' 'REG_SZ' 'Hide'

# Action 1625: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag' 'ThisPCPolicy' 'REG_SZ' 'Hide'

# Action 1626: !registryValue
Set-Reg 'HKCR\Directory\shell\cmd_here' '' 'REG_SZ' 'Open CMD here'

# Action 1627: !registryValue
Set-Reg 'HKCR\Directory\shell\cmd_here' 'Icon' 'REG_SZ' 'cmd.exe'

# Action 1628: !registryValue
Set-Reg 'HKCR\Directory\shell\cmd_here' 'SeparatorBefore' 'REG_SZ' ''

# Action 1629: !registryValue
Set-Reg 'HKCR\Directory\shell\cmd_here\command' '' 'REG_SZ' 'cmd.exe /k cd /d "%1"'

# Action 1630: !registryValue
Set-Reg 'HKCR\Directory\Background\shell\cmd_here' '' 'REG_SZ' 'Open CMD here'

# Action 1631: !registryValue
Set-Reg 'HKCR\Directory\Background\shell\cmd_here' 'Icon' 'REG_SZ' 'cmd.exe'

# Action 1632: !registryValue
Set-Reg 'HKCR\Directory\Background\shell\cmd_here' 'SeparatorBefore' 'REG_SZ' ''

# Action 1633: !registryValue
Set-Reg 'HKCR\Directory\Background\shell\cmd_here\command' '' 'REG_SZ' 'cmd.exe /k cd /d "%V"'

# Action 1634: !registryValue
Set-Reg 'HKCR\.pow' '' 'REG_SZ' 'Power Plan'

# Action 1635: !registryValue
Set-Reg 'HKCR\.pow' 'FriendlyTypeName' 'REG_SZ' 'Power Plan'

# Action 1636: !registryValue
Set-Reg 'HKCR\.pow\DefaultIcon' '' 'REG_EXPAND_SZ' '%SystemRoot%\System32\powercfg.cpl,-202'

# Action 1637: !registryValue
Set-Reg 'HKCR\.pow\shell\Import\command' '' 'REG_SZ' 'powercfg /import "%1"'

# Action 1638: !registryValue
Set-Reg 'HKCR\CABFolder\Shell\RunAs' '' 'REG_SZ' 'Install'

# Action 1639: !registryValue
Set-Reg 'HKCR\CABFolder\Shell\RunAs' 'HasLUAShield' 'REG_SZ' ''

# Action 1640: !registryValue
Set-Reg 'HKCR\CABFolder\Shell\RunAs\Command' '' 'REG_SZ' 'cmd /k dism /online /add-package /packagepath:"%1"'

# Action 1641: !registryValue
Set-Reg 'HKCR\.reg\ShellNew' 'NullFile' 'REG_SZ' ''

# Action 1642: !registryValue
Set-Reg 'HKCR\.reg\ShellNew' 'ItemName' 'REG_EXPAND_SZ' '%systemroot%\regedit.exe,-309'

# Action 1643: !registryValue
Set-Reg 'HKCR\.bat\ShellNew' 'ItemName' 'REG_EXPAND_SZ' '%systemroot%\System32\acppage.dll,-6002'

# Action 1644: !registryValue
Set-Reg 'HKCR\.bat\ShellNew' 'NullFile' 'REG_SZ' ''

# Action 1645: !registryValue
Set-Reg 'HKCR\.ps1' '' 'REG_SZ' 'Microsoft.PowerShellScript.1'

# Action 1646: !registryValue
Set-Reg 'HKCR\.ps1\ShellNew' 'NullFile' 'REG_SZ' ''

# Action 1647: !registryValue
Set-Reg 'HKCR\Microsoft.PowerShellScript.1' '' 'REG_SZ' 'Windows PowerShell Script'

# Action 1648: !registryValue
Set-Reg 'HKCR\Microsoft.PowerShellScript.1' 'FriendlyTypeName' 'REG_SZ' 'Windows PowerShell Script'

# Action 1649: !registryValue
Set-Reg 'HKCR\Directory\shell\runas' '' 'REG_SZ' 'Take Ownership'

# Action 1650: !registryValue
Set-Reg 'HKCR\Directory\shell\runas' 'HasLUAShield' 'REG_SZ' ''

# Action 1651: !registryValue
Set-Reg 'HKCR\Directory\shell\runas' 'NoWorkingDirectory' 'REG_SZ' ''

# Action 1652: !registryValue
Set-Reg 'HKCR\Directory\shell\runas\command' '' 'REG_SZ' 'cmd.exe /c takeown /f %1 /r /d y && icacls %1 /grant administrators:F'

# Action 1653: !registryValue
Set-Reg 'HKCR\Directory\shell\runas\command' 'IsolatedCommand' 'REG_SZ' 'cmd.exe /c takeown /f %1 /r /d y && icacls %1 /grant administrators:F'

# Action 1654: !cmd
Invoke-Cmd '"reg import runasti.reg'

# Action 1655: !registryKey
try { $p=Convert-RegPath 'HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\SendTo'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\SendTo - $_" }

# Action 1656: !registryKey
try { $p=Convert-RegPath 'HKCR\UserLibraryFolder\shellex\ContextMenuHandlers\SendTo'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\UserLibraryFolder\shellex\ContextMenuHandlers\SendTo - $_" }

# Action 1657: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked' '{7AD84985-87B4-4a16-BE58-8B72A5B390F7}' 'REG_SZ' ''

# Action 1658: !registryKey
try { $p=Convert-RegPath 'HKCR\CompressedFolder\ShellEx\ContextMenuHandlers\{b8cdcb65-b1bf-4b42-9428-1dfdb7ee92af}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\CompressedFolder\ShellEx\ContextMenuHandlers\{b8cdcb65-b1bf-4b42-9428-1dfdb7ee92af} - $_" }

# Action 1659: !registryKey
try { $p=Convert-RegPath 'HKCR\SystemFileAssociations\.zip\ShellEx\ContextMenuHandlers\{b8cdcb65-b1bf-4b42-9428-1dfdb7ee92af}'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\SystemFileAssociations\.zip\ShellEx\ContextMenuHandlers\{b8cdcb65-b1bf-4b42-9428-1dfdb7ee92af} - $_" }

# Action 1660: !powerShell
$__cmd = @'
New-ItemProperty -Path 'HKCU:\AppEvents\Schemes' -Name '(Default)' -Value '.None' -Force | Out-Null; Get-ChildItem -Path 'HKCU:\AppEvents\Schemes\Apps' | Get-ChildItem | Get-ChildItem | Where-Object { $_.PSChildName -eq '.Current' } | Set-ItemProperty -Name '(Default)' -Value ''
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1661: !registryKey
try { $p=Convert-RegPath 'HKCR\.rtf\ShellNew'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKCR\.rtf\ShellNew - $_" }

# Action 1662: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Shell\USB' 'NotifyOnUsbErrors' 'REG_DWORD' '0'

# Action 1663: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Shell\USB' 'NotifyOnWeakCharger' 'REG_DWORD' '0'

# Action 1664: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{D15ED2E1-C75B-443c-BD7C-FC03B2F08C17}' '' 'REG_SZ' 'All Tasks'

# Action 1665: !registryValue
Set-Reg 'HKCR\CLSID\{D15ED2E1-C75B-443c-BD7C-FC03B2F08C17}' '' 'REG_SZ' 'All Tasks'

# Action 1666: !registryValue
Set-Reg 'HKCR\CLSID\{D15ED2E1-C75B-443c-BD7C-FC03B2F08C17}' 'InfoTip' 'REG_SZ' 'View list of all Control Panel tasks'

# Action 1667: !registryValue
Set-Reg 'HKCR\CLSID\{D15ED2E1-C75B-443c-BD7C-FC03B2F08C17}' 'System.ControlPanel.Category' 'REG_SZ' '5'

# Action 1668: !registryValue
Set-Reg 'HKCR\CLSID\{D15ED2E1-C75B-443c-BD7C-FC03B2F08C17}\DefaultIcon' '' 'REG_SZ' '%systemroot%\System32\imageres.dll,-27'

# Action 1669: !registryValue
Set-Reg 'HKCR\CLSID\{D15ED2E1-C75B-443c-BD7C-FC03B2F08C17}\Shell\Open\Command' '' 'REG_SZ' 'explorer.exe shell:::{ED7BA470-8E54-465E-825C-99712043E01C}'

# Action 1670: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 'REG_DWORD' '1'

# Action 1671: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 'REG_DWORD' '0'

# Action 1672: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'UseCompactMode' 'REG_DWORD' '1'

# Action 1673: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'Max Cached Icons' 'REG_SZ' '4096'

# Action 1674: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'Max Cached Icons' 'REG_SZ' '4096'

# Action 1675: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'DontUsePowerShellOnWinX' 'REG_DWORD' '1'

# Action 1676: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\PCHealth\HelpSvc' 'Headlines' 'REG_DWORD' '0'

# Action 1677: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\AccountNotifications' 'DisableAccountNotifications' 'REG_DWORD' '1'

# Action 1678: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes' 'ThemeChangesDesktopIcons' 'REG_SZ' '0'

# Action 1679: !powerShell
$__cmd = @'
if ((Get-CimInstance Win32_ComputerSystem).Name -ne 'HEXA') { Rename-Computer -NewName 'HEXA' -Force }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1680: !registryValue
Set-Reg 'HKCU\Console\%SystemRoot%_system32_cmd.exe' 'FontWeight' 'REG_DWORD' '700'

# Action 1681: !registryValue
Set-Reg 'HKCU\Console\%SystemRoot%_system32_cmd.exe' 'WindowAlpha' 'REG_DWORD' '239'

# Action 1682: !registryValue
Set-Reg 'HKCU\Console\%SystemRoot%_system32_cmd.exe' 'CursorType' 'REG_DWORD' '2'

# Action 1683: !registryValue
Set-Reg 'HKCU\Console\%SystemRoot%_system32_cmd.exe' 'TerminalScrolling' 'REG_DWORD' '1'

# Action 1684: !registryValue
Set-Reg 'HKCU\Console\%SystemRoot%_system32_cmd.exe' 'FontSize' 'REG_DWORD' '1179648'

# Action 1685: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewAlphaSelect' 'REG_DWORD' '1'

# Action 1686: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'IconsOnly' 'REG_DWORD' '0'

# Action 1687: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 'REG_DWORD' '0'

# Action 1688: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 'REG_DWORD' '0'

# Action 1689: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 'REG_DWORD' '3'

# Action 1690: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\DWM' 'EnableAeroPeek' 'REG_DWORD' '0'

# Action 1691: !registryValue
Set-Reg 'HKCU\SOFTWARE\Microsoft\Windows\DWM' 'AlwaysHibernateThumbnails' 'REG_DWORD' '0'

# Action 1692: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 'REG_DWORD' '0'

# Action 1693: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'JPEGImportQuality' 'REG_DWORD' '100'

# Action 1694: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'UserPreferencesMask' 'REG_BINARY' '9012038012000000'

# Action 1695: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'DragFullWindows' 'REG_SZ' '1'

# Action 1696: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop\WindowMetrics' 'MinAnimate' 'REG_SZ' '0'

# Action 1697: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' 'AccentPalette' 'REG_BINARY' '9CEBFF0040BDFF00000000000000000000000000000000000000000000000000'

# Action 1698: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'ColorPrevalence' 'REG_DWORD' '1'

# Action 1699: !registryValue
Set-Reg 'HKCU\Control Panel\Desktop' 'ForegroundLockTimeout' 'REG_DWORD' '0'

# Action 1700: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'SettingsPageVisibility' 'REG_SZ' 'hide:home;privacy-automaticfiledownloads;privacy-feedback;windowsinsider;deviceusage;maps;otherusers;findmydevice;windowsdefender;quiethours;powersleep;batterysaver;batterysaver-settings;storagesense;storagepolicies;savelocations;project;crossdevice;mobile-devices;network-dialup;videoplayback;search-permissions;cortana-windowssearch;privacy-speech;privacy-speechtyping;privacy-activityhistory;recovery;troubleshoot;privacy-general;pen;personalization-textinput'

# Action 1701: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons' '29' 'REG_SZ' 'C:\Windows\system32\blank.ico'

# Action 1702: !registryValue
Set-Reg 'HKCU\Control Panel\Colors' 'InfoWindow' 'REG_SZ' '246 253 255'

# Action 1703: !powerShell
$__cmd = @'
Get-PnpDevice -FriendlyName 'ACPI Processor Aggregator' -ErrorAction Ignore | Disable-PnpDevice -Confirm:$False -ErrorAction Ignore
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1704: !powerShell
$__cmd = @'
Get-PnpDevice -FriendlyName 'ACPI Thermal Zone' -ErrorAction Ignore | Disable-PnpDevice -Confirm:$False -ErrorAction Ignore
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1705: !powerShell
$__cmd = @'
Get-PnpDevice -FriendlyName 'ACPI Wake Alarm' -ErrorAction Ignore | Disable-PnpDevice -Confirm:$False -ErrorAction Ignore
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1706: !powerShell
$__cmd = @'
Get-PnpDevice -FriendlyName 'Intel(R) Platform Monitoring Technology Device' -ErrorAction Ignore | Disable-PnpDevice -Confirm:$False -ErrorAction Ignore
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1707: !powerShell
$__cmd = @'
$c=(Get-CimInstance Win32_SystemEnclosure).ChassisTypes[0]; if($c -le 7){Get-PnpDevice -FriendlyName 'PCI standard ISA bridge' -ErrorAction Ignore|Disable-PnpDevice -Confirm:$False -ErrorAction Ignore;Get-PnpDevice -FriendlyName 'Microsoft Windows Management Interface for ACPI' -ErrorAction Ignore|Disable-PnpDevice -Confirm:$False -ErrorAction Ignore;Set-Service -Name 'WmiAcpi' -StartupType Disabled -ErrorAction Ignore;Set-Service -Name 'msisadrv' -StartupType Disabled -ErrorAction Ignore}
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1708: !cmd
Invoke-Cmd 'net user defaultuser0 /delete >nul 2>&1 & exit 0'

# Action 1709: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'MitigationOptions' 'REG_BINARY' '222222222222222222222222222222222222222222222222'

# Action 1710: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'MitigationAuditOptions' 'REG_BINARY' '222222222222222222222222222222222222222222222222'

# Action 1711: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'DisableExceptionChainValidation' 'REG_DWORD' '1'

# Action 1712: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'DisableControlFlowGuardXfg' 'REG_DWORD' '1'

# Action 1713: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'DisableControlFlowGuardExportSuppression' 'REG_DWORD' '1'

# Action 1714: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'DriveRemappingMitigation' 'REG_DWORD' '0'

# Action 1715: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'FeatureSettingsOverride' 'REG_DWORD' '3'

# Action 1716: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'FeatureSettingsOverrideMask' 'REG_DWORD' '3'

# Action 1717: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'FeatureSettings' 'REG_DWORD' '1'

# Action 1718: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 'REG_DWORD' '0'

# Action 1719: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 'REG_DWORD' '0'

# Action 1720: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks' 'Enabled' 'REG_DWORD' '0'

# Action 1721: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL' 'REG_DWORD' '0'

# Action 1722: !registryValue
Set-Reg 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard' 'Enabled' 'REG_DWORD' '0'

# Action 1723: !cmd
Invoke-Cmd '(for /f %i in (''reg query "HKLM\SYSTEM\CurrentControlSet\Services" /s /f "DmaRemappingCompatible" ^| find /i "Services\" '') do Reg.exe add "%i" /v "DmaRemappingCompatible" /t REG_DWORD /d "0" /f) >nul 2>&1'

# Action 1724: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate - $_" }

# Action 1725: !registryKey
try { $p=Convert-RegPath 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate'; if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null } } catch { Write-Warning "Registry key create failed: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate - $_" }

# Action 1726: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' 'AUOptions' 'REG_DWORD' '2'

# Action 1727: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' 'AutomaticMaintenanceEnabled' 'REG_DWORD' '0'

# Action 1728: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoUpdate' 'REG_DWORD' '1'

# Action 1729: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'TargetReleaseVersion' 'REG_DWORD' '1'

# Action 1730: !powerShell
$__cmd = @'
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Force | Out-Null; $ver = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion; New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name 'TargetReleaseVersion' -Value 1 -PropertyType DWord -Force | Out-Null; New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name 'TargetReleaseVersionInfo' -Value $ver -PropertyType String -Force | Out-Null
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1731: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate' 'DisableDualScan' 'REG_DWORD' '1'

# Action 1732: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 'REG_DWORD' '0'

# Action 1733: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 'REG_DWORD' '1'

# Action 1734: !registryValue
Set-Reg 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoAutoUpdate' 'REG_DWORD' '1'

# Action 1735: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate' 'DoNotConnectToWindowsUpdateInternetLocations' 'REG_DWORD' '1'

# Action 1736: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'SetDisableUXWUAccess' 'REG_DWORD' '1'

# Action 1737: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig' 'REG_DWORD' '0'

# Action 1738: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\DriverSearching' 'DontSearchWindowsUpdate' 'REG_DWORD' '1'

# Action 1739: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer' 'DisableCoInstallers' 'REG_DWORD' '1'

# Action 1740: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Maps' 'AutoDownloadAndUpdateMapData' 'REG_DWORD' '0'

# Action 1741: !registryValue
Set-Reg 'HKLM\SYSTEM\Maps' 'AutoUpdateEnabled' 'REG_DWORD' '0'

# Action 1742: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate' 'AutoDownload' 'REG_DWORD' '2'

# Action 1743: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' 'REG_DWORD' '2'

# Action 1744: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\WindowsStore' 'DisableOSUpgrade' 'REG_DWORD' '1'

# Action 1745: !registryValue
Set-Reg 'HKCU\SOFTWARE\Policies\Microsoft\WindowsStore' 'DisableOSUpgrade' 'REG_DWORD' '1'

# Action 1746: !registryValue
Set-Reg 'HKLM\SOFTWARE\Policies\Microsoft\Speech' 'AllowSpeechModelUpdate' 'REG_DWORD' '0'

# Action 1747: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate' 'SetAllowOptionalContent' 'REG_DWORD' '1'

# Action 1748: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate' 'AllowOptionalContent' 'REG_DWORD' '3'

# Action 1749: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate' 'SetUpdateNotificationLevel' 'REG_DWORD' '1'

# Action 1750: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate' 'UpdateNotificationLevel' 'REG_DWORD' '2'

# Action 1751: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAUAsDefaultShutdownOption' 'REG_DWORD' '1'

# Action 1752: !registryValue
Set-Reg 'HKCU\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAUAsDefaultShutdownOption' 'REG_DWORD' '1'

# Action 1753: !registryValue
Set-Reg 'HKLM\Software\Policies\Microsoft\Windows\StorageHealth' 'AllowDiskHealthModelUpdates' 'REG_DWORD' '0'

# Action 1754: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation' 'Model' 'REG_SZ' 'HEXA'

# Action 1755: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation' 'Manufacturer' 'REG_SZ' 'm6sry'

# Action 1756: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation' 'SupportURL' 'REG_SZ' 'https://dsc.gg/hexaopti'

# Action 1757: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'EditionSubVersion' 'REG_SZ' 'HEXA'

# Action 1758: !registryValue
Set-Reg 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'RegisteredOrganization' 'REG_SZ' 'HEXA'

# Action 1759: !status
Write-Status 'Configuring NIC'

# Action 1760: !cmd
Invoke-Cmd 'netsh int ip reset >nul 2>&1 & exit /b 0'

# Action 1761: !cmd
Invoke-Cmd 'netsh interface ipv4 reset >nul 2>&1 & exit /b 0'

# Action 1762: !cmd
Invoke-Cmd 'netsh interface ipv6 reset >nul 2>&1 & exit /b 0'

# Action 1763: !cmd
Invoke-Cmd 'netsh interface tcp reset >nul 2>&1'

# Action 1764: !cmd
Invoke-Cmd 'netsh winsock reset >nul 2>&1'

# Action 1765: !powerShell
$__cmd = @'
foreach ($dev in Get-PnpDevice -Class Net -Status "OK") { pnputil /remove-device $dev.InstanceId 2>&1 | Out-Null }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1766: !cmd
Invoke-Cmd 'pnputil /scan-devices >nul 2>&1'

# Action 1767: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnablePME" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnablePME" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1768: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*DeviceSleepOnDisconnect" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*DeviceSleepOnDisconnect" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1769: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*EEE" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*EEE" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1770: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*ModernStandbyWoLMagicPacket" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*ModernStandbyWoLMagicPacket" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1771: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*SelectiveSuspend" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*SelectiveSuspend" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1772: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*WakeOnMagicPacket" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*WakeOnMagicPacket" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1773: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*WakeOnPattern" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*WakeOnPattern" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1774: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "AutoPowerSaveModeEnabled" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "AutoPowerSaveModeEnabled" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1775: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EEELinkAdvertisement" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EEELinkAdvertisement" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1776: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EeePhyEnable" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EeePhyEnable" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1777: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnableGreenEthernet" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnableGreenEthernet" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1778: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnableModernStandby" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnableModernStandby" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1779: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "GigaLite" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "GigaLite" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1780: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "PowerDownPll" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "PowerDownPll" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1781: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "PowerSavingMode" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "PowerSavingMode" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1782: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "ReduceSpeedOnPowerDown" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "ReduceSpeedOnPowerDown" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1783: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "S5WakeOnLan" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "S5WakeOnLan" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1784: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "SavePowerNowEnabled" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "SavePowerNowEnabled" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1785: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "ULPMode" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "ULPMode" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1786: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "WakeOnLink" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "WakeOnLink" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1787: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "WakeOnSlot" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "WakeOnSlot" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1788: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "WakeUpModeCap" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "WakeUpModeCap" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1789: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "WaitAutoNegComplete" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "WaitAutoNegComplete" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1790: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*FlowControl" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*FlowControl" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1791: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*PMNSOffload" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*PMNSOffload" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1792: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*PMARPOffload" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*PMARPOffload" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1793: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*NicAutoPowerSaver" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*NicAutoPowerSaver" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1794: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*PMWiFiRekeyOffload" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*PMWiFiRekeyOffload" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1795: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnablePowerManagement" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnablePowerManagement" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1796: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "ForceWakeFromMagicPacketOnModernStandby" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "ForceWakeFromMagicPacketOnModernStandby" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1797: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "WakeFromS5" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "WakeFromS5" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1798: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "WakeOn" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "WakeOn" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1799: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "OBFFEnabled" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "OBFFEnabled" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1800: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "DMACoalescing" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "DMACoalescing" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1801: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnableSavePowerNow" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnableSavePowerNow" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1802: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnableD0PHYFlexibleSpeed" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnableD0PHYFlexibleSpeed" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1803: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnablePHYWakeUp" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnablePHYWakeUp" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1804: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnablePHYFlexibleSpeed" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnablePHYFlexibleSpeed" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1805: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "AllowAllSpeedsLPLU" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "AllowAllSpeedsLPLU" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1806: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*EnableDynamicPowerGating" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*EnableDynamicPowerGating" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1807: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnableD3ColdInS0" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnableD3ColdInS0" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1808: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "LatencyToleranceReporting" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "LatencyToleranceReporting" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1809: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "EnableAspm" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "EnableAspm" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1810: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "LTROBFF" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "LTROBFF" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1811: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "S0MgcPkt" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "S0MgcPkt" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1812: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "WakeFromPowerOff" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "WakeFromPowerOff" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1813: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "LogLinkStateEvent" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "LogLinkStateEvent" -Value "16" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1814: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "WolShutdownLinkSpeed" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "WolShutdownLinkSpeed" -Value "2" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1815: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "WakeOnMagicPacketFromS5" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "WakeOnMagicPacketFromS5" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1816: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*TCPChecksumOffloadIPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*TCPChecksumOffloadIPv4" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1817: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*TCPChecksumOffloadIPv6" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*TCPChecksumOffloadIPv6" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1818: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*TCPConnectionOffloadIPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*TCPConnectionOffloadIPv4" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1819: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*TCPConnectionOffloadIPv6" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*TCPConnectionOffloadIPv6" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1820: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*TCPUDPChecksumOffloadIPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*TCPUDPChecksumOffloadIPv4" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1821: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*TCPUDPChecksumOffloadIPv6" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*TCPUDPChecksumOffloadIPv6" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1822: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*UDPChecksumOffloadIPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*UDPChecksumOffloadIPv4" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1823: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*UDPChecksumOffloadIPv6" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*UDPChecksumOffloadIPv6" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1824: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*IPChecksumOffloadIPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*IPChecksumOffloadIPv4" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1825: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*UdpRsc" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*UdpRsc" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1826: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*UsoIPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*UsoIPv4" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1827: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*UsoIPv6" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*UsoIPv6" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1828: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*RscIPv6" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*RscIPv6" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1829: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*RscIPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*RscIPv4" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1830: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*IPsecOffloadV2IPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*IPsecOffloadV2IPv4" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1831: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*IPsecOffloadV2" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*IPsecOffloadV2" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1832: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*IPsecOffloadV1IPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*IPsecOffloadV1IPv4" -Value "3" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1833: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*LsoV1IPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*LsoV1IPv4" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1834: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*LsoV2IPv4" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*LsoV2IPv4" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1835: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*LsoV2IPv6" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*LsoV2IPv6" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1836: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*QoSOffload" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*QoSOffload" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1837: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "TeredoOffload" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "TeredoOffload" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1838: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*EncapsulatedPacketTaskOffload" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*EncapsulatedPacketTaskOffload" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1839: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*EncapsulatedPacketTaskOffloadVxlan" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*EncapsulatedPacketTaskOffloadVxlan" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1840: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*EncapsulatedPacketTaskOffloadNvgre" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*EncapsulatedPacketTaskOffloadNvgre" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1841: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*InterruptModeration" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*InterruptModeration" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1842: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "ITR" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "ITR" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1843: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*RSS" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*RSS" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1844: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "*QOS" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "*QOS" -Value "1" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1845: !powerShell
$__cmd = @'
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | ForEach-Object { if (Get-ItemProperty -Path $_.PSPath -Name "Downshift" -ErrorAction SilentlyContinue) { Set-ItemProperty -Path $_.PSPath -Name "Downshift" -Value "0" -Type String -Force -ErrorAction SilentlyContinue } }
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1846: !powerShell
$__cmd = @'
Disable-NetAdapterBinding -Name "*" -ComponentID vmware_bridge,ms_lldp,ms_lltdio,ms_implat,ms_rspndr,ms_server,ms_msclient -ErrorAction SilentlyContinue
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1847: !cmd
Invoke-Cmd 'netsh int tcp set security profiles=disabled >nul 2>&1'

# Action 1848: !cmd
Invoke-Cmd 'netsh int udp set global uro=enabled >nul 2>&1'

# Action 1849: !cmd
Invoke-Cmd 'netsh int tcp set global timestamps=disabled >nul 2>&1'

# Action 1850: !powerShell
$__cmd = @'
Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Enable -ErrorAction SilentlyContinue
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1851: !powerShell
$__cmd = @'
Set-NetOffloadGlobalSetting -PacketCoalescingFilter Disabled -ErrorAction SilentlyContinue
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1852: !status
Write-Status 'Setting file associations'

# Action 1853: !powerShell
$__cmd = @'
.\SetFileTypeAssociation.ps1
'@
try { Invoke-Expression $__cmd } catch { Write-Warning "Embedded PowerShell action failed: $_" }

# Action 1854: !status
Write-Status 'Rebuilding Perf Counters'

# Action 1855: !run
Invoke-Native 'lodctr' '/r'

# Action 1856: !run
Invoke-Native 'lodctr' '/r'

# Action 1857: !run
Invoke-Native 'winmgmt' '/resyncperf'

# Action 1858: !registryValue
Set-Reg 'HKCU\Control Panel\Keyboard' 'PrintScreenKeyForSnippingEnabled' 'REG_DWORD' '0'

# Action 1859: !status
Write-Status 'Cleaning up'

# Action 1860: !file
try { $p=Resolve-Env '%SystemDrive%\PerfLogs'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %SystemDrive%\PerfLogs - $_" }

# Action 1861: !file
try { $p=Resolve-Env '%SystemDrive%\inetpub'; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop } } catch { Write-Warning "File/path removal failed: %SystemDrive%\inetpub - $_" }

# Action 1862: !cmd
Invoke-Cmd 'del /f /s /q "%WINDIR%\Temp\*"  >nul 2>&1'

# Action 1863: !cmd
Invoke-Cmd 'vssadmin delete shadows /all /quiet  >nul 2>&1'

# Action 1864: !cmd
Invoke-Cmd 'for /f "tokens=*" %i in (''wevtutil el'') do wevtutil cl "%i" >nul 2>&1'

# Action 1865: !status
Write-Status 'End'

Write-Host "Finished. Review warnings above; some Windows changes require a restart/sign-out." -ForegroundColor Green
Read-Host "Press Enter to close" | Out-Null
