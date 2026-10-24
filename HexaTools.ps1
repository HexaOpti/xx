#Requires -Version 5.1
<#
    Hexa Tools v1.0  -  the after-optimization toolbox for clients
    Home (live PC status) | Fixes (switches + repairs) | Apps (recommended tools) | Support
    Every change is logged to %ProgramData%\Hexa\Logs\tools.log so support can see what was done.
#>
param()

# ---------- Self-elevate ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing

# ---------- Config ----------
$Config = @{
    Version    = '1.0'
    # Put your Discord invite here (the support button opens it)
    DiscordUrl = 'https://discord.gg/REPLACE_ME'
    DataDir    = Join-Path $env:ProgramData 'Hexa'
}
$LogDir  = Join-Path $Config.DataDir 'Logs'
$LogFile = Join-Path $LogDir 'tools.log'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

# ---------- XAML ----------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Hexa Tools" Width="1080" Height="740" MinWidth="920" MinHeight="620"
        WindowStartupLocation="CenterScreen" Background="#000000" Foreground="#F2F2F2" FontFamily="Segoe UI">
  <Window.Resources>

    <!-- White pill button -->
    <Style x:Key="Pill" TargetType="Button">
      <Setter Property="Foreground" Value="#000000"/>
      <Setter Property="Background" Value="#FFFFFF"/>
      <Setter Property="BorderBrush" Value="#FFFFFF"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Padding" Value="22,10"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="20" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.88"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Ghost" TargetType="Button" BasedOn="{StaticResource Pill}">
      <Setter Property="Foreground" Value="#E6E6E6"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderBrush" Value="#3A3A3A"/>
    </Style>

    <!-- Icon-only button (bottom of sidebar) -->
    <Style x:Key="IconBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#8E8E8E"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="20"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="Transparent" CornerRadius="12" Padding="10">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#141414"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Sidebar navigation item -->
    <Style x:Key="Nav" TargetType="RadioButton">
      <Setter Property="Foreground" Value="#8E8E8E"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Grid>
              <Border x:Name="bg" Background="Transparent" CornerRadius="12" Margin="10,0,10,0" Padding="0,10">
                <StackPanel HorizontalAlignment="Center">
                  <TextBlock Text="{TemplateBinding Tag}" FontFamily="Segoe MDL2 Assets" FontSize="20" HorizontalAlignment="Center"/>
                  <TextBlock Text="{TemplateBinding Content}" FontSize="12" Margin="0,6,0,0" HorizontalAlignment="Center"/>
                </StackPanel>
              </Border>
              <Rectangle x:Name="bar" Width="2" Height="28" Fill="#FFFFFF" HorizontalAlignment="Left" VerticalAlignment="Center" Visibility="Collapsed"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bg" Property="Background" Value="#141414"/>
                <Setter TargetName="bar" Property="Visibility" Value="Visible"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#FFFFFF"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Category list item (left column on list pages) -->
    <Style x:Key="Cat" TargetType="RadioButton">
      <Setter Property="Foreground" Value="#8E8E8E"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,0,4"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bg" Background="Transparent" CornerRadius="10" Padding="16,13">
              <Grid>
                <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                <TextBlock Text="{TemplateBinding Tag}" FontFamily="Consolas" FontSize="13" HorizontalAlignment="Right" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bg" Property="Background" Value="#FFFFFF"/>
                <Setter Property="Foreground" Value="#000000"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bg" Property="Opacity" Value="0.85"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Toggle switch -->
    <Style x:Key="Tgl" TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border x:Name="trk" Width="52" Height="30" CornerRadius="15" Background="#0F0F0F" BorderBrush="#3A3A3A" BorderThickness="1.5">
              <Ellipse x:Name="knob" Width="20" Height="20" Fill="#6A6A6A" HorizontalAlignment="Left" Margin="4,0,0,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="trk" Property="Background" Value="#FFFFFF"/>
                <Setter TargetName="trk" Property="BorderBrush" Value="#FFFFFF"/>
                <Setter TargetName="knob" Property="Fill" Value="#000000"/>
                <Setter TargetName="knob" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="knob" Property="Margin" Value="0,0,4,0"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="trk" Property="Opacity" Value="0.9"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="trk" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="92"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- Sidebar -->
    <Border Grid.Column="0" BorderBrush="#161616" BorderThickness="0,0,1,0">
      <Grid Margin="0,18,0,14">
        <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <StackPanel>
          <RadioButton x:Name="navHome"    GroupName="nav" Content="Home"    Tag="&#xE80F;" Style="{StaticResource Nav}" IsChecked="True"/>
          <RadioButton x:Name="navFixes"   GroupName="nav" Content="Fixes"   Tag="&#xE713;" Style="{StaticResource Nav}"/>
          <RadioButton x:Name="navApps"    GroupName="nav" Content="Apps"    Tag="&#xE71D;" Style="{StaticResource Nav}"/>
          <RadioButton x:Name="navSupport" GroupName="nav" Content="Support" Tag="&#xE897;" Style="{StaticResource Nav}"/>
        </StackPanel>
        <Button x:Name="btnUndo" Grid.Row="1" Content="&#xE777;" Style="{StaticResource IconBtn}" HorizontalAlignment="Center"
                ToolTip="Undo changes (opens System Restore)"/>
      </Grid>
    </Border>

    <!-- Main area -->
    <Grid Grid.Column="1">
      <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>

      <Grid Grid.Row="0">

        <!-- HOME -->
        <ScrollViewer x:Name="pageHome" VerticalScrollBarVisibility="Auto">
          <Grid Margin="48,34,48,26">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>

            <Grid Grid.Row="0">
              <Grid.ColumnDefinitions><ColumnDefinition Width="380"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <Grid Width="340" Height="340" HorizontalAlignment="Left" VerticalAlignment="Center">
                <Canvas x:Name="ringCanvas" Width="340" Height="340"/>
                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                  <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                    <TextBlock x:Name="txtCpu" Text="0" FontSize="80" FontFamily="Segoe UI Black, Segoe UI" FontWeight="Bold"/>
                    <TextBlock Text="%" FontSize="28" Foreground="#BDBDBD" VerticalAlignment="Bottom" Margin="4,0,0,14" FontWeight="SemiBold"/>
                  </StackPanel>
                  <TextBlock Text="CPU load right now" FontSize="13" Foreground="#9A9A9A" HorizontalAlignment="Center"/>
                </StackPanel>
              </Grid>
              <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="12,0,0,0">
                <TextBlock FontFamily="Segoe UI Black, Segoe UI" FontSize="42" FontWeight="Bold" TextWrapping="Wrap" LineHeight="46">
                  <Run Text="Built By HEXA,"/><LineBreak/><Run Text="Tuned For You."/>
                </TextBlock>
                <TextBlock Text="Your PC has been optimized. If something needs adjusting, Fixes can switch it back or repair it in a click. Need a hand? Open a ticket and we will help."
                           FontSize="15" Foreground="#9A9A9A" TextWrapping="Wrap" Margin="0,16,0,0" MaxWidth="520"/>
                <StackPanel Orientation="Horizontal" Margin="0,24,0,0">
                  <Button x:Name="btnHomeFixes" Content="Review fixes" Style="{StaticResource Pill}" Margin="0,0,12,0"/>
                  <Button x:Name="btnHomeSupport" Content="Open a ticket" Style="{StaticResource Ghost}"/>
                </StackPanel>
              </StackPanel>
            </Grid>

            <!-- Hardware -->
            <Border Grid.Row="1" Margin="0,26,0,0" BorderBrush="#1E1E1E" BorderThickness="0,1,0,1">
              <UniformGrid Columns="4">
                <StackPanel Margin="0,18,12,18">
                  <TextBlock Text="Processor" FontSize="12" Foreground="#8E8E8E"/>
                  <TextBlock x:Name="hwCpu" Text="..." FontSize="15" FontWeight="SemiBold" Margin="0,6,0,0" TextWrapping="Wrap"/>
                  <TextBlock x:Name="hwCpuSub" Text="" FontSize="12" Foreground="#8E8E8E" Margin="0,3,0,0"/>
                </StackPanel>
                <StackPanel Margin="14,18,12,18">
                  <TextBlock Text="Graphics" FontSize="12" Foreground="#8E8E8E"/>
                  <TextBlock x:Name="hwGpu" Text="..." FontSize="15" FontWeight="SemiBold" Margin="0,6,0,0" TextWrapping="Wrap"/>
                  <TextBlock x:Name="hwGpuSub" Text="" FontSize="12" Foreground="#8E8E8E" Margin="0,3,0,0"/>
                </StackPanel>
                <StackPanel Margin="14,18,12,18">
                  <TextBlock Text="Memory" FontSize="12" Foreground="#8E8E8E"/>
                  <TextBlock x:Name="hwMem" Text="..." FontSize="15" FontWeight="SemiBold" Margin="0,6,0,0" TextWrapping="Wrap"/>
                  <TextBlock x:Name="hwMemSub" Text="" FontSize="12" Foreground="#8E8E8E" Margin="0,3,0,0"/>
                </StackPanel>
                <StackPanel Margin="14,18,0,18">
                  <TextBlock Text="System drive" FontSize="12" Foreground="#8E8E8E"/>
                  <TextBlock x:Name="hwDisk" Text="..." FontSize="15" FontWeight="SemiBold" Margin="0,6,0,0" TextWrapping="Wrap"/>
                  <TextBlock x:Name="hwDiskSub" Text="" FontSize="12" Foreground="#8E8E8E" Margin="0,3,0,0"/>
                </StackPanel>
              </UniformGrid>
            </Border>

            <!-- Live cards -->
            <UniformGrid Grid.Row="2" Columns="3" Margin="0,22,0,0">
              <Border BorderBrush="#1E1E1E" BorderThickness="1" CornerRadius="18" Padding="20,18" Margin="0,0,12,0" Height="104">
                <Grid>
                  <TextBlock Text="Memory in use" FontSize="13" Foreground="#9A9A9A" VerticalAlignment="Top"/>
                  <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom">
                    <TextBlock x:Name="txtMem" Text="0" FontSize="34" FontWeight="Bold"/>
                    <TextBlock x:Name="txtMemOf" Text="" FontFamily="Consolas" FontSize="13" Foreground="#9A9A9A" VerticalAlignment="Bottom" Margin="6,0,0,6"/>
                  </StackPanel>
                </Grid>
              </Border>
              <Border BorderBrush="#1E1E1E" BorderThickness="1" CornerRadius="18" Padding="20,18" Margin="6,0,6,0" Height="104">
                <Grid>
                  <TextBlock Text="Free space on C:" FontSize="13" Foreground="#9A9A9A" VerticalAlignment="Top"/>
                  <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom">
                    <TextBlock x:Name="txtDisk" Text="0" FontSize="34" FontWeight="Bold"/>
                    <TextBlock Text="GB" FontFamily="Consolas" FontSize="13" Foreground="#9A9A9A" VerticalAlignment="Bottom" Margin="6,0,0,6"/>
                  </StackPanel>
                </Grid>
              </Border>
              <Border BorderBrush="#1E1E1E" BorderThickness="1" CornerRadius="18" Padding="20,18" Margin="12,0,0,0" Height="104">
                <Grid>
                  <TextBlock Text="Time since last restart" FontSize="13" Foreground="#9A9A9A" VerticalAlignment="Top"/>
                  <TextBlock x:Name="txtUptime" Text="-" FontSize="34" FontWeight="Bold" HorizontalAlignment="Right" VerticalAlignment="Bottom"/>
                </Grid>
              </Border>
            </UniformGrid>
          </Grid>
        </ScrollViewer>

        <!-- LIST PAGES (Fixes / Apps / Support) -->
        <Grid x:Name="pageList" Visibility="Collapsed" Margin="48,30,48,6">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel>
            <TextBlock x:Name="txtListTitle" Text="Fixes" FontSize="44" FontFamily="Segoe UI Black, Segoe UI" FontWeight="Bold"/>
            <TextBlock x:Name="txtListSub" Text="" FontSize="14" Foreground="#9A9A9A" TextWrapping="Wrap" MaxWidth="660" HorizontalAlignment="Left" Margin="0,8,0,22"/>
          </StackPanel>
          <Grid Grid.Row="1">
            <Grid.ColumnDefinitions><ColumnDefinition Width="250"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <StackPanel x:Name="catPanel" Margin="0,0,26,0"/>
            <Grid Grid.Column="1">
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
              <Border Height="46" CornerRadius="23" BorderBrush="#2A2A2A" BorderThickness="1" Background="#0A0A0A">
                <Grid>
                  <TextBlock Text="&#xE721;" FontFamily="Segoe MDL2 Assets" FontSize="15" Foreground="#8E8E8E" VerticalAlignment="Center" Margin="18,0,0,0"/>
                  <TextBlock x:Name="txtSearchHint" Text="Search" Foreground="#6E6E6E" FontSize="14" VerticalAlignment="Center" Margin="46,0,0,0" IsHitTestVisible="False"/>
                  <TextBox x:Name="txtSearch" Background="Transparent" BorderThickness="0" Foreground="#F2F2F2" CaretBrush="#FFFFFF"
                           FontSize="14" VerticalContentAlignment="Center" Margin="42,0,16,0"/>
                </Grid>
              </Border>
              <ScrollViewer x:Name="rowScroll" Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,10,0,0">
                <StackPanel x:Name="rowPanel" Margin="0,0,12,16"/>
              </ScrollViewer>
            </Grid>
          </Grid>
        </Grid>
      </Grid>

      <!-- Footer: status + restart banner -->
      <Border Grid.Row="1" BorderBrush="#161616" BorderThickness="0,1,0,0" Padding="48,12">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBlock x:Name="txtStatus" Text="Ready." FontSize="12" Foreground="#9A9A9A" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
          <StackPanel x:Name="restartBar" Grid.Column="1" Orientation="Horizontal" Visibility="Collapsed">
            <TextBlock Text="Restart needed to finish applying changes." FontSize="12" Foreground="#E6E6E6" VerticalAlignment="Center" Margin="0,0,14,0"/>
            <Button x:Name="btnRestart" Content="Restart now" Style="{StaticResource Pill}" Padding="16,6" FontSize="12"/>
          </StackPanel>
        </Grid>
      </Border>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)
$win.Title = "Hexa Tools v$($Config.Version)"
$ui = @{}
$xaml.SelectNodes('//*[@*[local-name()="Name"]]') | ForEach-Object { $ui[$_.Name] = $win.FindName($_.Name) }

$bc = New-Object Windows.Media.BrushConverter
$script:Bright    = $bc.ConvertFromString('#FFFFFF')
$script:Faint     = $bc.ConvertFromString('#2E2E2E')
$script:BarOff    = $bc.ConvertFromString('#3A3A3A')
$script:ChipBrd   = $bc.ConvertFromString('#333333')
$script:ChipTxt   = $bc.ConvertFromString('#CFCFCF')
$script:Dim       = $bc.ConvertFromString('#8E8E8E')

# ---------- Helpers ----------
function DoEvents {
    $script:frame = New-Object System.Windows.Threading.DispatcherFrame
    [void][Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [Windows.Threading.DispatcherPriority]::Background,
        [Action]{ $script:frame.Continue = $false })
    [Windows.Threading.Dispatcher]::PushFrame($script:frame)
}
function Wait-Ms($ms) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $ms) { DoEvents; Start-Sleep -Milliseconds 20 }
}
function Write-ToolLog($m) {
    try { Add-Content -Path $LogFile -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) } catch {}
}
function Set-Status($t) { $ui.txtStatus.Text = $t; DoEvents }
function Open-Link($url) { Start-Process $url; return 'Opened.' }

# ---------- Fix implementations ----------
function Invoke-Sc($svc, $start) { & sc.exe config $svc "start=$start" 2>&1 | Out-Null }

function Set-PnpState($filter, [bool]$enable) {
    Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object $filter | ForEach-Object {
        try {
            if ($enable) { Enable-PnpDevice  -InstanceId $_.InstanceId -Confirm:$false -ErrorAction Stop }
            else         { Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction Stop }
        } catch {}
    }
}
function Set-BluetoothState([bool]$enable) {
    $start  = if ($enable) { 'demand' } else { 'disabled' }
    $regVal = if ($enable) { 3 } else { 4 }
    $svcs = 'BthA2dp','BthEnum','BthHFEnum','BthLEEnum','BthMini','BTHMODEM','BthPan','BTHPORT','BTHUSB','HidBth',
            'Microsoft_Bluetooth_AvrcpTransport','RFCOMM','BluetoothUserService','BTAGService','BthAvctpSvc','bthserv','Modem'
    $classFilter = { $_.Class -eq 'Bluetooth' }
    $bthFilter   = { $_.InstanceId -like 'BTH*' }

    if ($enable) { Set-PnpState $classFilter $true } else { Set-PnpState $bthFilter $false }
    & reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Services\BluetoothUserService' /v Start /t REG_DWORD /d $regVal /f 2>&1 | Out-Null
    foreach ($s in $svcs) {
        # BTHMODEM stays on "demand" even when turning Bluetooth off (same as the original off script)
        $st = if ((-not $enable) -and $s -eq 'BTHMODEM') { 'demand' } else { $start }
        Invoke-Sc $s $st
    }
    Wait-Ms 2000
    if ($enable) { Set-PnpState $bthFilter $true } else { Set-PnpState $classFilter $false }
}
function Get-BluetoothOn {
    try { return ((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\bthserv' -ErrorAction Stop).Start -ne 4) } catch { return $false }
}

function Invoke-Bcd($bcdArgs) {
    $out = & bcdedit.exe @bcdArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw $out.Trim() }
}
function Get-NxMode {
    try {
        $o = & bcdedit.exe /enum '{current}' 2>$null | Out-String
        if ($o -match '(?im)^\s*nx\s+(\S+)') { return $Matches[1] }
    } catch {}
    return 'default'
}
function Set-DepState([bool]$enable) {
    if ($enable) { if ((Get-NxMode) -ne 'default') { Invoke-Bcd @('/deletevalue','nx') } }
    else         { Invoke-Bcd @('/set','nx','AlwaysOff') }
}

function Invoke-ValorantCfgFix {
    if ((Get-NxMode) -ne 'default') { try { Invoke-Bcd @('/deletevalue','nx') } catch {} }
    foreach ($n in 'valorant','valorant-win64-shipping','vgtray','vgc') {
        Set-ProcessMitigation -Name "$n.exe" -Enable CFG -ErrorAction Stop
    }
    & reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' /v MitigationAuditOptions /t REG_BINARY /d 222222222222222222222222222222222222222222222222 /f 2>&1 | Out-Null
    & reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' /v MitigationOptions /t REG_BINARY /d 232222222223222222222222222222222222222222222222 /f 2>&1 | Out-Null
}

$script:XboxSvcs = 'XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','GamingServices','GamingServicesNet'
function Set-XboxState([bool]$enable) {
    $st = if ($enable) { 'demand' } else { 'disabled' }
    foreach ($s in $script:XboxSvcs) {
        Invoke-Sc $s $st
        if (-not $enable) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
    }
}
function Get-XboxOn {
    try { return ((Get-Service -Name 'XblAuthManager' -ErrorAction Stop).StartType -ne 'Disabled') } catch { return $false }
}

$script:PowerKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
function Get-FastStartupOn {
    try { return ((Get-ItemProperty $script:PowerKey -Name HiberbootEnabled -ErrorAction Stop).HiberbootEnabled -ne 0) } catch { return $false }
}
function Set-FastStartup([bool]$enable) {
    $v = if ($enable) { 1 } else { 0 }
    New-ItemProperty -Path $script:PowerKey -Name HiberbootEnabled -PropertyType DWord -Value $v -Force | Out-Null
}

function Get-MouseAccelOn {
    try { return ((Get-ItemProperty 'HKCU:\Control Panel\Mouse' -ErrorAction Stop).MouseSpeed -ne '0') } catch { return $false }
}
function Set-MouseAccel([bool]$enable) {
    $vals = if ($enable) { @(6, 10, 1) } else { @(0, 0, 0) }
    $reg = 'HKCU:\Control Panel\Mouse'
    Set-ItemProperty -Path $reg -Name MouseThreshold1 -Value ([string]$vals[0])
    Set-ItemProperty -Path $reg -Name MouseThreshold2 -Value ([string]$vals[1])
    Set-ItemProperty -Path $reg -Name MouseSpeed      -Value ([string]$vals[2])
    if (-not ('HexaMouse' -as [type])) {
        Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class HexaMouse { [DllImport("user32.dll", SetLastError=true)] public static extern bool SystemParametersInfo(uint a, uint b, int[] c, uint d); }'
    }
    [void][HexaMouse]::SystemParametersInfo(0x0004, 0, [int[]]$vals, 3)
}

function Restart-ExplorerShell {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt 5000 -and -not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Wait-Ms 300 }
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}
function Get-TempBytes {
    $t = 0L
    foreach ($p in $env:TEMP, (Join-Path $env:SystemRoot 'Temp')) {
        if (Test-Path $p) {
            $m = Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum
            if ($m.Sum) { $t += [long]$m.Sum }
        }
    }
    return $t
}
function Clear-TempNow {
    $before = Get-TempBytes
    foreach ($p in $env:TEMP, (Join-Path $env:SystemRoot 'Temp')) {
        if (-not (Test-Path $p)) { continue }
        Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch {}
            DoEvents
        }
    }
    $after = Get-TempBytes
    $freed = [math]::Max(0, [math]::Round(($before - $after) / 1MB))
    return "Freed about $freed MB of temporary files."
}
function Get-PcInfoText {
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
    $gpu = (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Remote|Virtual' } | ForEach-Object { "$($_.Name) (driver $($_.DriverVersion))" }) -join '; '
    $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $bb  = Get-CimInstance Win32_BaseBoard
    $c   = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $up  = (Get-Date) - $os.LastBootUpTime
    @(
        ("Hexa Tools v{0} - {1}" -f $Config.Version, (Get-Date -Format 'yyyy-MM-dd HH:mm')),
        ("OS: {0} (build {1})" -f ($os.Caption -replace 'Microsoft ', ''), $os.BuildNumber),
        "CPU: $cpu",
        "GPU: $gpu",
        "RAM: $ram GB",
        ("Motherboard: {0} {1}" -f $bb.Manufacturer, $bb.Product),
        ("System drive: {0} GB free of {1} GB" -f [math]::Round($c.FreeSpace / 1GB), [math]::Round($c.Size / 1GB)),
        ("Uptime: {0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes)
    ) -join "`r`n"
}

# ---------- Catalog (everything the app shows) ----------
$script:PageNames = @{ Fixes = 'fixes'; Apps = 'apps'; Support = 'support' }
$script:PageTitle = @{
    Fixes   = @('Fixes',   'Flip a switch or run a quick repair. Every fix says what it does, and each change is logged so support can see it.')
    Apps    = @('Apps',    'Free tools we recommend for keeping your PC healthy. Each button opens the download page.')
    Support = @('Support', 'Stuck on something? Open a ticket and we will get you sorted.')
}
$script:Cats = @{
    Fixes   = @('Connectivity', 'Games', 'System', 'Maintenance')
    Apps    = @('Monitor and diagnose', 'Clean and remove', 'Windows tools')
    Support = @('Contact', 'Help')
}
$script:CatDesc = @{
    'Connectivity' = 'Bluetooth and internet'
    'Games' = 'Anticheat and launcher errors'
    'System' = 'Everyday Windows behaviour'
    'Maintenance' = 'Repairs and safety nets'
    'Monitor and diagnose' = 'See what your PC is doing'
    'Clean and remove' = 'Get rid of junk and leftovers'
    'Windows tools' = 'Built-in Windows shortcuts'
    'Contact' = 'Talk to us'
    'Help' = 'Make support faster'
}

$script:Items = @(
    # ---------------- FIXES: Connectivity ----------------
    @{ Page='Fixes'; Cat='Connectivity'; Kind='switch'; Impact=2; Title='Bluetooth'
       Desc='Turns the Bluetooth services and devices on or off. Switch on if headphones, a mouse or a controller will not pair. You may need your Bluetooth driver installed.'
       Tags=@('Restart needed'); Restart=$true
       Get={ Get-BluetoothOn }
       On ={ Set-BluetoothState $true;  'Bluetooth turned on. Install your Bluetooth driver if devices do not appear, then restart your PC.' }
       Off={ Set-BluetoothState $false; 'Bluetooth turned off. Restart your PC to finish.' } },

    @{ Page='Fixes'; Cat='Connectivity'; Kind='button'; Impact=3; Title='Reset network'; Button='Reset'
       Desc='Clears the DNS cache and resets Winsock and TCP/IP. Fixes "no internet", slow Wi-Fi and odd connection errors.'
       Tags=@('Restart needed'); Restart=$true
       Confirm='This resets your network settings. Saved Wi-Fi passwords are kept, but a restart is needed. Continue?'
       Run={
           & ipconfig.exe /flushdns 2>&1 | Out-Null
           & netsh.exe winsock reset 2>&1 | Out-Null
           & netsh.exe int ip reset 2>&1 | Out-Null
           'Network reset. Restart your PC to finish.' } },

    # ---------------- FIXES: Games ----------------
    @{ Page='Fixes'; Cat='Games'; Kind='button'; Impact=4; Title='Valorant CFG error fix'; Button='Apply fix'
       Desc='Enables Control Flow Guard for Valorant and Vanguard so the CFG / VAN errors go away. This one has no off switch.'
       Tags=@('One-way fix','Restart needed'); Restart=$true
       Run={ Invoke-ValorantCfgFix; 'Valorant fix applied. Restart your PC to finish.' } },

    @{ Page='Fixes'; Cat='Games'; Kind='switch'; Impact=3; Title='DEP / NX (Valorant and FACEIT fix)'
       Desc='Windows memory protection. On is the Windows default. Switch it off only if FACEIT or Valorant reports a DEP / NX error, and back on afterwards.'
       Tags=@('Restart needed'); Restart=$true
       ConfirmOff='Turning DEP off lowers Windows memory protection. Only do this if FACEIT, Valorant or support asked you to. Continue?'
       Get={ (Get-NxMode) -ne 'AlwaysOff' }
       On ={ Set-DepState $true;  'DEP turned on. Restart your PC to finish.' }
       Off={ Set-DepState $false; 'DEP turned off. Restart your PC to finish.' } },

    @{ Page='Fixes'; Cat='Games'; Kind='switch'; Impact=2; Title='Xbox and Game Bar services'
       Desc='Keeps the Xbox services available for Game Pass, the Xbox app and some game launchers. Switch on if a store game will not sign in or launch.'
       Tags=@('Restart recommended'); Restart=$true
       Get={ Get-XboxOn }
       On ={ Set-XboxState $true;  'Xbox services enabled. Restart your PC, then try your game again.' }
       Off={ Set-XboxState $false; 'Xbox services disabled.' } },

    # ---------------- FIXES: System ----------------
    @{ Page='Fixes'; Cat='System'; Kind='switch'; Impact=2; Title='Fast Startup'
       Desc='Makes boot faster, but Shut down no longer fully restarts Windows. Switch it off if you see odd issues after shutting down and turning back on.'
       Tags=@('Applies next boot')
       Get={ Get-FastStartupOn }
       On ={ Set-FastStartup $true;  'Fast Startup turned on.' }
       Off={ Set-FastStartup $false; 'Fast Startup turned off.' } },

    @{ Page='Fixes'; Cat='System'; Kind='switch'; Impact=3; Title='Mouse acceleration'
       Desc='Enhance pointer precision. On is the Windows default. Off gives 1:1 mouse movement, which most gamers prefer.'
       Tags=@('Instant')
       Get={ Get-MouseAccelOn }
       On ={ Set-MouseAccel $true;  'Mouse acceleration turned on.' }
       Off={ Set-MouseAccel $false; 'Mouse acceleration turned off.' } },

    # ---------------- FIXES: Maintenance ----------------
    @{ Page='Fixes'; Cat='Maintenance'; Kind='button'; Impact=2; Title='Restart Windows Explorer'; Button='Restart'
       Desc='Fixes a frozen taskbar or Start menu, or missing desktop icons, without restarting your PC.'
       Tags=@('Instant')
       Run={ Restart-ExplorerShell; 'Windows Explorer restarted.' } },

    @{ Page='Fixes'; Cat='Maintenance'; Kind='button'; Impact=2; Title='Fix no sound'; Button='Restart audio'
       Desc='Restarts the Windows audio services. Fixes missing or crackling sound without restarting your PC.'
       Tags=@('Instant')
       Run={
           Restart-Service -Name AudioEndpointBuilder -Force -ErrorAction Stop
           Start-Service -Name Audiosrv -ErrorAction SilentlyContinue
           'Audio services restarted.' } },

    @{ Page='Fixes'; Cat='Maintenance'; Kind='button'; Impact=3; Title='Repair Windows files'; Button='Run repair'
       Desc='Checks and repairs Windows system files (DISM and SFC). Opens in its own window and can take 10 to 20 minutes.'
       Tags=@('Takes a while')
       Confirm='This runs in a separate window and can take 10 to 20 minutes. Keep that window open until it says done. Start now?'
       Run={
           Start-Process cmd.exe -ArgumentList '/c title Hexa Repair & DISM /Online /Cleanup-Image /RestoreHealth & sfc /scannow & echo. & echo Finished. Press any key to close. & pause >nul'
           'Repair started in a new window.' } },

    @{ Page='Fixes'; Cat='Maintenance'; Kind='button'; Impact=2; Title='Free up space'; Button='Clean'
       Desc='Deletes temporary files that Windows and apps no longer need. Files in use are skipped.'
       Tags=@('Safe')
       Run={ Clear-TempNow } },

    @{ Page='Fixes'; Cat='Maintenance'; Kind='button'; Impact=3; Title='Create a restore point'; Button='Create'
       Desc='Saves a snapshot of Windows you can roll back to. Handy before you change anything yourself.'
       Tags=@('Safe')
       Run={
           Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
           Checkpoint-Computer -Description 'Hexa Tools restore point' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
           'Restore point created.' } },

    @{ Page='Fixes'; Cat='Maintenance'; Kind='button'; Impact=4; Title='Undo optimization'; Button='Open System Restore'
       Desc='Opens Windows System Restore so you can roll your PC back to the restore point made before the optimization.'
       Tags=@('Opens Windows tool')
       Run={ Start-Process rstrui.exe; 'System Restore opened.' } },

    # ---------------- APPS ----------------
    @{ Page='Apps'; Cat='Monitor and diagnose'; Kind='button'; Impact=3; Title='Core Temp'; Button='Open'
       Desc='Shows your CPU temperature and load, per core, in real time. Good for checking your PC is not running too hot.'
       Tags=@('Opens website')
       Run={ Open-Link 'https://www.alcpu.com/CoreTemp/' } },
    @{ Page='Apps'; Cat='Monitor and diagnose'; Kind='button'; Impact=3; Title='HWiNFO'; Button='Open'
       Desc='Detailed hardware information and live sensors for every part of your PC. Useful when support asks what is inside.'
       Tags=@('Opens website')
       Run={ Open-Link 'https://www.hwinfo.com/download/' } },
    @{ Page='Apps'; Cat='Clean and remove'; Kind='button'; Impact=3; Title='AdwCleaner'; Button='Open'
       Desc='Removes adware, unwanted toolbars and browser hijackers in a single scan.'
       Tags=@('Opens website')
       Run={ Open-Link 'https://www.majorgeeks.com/files/details/adwcleaner.html' } },
    @{ Page='Apps'; Cat='Clean and remove'; Kind='button'; Impact=3; Title='Geek Uninstaller'; Button='Open'
       Desc='Uninstalls programs completely, including the leftover files and registry entries Windows leaves behind.'
       Tags=@('Opens website')
       Run={ Open-Link 'https://geekuninstaller.com/download' } },
    @{ Page='Apps'; Cat='Windows tools'; Kind='button'; Impact=2; Title='Task Manager'; Button='Open'
       Desc='See which apps are using your CPU, memory and disk, and close ones that are stuck.'
       Tags=@('Windows tool')
       Run={ Open-Link 'taskmgr.exe' } },
    @{ Page='Apps'; Cat='Windows tools'; Kind='button'; Impact=2; Title='Startup apps'; Button='Open'
       Desc='Choose which apps start with Windows. Fewer startup apps means a faster boot.'
       Tags=@('Windows tool')
       Run={ Open-Link 'ms-settings:startupapps' } },
    @{ Page='Apps'; Cat='Windows tools'; Kind='button'; Impact=2; Title='Device Manager'; Button='Open'
       Desc='Check for devices with a warning icon and update or reinstall drivers.'
       Tags=@('Windows tool')
       Run={ Open-Link 'devmgmt.msc' } },
    @{ Page='Apps'; Cat='Windows tools'; Kind='button'; Impact=2; Title='Windows Update'; Button='Open'
       Desc='Check for Windows updates and driver updates.'
       Tags=@('Windows tool')
       Run={ Open-Link 'ms-settings:windowsupdate' } },

    # ---------------- SUPPORT ----------------
    @{ Page='Support'; Cat='Contact'; Kind='button'; Impact=4; Title='Hexa Discord'; Button='Open Discord'
       Desc='Open ticket for support'
       Tags=@('Opens Discord')
       Run={
           if ($Config.DiscordUrl -match 'REPLACE_ME') { throw 'The support link has not been set up yet.' }
           Open-Link $Config.DiscordUrl } },
    @{ Page='Support'; Cat='Help'; Kind='button'; Impact=3; Title='Copy PC info'; Button='Copy'
       Desc='Copies your PC details (hardware, Windows version, free space) so you can paste them into your ticket.'
       Tags=@('Copies to clipboard')
       Run={ Set-Clipboard -Value (Get-PcInfoText); 'PC info copied. Paste it into your ticket.' } }
)

# ---------- Fix runner ----------
function Invoke-Fix($it, $ctl) {
    $isSwitch = ($it.Kind -eq 'switch')
    $want = if ($isSwitch) { [bool]$ctl.IsChecked } else { $true }
    $ask = if ($isSwitch) { if ($want) { $it.ConfirmOn } else { $it.ConfirmOff } } else { $it.Confirm }
    if ($ask) {
        $r = [Windows.MessageBox]::Show($ask, 'Hexa', 'YesNo', 'Question')
        if ($r -ne 'Yes') { if ($isSwitch) { $ctl.IsChecked = (-not $want) }; return }
    }
    $ctl.IsEnabled = $false
    $win.Cursor = [Windows.Input.Cursors]::Wait
    Set-Status "Working on: $($it.Title)..."
    try {
        $out = if ($isSwitch) { if ($want) { @(& $it.On) } else { @(& $it.Off) } } else { @(& $it.Run) }
        $m = $out | Where-Object { $_ -is [string] -and $_ } | Select-Object -Last 1
        if (-not $m) { $m = if ($isSwitch) { "$($it.Title) turned $(if ($want) { 'on' } else { 'off' })." } else { "$($it.Title): done." } }
        Set-Status $m
        Write-ToolLog "$($it.Title) -> $m"
        if ($it.Restart) { $ui.restartBar.Visibility = 'Visible' }
    } catch {
        Set-Status "Could not complete '$($it.Title)': $($_.Exception.Message)"
        Write-ToolLog "[ERROR] $($it.Title): $($_.Exception.Message)"
    } finally {
        $win.Cursor = [Windows.Input.Cursors]::Arrow
        $ctl.IsEnabled = $true
    }
    if ($isSwitch) {
        try { $ctl.IsChecked = [bool](& $it.Get) } catch {}
    } else {
        $off = $ui.rowScroll.VerticalOffset
        Render-Rows
        $ui.rowScroll.UpdateLayout()
        $ui.rowScroll.ScrollToVerticalOffset($off)
    }
}

# ---------- List UI ----------
$script:RowXaml = @'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Border BorderBrush="#1E1E1E" BorderThickness="0,0,0,1" Padding="0,16,0,16">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="46"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel x:Name="bars" Orientation="Horizontal" VerticalAlignment="Top" Height="14" Margin="4,6,0,0"/>
      <StackPanel Grid.Column="1" Margin="0,0,18,0">
        <TextBlock x:Name="ttl" FontSize="15" FontWeight="SemiBold" Foreground="#F2F2F2" TextWrapping="Wrap"/>
        <TextBlock x:Name="dsc" FontSize="12.5" Foreground="#8E8E8E" TextWrapping="Wrap" Margin="0,4,0,0"/>
        <WrapPanel x:Name="tags" Margin="0,10,0,0"/>
      </StackPanel>
      <ContentControl x:Name="slot" Grid.Column="2" VerticalAlignment="Center"/>
    </Grid>
  </Border>
</Grid>
'@

function New-Row($it) {
    $g = [Windows.Markup.XamlReader]::Parse($script:RowXaml)
    $g.FindName('ttl').Text = $it.Title
    $g.FindName('dsc').Text = $it.Desc

    $bars = $g.FindName('bars')
    $heights = 5, 8, 11, 14
    for ($i = 0; $i -lt 4; $i++) {
        $r = New-Object Windows.Shapes.Rectangle
        $r.Width = 3; $r.Height = $heights[$i]; $r.RadiusX = 1; $r.RadiusY = 1
        $r.Margin = '0,0,2,0'; $r.VerticalAlignment = 'Bottom'
        $r.Fill = if ($i -lt $it.Impact) { $script:Bright } else { $script:BarOff }
        [void]$bars.Children.Add($r)
    }

    $tags = $g.FindName('tags')
    foreach ($t in $it.Tags) {
        $b = New-Object Windows.Controls.Border
        $b.BorderBrush = $script:ChipBrd
        $b.BorderThickness = New-Object Windows.Thickness 1
        $b.CornerRadius = New-Object Windows.CornerRadius 6
        $b.Padding = '9,3,9,3'; $b.Margin = '0,0,8,0'
        $tb = New-Object Windows.Controls.TextBlock
        $tb.Text = $t; $tb.FontSize = 11; $tb.Foreground = $script:ChipTxt
        $b.Child = $tb
        [void]$tags.Children.Add($b)
    }

    $slot = $g.FindName('slot')
    if ($it.Kind -eq 'switch') {
        $cb = New-Object Windows.Controls.CheckBox
        $cb.Style = $win.FindResource('Tgl')
        $cb.Tag = $it
        try { $cb.IsChecked = [bool](& $it.Get) } catch { $cb.IsChecked = $false }
        $cb.Add_Click({ param($s, $e) Invoke-Fix $s.Tag $s })
        $slot.Content = $cb
    } else {
        $btn = New-Object Windows.Controls.Button
        $btn.Style = $win.FindResource('Pill')
        $btn.Content = $it.Button
        $btn.Tag = $it
        $btn.Add_Click({ param($s, $e) Invoke-Fix $s.Tag $s })
        $slot.Content = $btn
    }
    return $g
}

function Render-Rows {
    $ui.rowPanel.Children.Clear()
    $q = $ui.txtSearch.Text.Trim().ToLower()
    $items = @($script:Items | Where-Object { $_.Page -eq $script:Page })
    $shown = 0
    foreach ($c in $script:Cats[$script:Page]) {
        if ($script:Cat -ne 'All' -and $script:Cat -ne $c) { continue }
        $grp = @($items | Where-Object { $_.Cat -eq $c -and ($q -eq '' -or ("$($_.Title) $($_.Desc)").ToLower().Contains($q)) })
        if ($grp.Count -eq 0) { continue }
        if ($script:Cat -eq 'All') {
            $h = New-Object Windows.Controls.StackPanel
            $h.Orientation = 'Horizontal'; $h.Margin = '0,18,0,6'
            $t1 = New-Object Windows.Controls.TextBlock
            $t1.Text = $c; $t1.FontSize = 20; $t1.FontWeight = 'Bold'; $t1.Foreground = $bc.ConvertFromString('#F2F2F2')
            $t2 = New-Object Windows.Controls.TextBlock
            $t2.Text = $script:CatDesc[$c]; $t2.FontSize = 13; $t2.Foreground = $script:Dim; $t2.Margin = '12,0,0,2'; $t2.VerticalAlignment = 'Bottom'
            [void]$h.Children.Add($t1); [void]$h.Children.Add($t2)
            [void]$ui.rowPanel.Children.Add($h)
        }
        foreach ($it in $grp) { [void]$ui.rowPanel.Children.Add((New-Row $it)); $shown++ }
    }
    if ($shown -eq 0) {
        $e = New-Object Windows.Controls.TextBlock
        $e.Text = 'Nothing matches your search.'; $e.Foreground = $script:Dim; $e.FontSize = 14; $e.Margin = '0,24,0,0'
        [void]$ui.rowPanel.Children.Add($e)
    }
}

function Build-Cats {
    $script:building = $true
    $ui.catPanel.Children.Clear()
    $items = @($script:Items | Where-Object { $_.Page -eq $script:Page })
    $entries = @(@{ Key = 'All'; Name = ('All ' + $script:PageNames[$script:Page]); Count = $items.Count })
    foreach ($c in $script:Cats[$script:Page]) {
        $entries += @{ Key = $c; Name = $c; Count = @($items | Where-Object { $_.Cat -eq $c }).Count }
    }
    foreach ($e in $entries) {
        $rb = New-Object Windows.Controls.RadioButton
        $rb.Style = $win.FindResource('Cat')
        $rb.GroupName = 'cat'
        $rb.Content = $e.Name
        $rb.Tag = [string]$e.Count
        $rb.DataContext = $e.Key
        if ($e.Key -eq $script:Cat) { $rb.IsChecked = $true }
        $rb.Add_Checked({ param($s, $a) if (-not $script:building) { $script:Cat = [string]$s.DataContext; Render-Rows } })
        [void]$ui.catPanel.Children.Add($rb)
    }
    $script:building = $false
}

function Show-Section($name) {
    $script:Page = $name
    if ($name -eq 'Home') {
        $ui.pageList.Visibility = 'Collapsed'
        $ui.pageHome.Visibility = 'Visible'
        Update-Live
    } else {
        $ui.pageHome.Visibility = 'Collapsed'
        $ui.pageList.Visibility = 'Visible'
        $ui.txtListTitle.Text = $script:PageTitle[$name][0]
        $ui.txtListSub.Text   = $script:PageTitle[$name][1]
        $ui.txtSearch.Text = ''
        $ui.txtSearchHint.Text = 'Search ' + $script:PageNames[$name]
        $ui.txtSearchHint.Visibility = 'Visible'
        $script:Cat = 'All'
        Build-Cats
        Render-Rows
    }
}

# ---------- Home: live ring + hardware ----------
$script:ticks = @()
function Initialize-Ring {
    $n = 72; $cx = 170; $cy = 170; $r1 = 134; $r2 = 156
    for ($i = 0; $i -lt $n; $i++) {
        $deg = 135 + (270 * $i / ($n - 1))
        $rad = $deg * [math]::PI / 180
        $ln = New-Object Windows.Shapes.Line
        $ln.X1 = $cx + $r1 * [math]::Cos($rad); $ln.Y1 = $cy + $r1 * [math]::Sin($rad)
        $ln.X2 = $cx + $r2 * [math]::Cos($rad); $ln.Y2 = $cy + $r2 * [math]::Sin($rad)
        $ln.StrokeThickness = 3
        $ln.StrokeStartLineCap = 'Round'; $ln.StrokeEndLineCap = 'Round'
        $ln.Stroke = $script:Faint
        [void]$ui.ringCanvas.Children.Add($ln)
        $script:ticks += $ln
    }
}
try {
    $script:cpuCtr = New-Object System.Diagnostics.PerformanceCounter -ArgumentList 'Processor', '% Processor Time', '_Total'
    [void]$script:cpuCtr.NextValue()
} catch { $script:cpuCtr = $null }

function Update-Live {
    if ($ui.pageHome.Visibility -ne 'Visible') { return }
    try {
        $cpu = 0
        if ($script:cpuCtr) { $cpu = [int][math]::Round($script:cpuCtr.NextValue()) }
        $cpu = [math]::Min(100, [math]::Max(0, $cpu))
        $lit = [int][math]::Round($script:ticks.Count * $cpu / 100)
        for ($i = 0; $i -lt $script:ticks.Count; $i++) {
            $script:ticks[$i].Stroke = if ($i -lt $lit) { $script:Bright } else { $script:Faint }
        }
        $ui.txtCpu.Text = [string]$cpu

        $os = Get-CimInstance Win32_OperatingSystem
        $totalGB = $os.TotalVisibleMemorySize / 1MB
        $usedGB  = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB
        $ui.txtMem.Text   = '{0:N1}' -f $usedGB
        $ui.txtMemOf.Text = '/ {0:N0} GB' -f $totalGB

        $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        if ($c) { $ui.txtDisk.Text = [string][math]::Round($c.FreeSpace / 1GB) }

        $up = (Get-Date) - $os.LastBootUpTime
        $ui.txtUptime.Text = if ($up.Days -gt 0) { '{0}d {1}h' -f $up.Days, $up.Hours } else { '{0}h {1}m' -f $up.Hours, $up.Minutes }
    } catch {}
}

function Initialize-Hardware {
    try {
        $c = Get-CimInstance Win32_Processor | Select-Object -First 1
        $ui.hwCpu.Text = $c.Name.Trim()
        $ui.hwCpuSub.Text = '{0} cores / {1} threads' -f $c.NumberOfCores, $c.NumberOfLogicalProcessors
    } catch { $ui.hwCpu.Text = 'Unavailable' }
    try {
        $g = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Remote|Virtual' } | Select-Object -First 1
        if ($g) { $ui.hwGpu.Text = $g.Name; $ui.hwGpuSub.Text = "Driver $($g.DriverVersion)" } else { $ui.hwGpu.Text = 'Integrated graphics' }
    } catch { $ui.hwGpu.Text = 'Unavailable' }
    try {
        $mods = @(Get-CimInstance Win32_PhysicalMemory)
        $tot = [math]::Round(($mods | Measure-Object Capacity -Sum).Sum / 1GB)
        $m0 = $mods | Select-Object -First 1
        $type = switch ([int]$m0.SMBIOSMemoryType) { 24 {'DDR3'} 26 {'DDR4'} 34 {'DDR5'} default {'RAM'} }
        $speed = if ($m0.ConfiguredClockSpeed) { $m0.ConfiguredClockSpeed } else { $m0.Speed }
        $ui.hwMem.Text = "$tot GB $type"
        $ui.hwMemSub.Text = "$($mods.Count) stick(s) at $speed MT/s"
    } catch { $ui.hwMem.Text = 'Unavailable' }
    try {
        $d = Get-PhysicalDisk -ErrorAction Stop | Select-Object -First 1
        $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        $ui.hwDisk.Text = $d.FriendlyName
        $ui.hwDiskSub.Text = '{0} - {1} GB free of {2} GB' -f $d.MediaType, [math]::Round($c.FreeSpace / 1GB), [math]::Round($c.Size / 1GB)
    } catch { $ui.hwDisk.Text = 'Unavailable' }
}

# ---------- Wiring ----------
$ui.navHome.Add_Checked({ Show-Section 'Home' })
$ui.navFixes.Add_Checked({ Show-Section 'Fixes' })
$ui.navApps.Add_Checked({ Show-Section 'Apps' })
$ui.navSupport.Add_Checked({ Show-Section 'Support' })

$ui.btnHomeFixes.Add_Click({ $ui.navFixes.IsChecked = $true })
$ui.btnHomeSupport.Add_Click({ $ui.navSupport.IsChecked = $true })

$ui.txtSearch.Add_TextChanged({
    $ui.txtSearchHint.Visibility = if ($ui.txtSearch.Text.Length -gt 0) { 'Collapsed' } else { 'Visible' }
    if ($script:Page -ne 'Home') { Render-Rows }
})

$ui.btnUndo.Add_Click({
    try { Start-Process rstrui.exe; Write-ToolLog 'Opened System Restore (sidebar)' } catch { Set-Status 'Could not open System Restore.' }
})
$ui.btnRestart.Add_Click({
    $r = [Windows.MessageBox]::Show('Restart this PC now? Save any open work first.', 'Hexa', 'YesNo', 'Question')
    if ($r -eq 'Yes') {
        Write-ToolLog 'Restart requested from Hexa Tools'
        Start-Process shutdown.exe -ArgumentList '/r /t 15 /c "Hexa Tools: restarting to finish applying changes"' -WindowStyle Hidden
    }
})

$script:Page = 'Home'
$script:Cat = 'All'
$script:building = $false

Initialize-Ring

$script:timer = New-Object System.Windows.Threading.DispatcherTimer
$script:timer.Interval = [TimeSpan]::FromSeconds(2)
$script:timer.Add_Tick({ Update-Live })
$script:timer.Start()

$win.Add_ContentRendered({
    if ($script:started) { return }
    $script:started = $true
    Initialize-Hardware
    Update-Live
    Write-ToolLog 'Hexa Tools opened'
})
$win.Add_Closed({ try { $script:timer.Stop() } catch {} })

[void]$win.ShowDialog()
