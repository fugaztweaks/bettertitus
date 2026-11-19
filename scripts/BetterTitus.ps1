# ==============================================================================
# BetterTitus - by fugaztweaks (Version 0.8 Beta - Revised)
# Windows Optimization, Fast Deep Cleanup & Competitive Gaming Utility
# ==============================================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath) -and (Test-Path $PSCommandPath)) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        $tempRunner = Join-Path $env:TEMP "BetterTitus_RunAs.ps1"
        $MyInvocation.MyCommand.ScriptBlock.ToString() | Set-Content -Path $tempRunner -Encoding UTF8 -Force
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& '$tempRunner'; Remove-Item '$tempRunner' -Force -ErrorAction SilentlyContinue`"" -Verb RunAs
    }
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
$script:HasDrawing = $false
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $script:HasDrawing = $true
} catch {
    Write-Warning "[BetterTitus] System.Drawing indisponível; usando fallback vetorial para ícone."
}

# ==============================================================================
# DIRETÓRIO SEGURO E ARQUIVOS DE BACKUP / CONFIGURAÇÃO
# ==============================================================================
$script:ConfigDir       = "$env:ProgramData\BetterTitus"
$script:SettingsJson    = "$script:ConfigDir\settings.json"
$script:GamesJson       = "$script:ConfigDir\games.json"
$script:IconPath        = "$script:ConfigDir\BetterTitus.ico"
$script:CleanerDll      = "$script:ConfigDir\FastCleaner.dll"
$script:SvcBackup       = "$script:ConfigDir\services_backup.json"
$script:CoreSvcBackup   = "$script:ConfigDir\core_services_backup.json"
$script:TasksBackup     = "$script:ConfigDir\tasks_backup.json"
$script:MmBackup        = "$script:ConfigDir\mmprofile_backup.json"
$script:CrashBackup     = "$script:ConfigDir\crashcontrol_backup.json"
$script:Ipv6Backup      = "$script:ConfigDir\ipv6_backup.json"
$script:PowerBackup     = "$script:ConfigDir\power_backup.json"

if (-not (Test-Path $script:ConfigDir)) {
    New-Item -Path $script:ConfigDir -ItemType Directory -Force | Out-Null
}
& icacls.exe $script:ConfigDir /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-32-545:(OI)(CI)RX" | Out-Null

# ==============================================================================
# LOG NO CONSOLE POWERSHELL
# ==============================================================================
function Write-BTLog ([string]$Message, [string]$Level = "INFO") {
    $time = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "OK"      { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "PARTIAL" { "DarkYellow" }
        "HEADER"  { "Magenta" }
        default   { "Cyan" }
    }
    Write-Host "[$time] " -NoNewline -ForegroundColor DarkGray
    Write-Host "[$Level] " -NoNewline -ForegroundColor $color
    Write-Host $Message -ForegroundColor White
}

Clear-Host
Write-Host "==============================================================================" -ForegroundColor Magenta
Write-Host "  BetterTitus v0.8 Beta (Revised) - by fugaztweaks" -ForegroundColor White
Write-Host "  Console Verbose Output Active | Todos os logs serao exibidos aqui" -ForegroundColor DarkGray
Write-Host "==============================================================================" -ForegroundColor Magenta

# ==============================================================================
# RESOLUÇÃO DO PERFIL INTERATIVO REAL (CORREÇÃO HKCU ELEVADO)
# ==============================================================================
function Resolve-InteractiveUserContext {
    $regRoot = "HKCU:"
    $userName = $env:USERNAME
    $userProfile = $env:USERPROFILE
    try {
        $csUser = (Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 4 -ErrorAction Stop).UserName
        if (-not [string]::IsNullOrWhiteSpace($csUser)) {
            $userName = $csUser
            $ntAcc = New-Object System.Security.Principal.NTAccount($csUser)
            $sid = $ntAcc.Translate([System.Security.Principal.SecurityIdentifier]).Value
            if (Test-Path "Registry::HKEY_USERS\$sid") {
                $regRoot = "Registry::HKEY_USERS\$sid"
            }
            $profPath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" -Name "ProfileImagePath" -ErrorAction SilentlyContinue).ProfileImagePath
            if (-not [string]::IsNullOrWhiteSpace($profPath)) {
                $userProfile = $profPath
            }
        }
    } catch {
        Write-BTLog "Aviso ao resolver perfil interativo via WMI: $($_.Exception.Message)" "WARN"
    }
    return [PSCustomObject]@{
        UserName    = $userName
        RegRoot     = $regRoot
        UserProfile = $userProfile
    }
}

$script:UserCtx = Resolve-InteractiveUserContext
Write-BTLog "Perfil Interativo: $($script:UserCtx.UserName) | Pasta: $($script:UserCtx.UserProfile) | Root: $($script:UserCtx.RegRoot)" "INFO"

function Resolve-RegPath ([string]$Path) {
    if ($Path -like "HKCU:\*") {
        return ($script:UserCtx.RegRoot + "\" + $Path.Substring(6))
    }
    return $Path
}

function Set-Reg ([string]$Path, [string]$Name, $Value, [string]$Type = "DWord") {
    $resolved = Resolve-RegPath $Path
    if (-not (Test-Path $resolved)) { New-Item -Path $resolved -Force -ErrorAction Stop | Out-Null }
    Set-ItemProperty -Path $resolved -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
}

function Get-Reg ([string]$Path, [string]$Name, $Default = $null) {
    try {
        $resolved = Resolve-RegPath $Path
        if (Test-Path $resolved) {
            $prop = Get-ItemProperty -Path $resolved -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $prop) {
                $pInfo = $prop.PSObject.Properties[$Name]
                if ($null -ne $pInfo -and $null -ne $pInfo.Value) {
                    return $pInfo.Value
                }
            }
        }
    } catch {
        Write-BTLog "Erro ao ler registro [$Path -> $Name]: $($_.Exception.Message)" "WARN"
    }
    return $Default
}

function Remove-RegValueSafe ([string]$Path, [string]$Name) {
    try {
        $resolved = Resolve-RegPath $Path
        if (Test-Path $resolved) {
            Remove-ItemProperty -Path $resolved -Name $Name -ErrorAction SilentlyContinue
            $item = Get-Item -Path $resolved -ErrorAction SilentlyContinue
            if ($null -ne $item -and $item.Property.Count -eq 0 -and $item.SubKeyCount -eq 0) {
                Remove-Item -Path $resolved -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-BTLog "Erro ao remover valor [$Path -> $Name]: $($_.Exception.Message)" "WARN"
    }
}

# ==============================================================================
# MOTOR NATIVO C# (CACHEADO EM DLL COM TRATAMENTO DE ERROS E REPARSE POINTS)
# ==============================================================================
$csSource = @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;

namespace BetterTitus {
    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);

        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

        public static void BroadcastSettingsChange() {
            UIntPtr res;
            SendMessageTimeout(new IntPtr(0xffff), 0x001A, UIntPtr.Zero, "ImmersiveColorSet", 0x0002, 1000, out res);
            SendMessageTimeout(new IntPtr(0xffff), 0x001A, UIntPtr.Zero, "Policy", 0x0002, 1000, out res);
            SHChangeNotify(0x08000000, 0x0000, IntPtr.Zero, IntPtr.Zero);
        }

        public static void SetMouseAccel(bool enable) {
            int[] mouseParams = new int[3];
            mouseParams[0] = enable ? 6 : 0;
            mouseParams[1] = enable ? 10 : 0;
            mouseParams[2] = enable ? 1 : 0;
            GCHandle handle = GCHandle.Alloc(mouseParams, GCHandleType.Pinned);
            try {
                SystemParametersInfo(0x0004, 0, handle.AddrOfPinnedObject(), 0x01 | 0x02);
            } finally {
                handle.Free();
            }
        }
    }

    public static class FastCleaner {
        private static IEnumerable<string> ResolveTargets(string pattern) {
            if (string.IsNullOrWhiteSpace(pattern)) yield break;
            pattern = Environment.ExpandEnvironmentVariables(pattern);

            int wildIdx = pattern.IndexOfAny(new char[] { '*', '?' });
            if (wildIdx == -1) {
                if (File.Exists(pattern) || Directory.Exists(pattern)) yield return pattern;
                yield break;
            }

            int lastSlash = pattern.LastIndexOf('\\', wildIdx);
            if (lastSlash < 0) yield break;

            string root = pattern.Substring(0, lastSlash);
            if (!Directory.Exists(root)) yield break;

            string rest = pattern.Substring(lastSlash + 1);
            string[] parts = rest.Split(new char[] { '\\' }, StringSplitOptions.RemoveEmptyEntries);

            List<string> current = new List<string> { root };
            for (int i = 0; i < parts.Length; i++) {
                List<string> next = new List<string>();
                bool isLast = (i == parts.Length - 1);
                string seg = parts[i];

                foreach (string dir in current) {
                    try {
                        DirectoryInfo di = new DirectoryInfo(dir);
                        if ((di.Attributes & FileAttributes.ReparsePoint) != 0) continue;

                        if (isLast) {
                            foreach (string f in Directory.EnumerateFiles(dir, seg, SearchOption.TopDirectoryOnly))
                                next.Add(f);
                            foreach (string d in Directory.EnumerateDirectories(dir, seg, SearchOption.TopDirectoryOnly))
                                next.Add(d);
                        } else {
                            foreach (string d in Directory.EnumerateDirectories(dir, seg, SearchOption.TopDirectoryOnly)) {
                                DirectoryInfo subDi = new DirectoryInfo(d);
                                if ((subDi.Attributes & FileAttributes.ReparsePoint) == 0)
                                    next.Add(d);
                            }
                        }
                    } catch (UnauthorizedAccessException) { }
                      catch (IOException) { }
                }
                current = next;
                if (current.Count == 0) break;
            }

            foreach (string item in current) yield return item;
        }

        private static long GetDirSizeSafe(DirectoryInfo dir) {
            long total = 0;
            try {
                if ((dir.Attributes & FileAttributes.ReparsePoint) != 0) return 0;
                foreach (FileInfo fi in dir.EnumerateFiles("*", SearchOption.TopDirectoryOnly)) {
                    try { total += fi.Length; }
                    catch (UnauthorizedAccessException) { }
                    catch (IOException) { }
                }
                foreach (DirectoryInfo sub in dir.EnumerateDirectories("*", SearchOption.TopDirectoryOnly)) {
                    total += GetDirSizeSafe(sub);
                }
            } catch (UnauthorizedAccessException) { }
              catch (IOException) { }
            return total;
        }

        public static long GetPatternSize(string[] patterns) {
            long total = 0;
            if (patterns == null) return 0;
            foreach (string pat in patterns) {
                foreach (string target in ResolveTargets(pat)) {
                    try {
                        if (File.Exists(target)) {
                            total += new FileInfo(target).Length;
                        } else if (Directory.Exists(target)) {
                            total += GetDirSizeSafe(new DirectoryInfo(target));
                        }
                    } catch (UnauthorizedAccessException) { }
                      catch (IOException) { }
                }
            }
            return total;
        }

        private static void DeleteDirSafe(DirectoryInfo dir, bool removeRoot) {
            try {
                if ((dir.Attributes & FileAttributes.ReparsePoint) != 0) return;
                foreach (FileInfo fi in dir.EnumerateFiles("*", SearchOption.TopDirectoryOnly)) {
                    try {
                        fi.Attributes = FileAttributes.Normal;
                        fi.Delete();
                    } catch (UnauthorizedAccessException) { }
                      catch (IOException) { }
                }
                foreach (DirectoryInfo sub in dir.EnumerateDirectories("*", SearchOption.TopDirectoryOnly)) {
                    DeleteDirSafe(sub, true);
                }
                if (removeRoot) {
                    try { dir.Delete(false); }
                    catch (UnauthorizedAccessException) { }
                    catch (IOException) { }
                }
            } catch (UnauthorizedAccessException) { }
              catch (IOException) { }
        }

        public static void CleanPattern(string[] patterns) {
            if (patterns == null) return;
            foreach (string pat in patterns) {
                bool isWildcardContent = pat.EndsWith("\\*");
                foreach (string target in ResolveTargets(pat)) {
                    try {
                        if (File.Exists(target)) {
                            FileInfo fi = new FileInfo(target);
                            fi.Attributes = FileAttributes.Normal;
                            fi.Delete();
                        } else if (Directory.Exists(target)) {
                            DeleteDirSafe(new DirectoryInfo(target), !isWildcardContent || pat.IndexOf('*') < pat.Length - 1);
                        }
                    } catch (UnauthorizedAccessException) { }
                      catch (IOException) { }
                }
            }
        }
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'BetterTitus.FastCleaner').Type) {
    if (Test-Path $script:CleanerDll) {
        try {
            Add-Type -Path $script:CleanerDll -ErrorAction Stop
        } catch {
            Write-BTLog "Cache FastCleaner.dll inválido ou desatualizado; recompilando: $($_.Exception.Message)" "WARN"
            Remove-Item $script:CleanerDll -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not ([System.Management.Automation.PSTypeName]'BetterTitus.FastCleaner').Type) {
        try {
            Add-Type -TypeDefinition $csSource -OutputAssembly $script:CleanerDll -OutputType Library -ErrorAction Stop
            Add-Type -Path $script:CleanerDll -ErrorAction Stop
        } catch {
            Write-BTLog "Falha ao salvar DLL em disco ($($_.Exception.Message)); compilando em memória." "WARN"
            Add-Type -TypeDefinition $csSource -ErrorAction Stop
        }
    }
}

# ==============================================================================
# GERADOR DE ÍCONE PERSONALIZADO (.ICO 256x256 - COM FALLBACK SEGURO)
# ==============================================================================
function Ensure-BetterTitusIcon ([string]$OutIcoPath) {
    if (Test-Path $OutIcoPath) { return }
    if (-not $script:HasDrawing) { return }
    try {
        $size = 256
        $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.Clear([System.Drawing.Color]::Transparent)

        $rect = New-Object System.Drawing.Rectangle(12, 12, 232, 232)
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $d = 56
        $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
        $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
        $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
        $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
        $path.CloseFigure()

        $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(255, 34, 24, 62), [System.Drawing.Color]::FromArgb(255, 109, 40, 217), 45.0)
        $g.FillPath($bgBrush, $path)

        $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 167, 139, 250), 8)
        $g.DrawPath($borderPen, $path)

        $boltPts = [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF(146, 44)),
            (New-Object System.Drawing.PointF(76, 138)),
            (New-Object System.Drawing.PointF(126, 138)),
            (New-Object System.Drawing.PointF(106, 212)),
            (New-Object System.Drawing.PointF(182, 114)),
            (New-Object System.Drawing.PointF(132, 114))
        )
        $boltBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.Point(76, 44)),
            (New-Object System.Drawing.Point(182, 212)),
            [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
            [System.Drawing.Color]::FromArgb(255, 216, 180, 254)
        )
        $g.FillPolygon($boltBrush, $boltPts)

        $pngMs = New-Object System.IO.MemoryStream
        $bmp.Save($pngMs, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBytes = $pngMs.ToArray()

        $icoMs = New-Object System.IO.MemoryStream
        $bw = New-Object System.IO.BinaryWriter($icoMs)
        $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)
        $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$pngBytes.Length); $bw.Write([uint32]22)
        $bw.Write($pngBytes); $bw.Flush()

        [System.IO.File]::WriteAllBytes($OutIcoPath, $icoMs.ToArray())
        $bw.Dispose(); $icoMs.Dispose(); $pngMs.Dispose()
        $borderPen.Dispose(); $boltBrush.Dispose(); $bgBrush.Dispose(); $path.Dispose(); $g.Dispose(); $bmp.Dispose()
    } catch {
        Write-BTLog "Falha ao gerar ícone personalizado: $($_.Exception.Message)" "WARN"
    }
}

Ensure-BetterTitusIcon $script:IconPath

# ==============================================================================
# INTERFACE XAML (COM DYNAMICRESOURCES PARA TEMAS DARK & LIGHT COMPLETOS)
# ==============================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="BetterTitus - by fugaztweaks (Version 0.8 Beta)" 
        Height="860" Width="1360" MinHeight="720" MinWidth="1180"
        WindowStartupLocation="CenterScreen" 
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        FontFamily="Segoe UI"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True"
        TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType">

    <Window.Resources>
        <SolidColorBrush x:Key="BgMain" Color="#111017"/>
        <SolidColorBrush x:Key="BgPanel" Color="#171520"/>
        <SolidColorBrush x:Key="BgCard" Color="#111017"/>
        <SolidColorBrush x:Key="BgCardHover" Color="#211D30"/>
        <SolidColorBrush x:Key="BgCardSelected" Color="#282042"/>
        <SolidColorBrush x:Key="BgHeader" Color="#0C0B10"/>
        <SolidColorBrush x:Key="BgInput" Color="#221E30"/>
        <SolidColorBrush x:Key="BgBtn" Color="#221E30"/>
        <SolidColorBrush x:Key="BgBtnHover" Color="#2F2944"/>
        <SolidColorBrush x:Key="BgBtnActive" Color="#7C3AED"/>
        <SolidColorBrush x:Key="BorderSubtle" Color="#2E2942"/>
        <SolidColorBrush x:Key="BorderHighlight" Color="#8B5CF6"/>
        <SolidColorBrush x:Key="TextMain" Color="#F3F4F6"/>
        <SolidColorBrush x:Key="TextDim" Color="#9CA3AF"/>
        <SolidColorBrush x:Key="PurpleHeader" Color="#A78BFA"/>
        <SolidColorBrush x:Key="PurpleAccent" Color="#7C3AED"/>

        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="{DynamicResource BgPanel}"/>
            <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderHighlight}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="MaxWidth" Value="420"/>
            <Setter Property="HasDropShadow" Value="True"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToolTip">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <TextBlock Text="{TemplateBinding Content}" TextWrapping="Wrap" LineHeight="17"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="BTButton" TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource BgBtn}"/>
            <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderSubtle}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="14,6"/>
            <Setter Property="Margin" Value="0,0,6,4"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource BgBtnHover}"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource BorderHighlight}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="{DynamicResource BgBtnActive}"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="NavTabBtn" TargetType="Button" BasedOn="{StaticResource BTButton}">
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="14,5"/>
            <Setter Property="Margin" Value="2.5,0"/>
        </Style>

        <Style x:Key="BTCheck" TargetType="CheckBox">
            <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Margin" Value="0,3,0,3"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="ToolTipService.InitialShowDelay" Value="250"/>
            <Setter Property="ToolTipService.ShowDuration" Value="20000"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Background="Transparent">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="22"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Border x:Name="chkBox" Width="14" Height="14" CornerRadius="3"
                                    Background="{DynamicResource BgInput}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1"
                                    VerticalAlignment="Center" HorizontalAlignment="Left">
                                <Path x:Name="chkMark" Data="M 2.5,6.5 L 5.5,9.5 L 11.5,3.5" Stroke="#FFFFFF" StrokeThickness="1.8" Visibility="Collapsed"/>
                            </Border>
                            <ContentPresenter Grid.Column="1" VerticalAlignment="Center" Margin="2,0,0,0"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="chkBox" Property="BorderBrush" Value="{DynamicResource BorderHighlight}"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="chkBox" Property="Background" Value="#7C3AED"/>
                                <Setter TargetName="chkBox" Property="BorderBrush" Value="#A78BFA"/>
                                <Setter TargetName="chkMark" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="BTToggleSwitch" TargetType="CheckBox">
            <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Margin" Value="0,4,0,4"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="ToolTipService.InitialShowDelay" Value="250"/>
            <Setter Property="ToolTipService.ShowDuration" Value="20000"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Background="Transparent">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="46"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Border x:Name="Track" Grid.Column="0" Width="38" Height="19" CornerRadius="9.5"
                                    Background="{DynamicResource BgInput}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1"
                                    VerticalAlignment="Center" HorizontalAlignment="Left">
                                <Ellipse x:Name="Thumb" Width="13" Height="13" Fill="#A39EB8"
                                         HorizontalAlignment="Left" VerticalAlignment="Center" Margin="2,0,0,0"
                                         RenderOptions.BitmapScalingMode="HighQuality">
                                    <Ellipse.RenderTransform>
                                        <TranslateTransform x:Name="ThumbTransform" X="0"/>
                                    </Ellipse.RenderTransform>
                                </Ellipse>
                            </Border>
                            <ContentPresenter Grid.Column="1" VerticalAlignment="Center" Margin="4,0,0,0"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Track" Property="BorderBrush" Value="{DynamicResource BorderHighlight}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Track" Property="Background" Value="#7C3AED"/>
                                <Setter TargetName="Track" Property="BorderBrush" Value="#A78BFA"/>
                                <Setter TargetName="Thumb" Property="Fill" Value="#FFFFFF"/>
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="ThumbTransform" Storyboard.TargetProperty="X" To="19" Duration="0:0:0.14">
                                                <DoubleAnimation.EasingFunction>
                                                    <QuadraticEase EasingMode="EaseOut"/>
                                                </DoubleAnimation.EasingFunction>
                                            </DoubleAnimation>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="ThumbTransform" Storyboard.TargetProperty="X" To="0" Duration="0:0:0.14">
                                                <DoubleAnimation.EasingFunction>
                                                    <QuadraticEase EasingMode="EaseOut"/>
                                                </DoubleAnimation.EasingFunction>
                                            </DoubleAnimation>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="GameListBoxItemStyle" TargetType="ListBoxItem">
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Padding" Value="0"/>
            <Setter Property="Margin" Value="0,0,0,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="ItemBorder" Background="{DynamicResource BgCard}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="5" Padding="14,10">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="{DynamicResource BgCardHover}"/>
                                <Setter TargetName="ItemBorder" Property="BorderBrush" Value="{DynamicResource BorderHighlight}"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="{DynamicResource BgCardSelected}"/>
                                <Setter TargetName="ItemBorder" Property="BorderBrush" Value="{DynamicResource BorderHighlight}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <!-- Borda Externa da Janela -->
    <Border x:Name="RootBorder" Background="{DynamicResource BgMain}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="5">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="46"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="64"/>
            </Grid.RowDefinitions>

            <!-- 1. BARRA SUPERIOR -->
            <Border Grid.Row="0" x:Name="TitleBar" Background="{DynamicResource BgHeader}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="0,0,0,1">
                <Grid Margin="12,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <!-- Ícone Vetorial Oficial BetterTitus -->
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,12,0">
                        <Border Width="30" Height="30" CornerRadius="6" BorderBrush="#A78BFA" BorderThickness="1" Margin="0,0,9,0">
                            <Border.Background>
                                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                    <GradientStop Color="#231842" Offset="0.0"/>
                                    <GradientStop Color="#7C3AED" Offset="1.0"/>
                                </LinearGradientBrush>
                            </Border.Background>
                            <Viewbox Width="18" Height="18" HorizontalAlignment="Center" VerticalAlignment="Center">
                                <Canvas Width="24" Height="24">
                                    <Path Data="M13.5,2 L5,13.5 L11,13.5 L9.5,22 L19,10.5 L13,10.5 Z" Fill="#FFFFFF">
                                        <Path.Effect>
                                            <DropShadowEffect Color="#C4B5FD" BlurRadius="6" ShadowDepth="0" Opacity="0.85"/>
                                        </Path.Effect>
                                    </Path>
                                </Canvas>
                            </Viewbox>
                        </Border>
                        <StackPanel VerticalAlignment="Center">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="BetterTitus" Foreground="{DynamicResource TextMain}" FontWeight="Bold" FontSize="13.5"/>
                                <Border Background="{DynamicResource BgInput}" BorderBrush="{DynamicResource BorderHighlight}" BorderThickness="1" CornerRadius="3" Padding="5,0" Margin="6,0,0,0" VerticalAlignment="Center">
                                    <TextBlock Text="Version 0.8 Beta" Foreground="{DynamicResource PurpleHeader}" FontSize="10" FontWeight="SemiBold"/>
                                </Border>
                            </StackPanel>
                            <TextBlock Text="by fugaztweaks" Foreground="{DynamicResource TextDim}" FontSize="10" Margin="0,-1,0,0"/>
                        </StackPanel>
                    </StackPanel>

                    <!-- Abas de Navegação -->
                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="BtnNavTweaks" Content="Tweaks" Style="{StaticResource NavTabBtn}" Background="#7C3AED" Foreground="#FFFFFF" BorderBrush="#A78BFA"/>
                        <Button x:Name="BtnNavGaming" Content="Gaming" Style="{StaticResource NavTabBtn}"/>
                        <Button x:Name="BtnNavDeepClean" Content="Deep Clean" Style="{StaticResource NavTabBtn}"/>
                        <Button x:Name="BtnNavAdvanced" Content="Advanced" Style="{StaticResource NavTabBtn}"/>
                    </StackPanel>

                    <!-- Barra de Busca Central Global -->
                    <Border Grid.Column="2" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Height="28" Margin="14,0">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="30"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="TxtSearch" Grid.Column="0" Background="Transparent" Foreground="{DynamicResource TextMain}" BorderThickness="0" VerticalContentAlignment="Center" Padding="8,0" FontSize="12" CaretBrush="{DynamicResource TextMain}"/>
                            <TextBlock x:Name="LblSearchPlaceholder" Grid.Column="0" Text="Search tweaks, games or cleanup..." Foreground="{DynamicResource TextDim}" VerticalAlignment="Center" Margin="10,0,0,0" IsHitTestVisible="False">
                                <TextBlock.Style>
                                    <Style TargetType="TextBlock">
                                        <Setter Property="Visibility" Value="Collapsed"/>
                                        <Style.Triggers>
                                            <DataTrigger Binding="{Binding Text, ElementName=TxtSearch}" Value="">
                                                <Setter Property="Visibility" Value="Visible"/>
                                            </DataTrigger>
                                        </Style.Triggers>
                                    </Style>
                                </TextBlock.Style>
                            </TextBlock>
                            <TextBlock Grid.Column="1" Text="🔍" FontSize="11" Foreground="{DynamicResource PurpleHeader}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Grid>
                    </Border>

                    <!-- Seletor de Idioma -->
                    <Border Grid.Column="3" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Height="28" Margin="0,0,10,0" Padding="2">
                        <StackPanel Orientation="Horizontal">
                            <Button x:Name="BtnLangEN" Content="English" Style="{StaticResource BTButton}" Margin="0" Padding="9,2" BorderThickness="0"/>
                            <Button x:Name="BtnLangPT" Content="Português (BR)" Style="{StaticResource BTButton}" Margin="2,0,0,0" Padding="9,2" BorderThickness="0"/>
                        </StackPanel>
                    </Border>

                    <!-- Botões de Controle da Janela -->
                    <StackPanel Grid.Column="4" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="BtnTheme" Content="☀" Style="{StaticResource BTButton}" Width="28" Padding="0,3" Margin="2,0"/>
                        <Button x:Name="BtnMin" Content="—" Style="{StaticResource BTButton}" Width="28" Padding="0,3" Margin="2,0"/>
                        <Button x:Name="BtnMax" Content="▢" Style="{StaticResource BTButton}" Width="28" Padding="0,3" Margin="2,0"/>
                        <Button x:Name="BtnClose" Content="✕" Style="{StaticResource BTButton}" Width="28" Padding="0,3" Margin="2,0"/>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- ====================================================================== -->
            <!-- ABA 1: TWEAKS                                                          -->
            <!-- ====================================================================== -->
            <Grid Grid.Row="1" x:Name="ViewTweaks" Visibility="Visible" Margin="12,8,12,6">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <Grid Grid.Row="0" Margin="0,0,0,6">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="LblRecTitle" Text="Recommended Selections:" Foreground="{DynamicResource PurpleHeader}" FontSize="12" FontWeight="SemiBold" Margin="2,0,0,4"/>
                        <WrapPanel Orientation="Horizontal">
                            <Button x:Name="BtnPresetStd" Content="Standard" Style="{StaticResource BTButton}"/>
                            <Button x:Name="BtnPresetMin" Content="Minimal" Style="{StaticResource BTButton}"/>
                            <Button x:Name="BtnPresetAdv" Content="Advanced" Style="{StaticResource BTButton}"/>
                            <Button x:Name="BtnPresetClr" Content="Clear" Style="{StaticResource BTButton}"/>
                            <Button x:Name="BtnSelectInstalled" Content="Detect Active Optimizations" Style="{StaticResource BTButton}" BorderBrush="#7C3AED"/>
                        </WrapPanel>
                    </StackPanel>

                    <StackPanel Grid.Column="1" HorizontalAlignment="Right">
                        <TextBlock x:Name="LblNativeTools" Text="Native Windows Tools:" Foreground="{DynamicResource PurpleHeader}" FontSize="12" FontWeight="SemiBold" Margin="2,0,0,4"/>
                        <WrapPanel Orientation="Horizontal">
                            <Button x:Name="BtnOpenCleanmgr" Content="🧹 Disk Cleanup (cleanmgr)" Style="{StaticResource BTButton}" BorderBrush="#8B5CF6"/>
                            <Button x:Name="BtnCreateRestore" Content="🛡️ Create Restore Point" Style="{StaticResource BTButton}" BorderBrush="#8B5CF6" Margin="0,0,0,4"/>
                        </WrapPanel>
                    </StackPanel>
                </Grid>

                <Grid Grid.Row="1">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.06*"/>
                        <ColumnDefinition Width="0.94*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Coluna Esquerda -->
                    <Border Grid.Column="0" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Margin="0,0,5,0" Padding="16,12">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel x:Name="PanelLeft">
                                <TextBlock x:Name="HdrEssential" Text="Essential Tweaks" FontFamily="Consolas" FontSize="15" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,6"/>
                                
                                <CheckBox x:Name="ChkActivity" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkConsumer" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkDelivery" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkEndTask" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkFolderDisc" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkHibernation" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkLocation" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkMemCompression" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkStoreSearch" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkDeviceCompanion" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkServicesMan" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkTelemetry" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkWidgets" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkWPBT" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkSearchIdx" Style="{StaticResource BTCheck}"/>

                                <TextBlock x:Name="HdrAdvCaution" Text="Advanced Tweaks - CAUTION" FontFamily="Consolas" FontSize="15" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,14,0,6"/>

                                <CheckBox x:Name="ChkBgApps" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkOptTasks" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkReservedStorage" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkExplorerGallery" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkGameDVR" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkIPv4Pref" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkTeredo" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkMenuDelay" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkEdgeDebloat" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkNetThrottle" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkPowerThrottle" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkClassicContext" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkStorageSense" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkSvcHost" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkUsbSuspend" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkBestPerf" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkWinAI" Style="{StaticResource BTCheck}"/>

                                <TextBlock x:Name="HdrSecOverhead" Text="Security &amp; CPU Overhead (Confirmation Required)" FontFamily="Consolas" FontSize="14.5" FontWeight="Bold" Foreground="#F59E0B" Margin="0,14,0,6"/>
                                <CheckBox x:Name="ChkBitLocker" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkHVCI" Style="{StaticResource BTCheck}"/>
                                <CheckBox x:Name="ChkCpuMitigations" Style="{StaticResource BTCheck}"/>

                                <Grid Margin="0,14,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="220"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock x:Name="LblDnsSet" Grid.Column="0" Text="DNS - Set to:" Foreground="{DynamicResource PurpleHeader}" VerticalAlignment="Center" Margin="0,0,10,0" FontSize="12" FontWeight="SemiBold"/>
                                    <ComboBox x:Name="CmbDNS" Grid.Column="1" SelectedIndex="0" Height="26" FontSize="12">
                                        <ComboBoxItem Content="Default (DHCP Auto)"/>
                                        <ComboBoxItem Content="Cloudflare (1.1.1.1 / 1.0.0.1)"/>
                                        <ComboBoxItem Content="Google (8.8.8.8 / 8.8.4.4)"/>
                                        <ComboBoxItem Content="Quad9 (9.9.9.9 / Secure)"/>
                                    </ComboBox>
                                </Grid>
                            </StackPanel>
                        </ScrollViewer>
                    </Border>

                    <!-- Coluna Direita -->
                    <Border Grid.Column="1" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Margin="5,0,0,0" Padding="16,12">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel x:Name="PanelRight">
                                <TextBlock x:Name="HdrCustomize" Text="Customize Preferences (Real-Time)" FontFamily="Consolas" FontSize="15" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,6"/>

                                <CheckBox x:Name="TglBsod" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglDarkWin" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglLongPaths" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglFastStart" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglFileExt" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglHiddenFiles" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglGameMode" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglAcrylic" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglVerboseLogon" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglMouseAccel" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglMmProfile" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglNumLock" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglBingSearch" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglStartRecs" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglStickyKeys" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglCenterTaskbar" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglSearchIcon" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglTaskView" Style="{StaticResource BTToggleSwitch}"/>
                                <CheckBox x:Name="TglSnap" Style="{StaticResource BTToggleSwitch}"/>

                                <Grid Margin="0,12,0,6">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="220"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock x:Name="LblMpo" Grid.Column="0" Text="Multiplane Overlay (MPO):" Foreground="{DynamicResource PurpleHeader}" VerticalAlignment="Center" Margin="0,0,10,0" FontSize="12" FontWeight="SemiBold"/>
                                    <ComboBox x:Name="CmbMPO" Grid.Column="1" SelectedIndex="0" Height="26" FontSize="12">
                                        <ComboBoxItem Content="Enabled (Default)"/>
                                        <ComboBoxItem Content="Disabled (Compatibility)"/>
                                    </ComboBox>
                                </Grid>

                                <TextBlock x:Name="HdrPerfPlans" Text="Performance Plans - NOT FOR LAPTOPS" FontFamily="Consolas" FontSize="14" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,12,0,6"/>
                                <Button x:Name="BtnUltDisable" Content="Ultimate Performance Profile - Disable" Style="{StaticResource BTButton}" HorizontalAlignment="Stretch" Margin="0,2"/>
                                <Button x:Name="BtnUltEnable" Content="Ultimate Performance Profile - Enable" Style="{StaticResource BTButton}" HorizontalAlignment="Stretch" Margin="0,2"/>
                            </StackPanel>
                        </ScrollViewer>
                    </Border>
                </Grid>
            </Grid>

            <!-- ====================================================================== -->
            <!-- ABA 2: GAMING                                                          -->
            <!-- ====================================================================== -->
            <Grid Grid.Row="1" x:Name="ViewGaming" Visibility="Collapsed" Margin="14,10,14,6">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="360"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <Border Grid.Column="0" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Margin="0,0,8,0" Padding="16">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <StackPanel Grid.Row="0" Margin="0,0,0,10">
                            <TextBlock x:Name="HdrGameList" Text="Competitive Games" FontFamily="Consolas" FontSize="16" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                            <TextBlock x:Name="SubGameList" Text="Select a game to configure automatic optimizations." Foreground="{DynamicResource TextDim}" FontSize="11.5" TextWrapping="Wrap" Margin="0,2,0,0"/>
                        </StackPanel>

                        <ListBox x:Name="LstGames" Grid.Row="1" Background="{DynamicResource BgCard}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" 
                                 Padding="6" SelectionMode="Single" ItemContainerStyle="{StaticResource GameListBoxItemStyle}"
                                 ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                            <ListBox.ItemTemplate>
                                <DataTemplate>
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Grid.Column="0" Text="{Binding Name}" FontWeight="Bold" FontSize="13.5" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                                        <TextBlock Grid.Column="1" Text="{Binding Badge}" FontSize="10" FontWeight="SemiBold" Foreground="{DynamicResource PurpleHeader}" VerticalAlignment="Center"/>
                                    </Grid>
                                </DataTemplate>
                            </ListBox.ItemTemplate>
                        </ListBox>

                        <Border Grid.Row="2" Background="{DynamicResource BgCard}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,12,0,0">
                            <StackPanel>
                                <TextBlock x:Name="HdrAddCustomGame" Text="Add Custom Game" FontFamily="Consolas" FontSize="13.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,8"/>
                                
                                <TextBlock x:Name="LblGameName" Text="Game Name:" Foreground="{DynamicResource TextDim}" FontSize="11.5" Margin="0,0,0,2"/>
                                <TextBox x:Name="TxtCustomGameName" Background="{DynamicResource BgInput}" Foreground="{DynamicResource TextMain}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" Height="26" Padding="6,2" Margin="0,0,0,8"/>

                                <TextBlock x:Name="LblGameExe" Text="Executable (.exe):" Foreground="{DynamicResource TextDim}" FontSize="11.5" Margin="0,0,0,2"/>
                                <Grid Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox x:Name="TxtCustomGameExe" Grid.Column="0" Background="{DynamicResource BgInput}" Foreground="{DynamicResource TextMain}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" Height="26" Padding="6,2" IsReadOnly="True"/>
                                    <Button x:Name="BtnBrowseExe" Grid.Column="1" Content="Browse..." Style="{StaticResource BTButton}" Margin="6,0,0,0" Padding="12,2"/>
                                </Grid>

                                <UniformGrid Rows="1" Columns="2">
                                    <Button x:Name="BtnAddGame" Content="Add to List" Style="{StaticResource BTButton}" Background="#7C3AED" Foreground="#FFFFFF" BorderBrush="#A78BFA"/>
                                    <Button x:Name="BtnRemoveGame" Content="Remove Selected" Style="{StaticResource BTButton}" Margin="0,0,0,4"/>
                                </UniformGrid>
                            </StackPanel>
                        </Border>
                    </Grid>
                </Border>

                <Border Grid.Column="1" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Margin="8,0,0,0" Padding="20">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Background="{DynamicResource BgCard}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="16,12" Margin="0,0,0,14">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                        <TextBlock x:Name="LblSelectedGameTitle" Text="VALORANT" FontSize="20" FontWeight="Bold" Foreground="{DynamicResource TextMain}"/>
                                        <TextBlock x:Name="LblSelectedGameExe" Text="VALORANT-Win64-Shipping.exe" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" Margin="0,2,0,0"/>
                                    </StackPanel>
                                    <Border Grid.Column="1" Background="{DynamicResource BgInput}" BorderBrush="{DynamicResource BorderHighlight}" BorderThickness="1" CornerRadius="4" Padding="14,6" VerticalAlignment="Center">
                                        <StackPanel>
                                            <TextBlock x:Name="LblCpuTopology" Text="CPU: Detecting..." FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource PurpleHeader}" FontWeight="Bold"/>
                                            <TextBlock x:Name="LblCpuMaskInfo" Text="No-CPU0 Mask: Bitwise" FontFamily="Consolas" FontSize="11" Foreground="{DynamicResource TextDim}"/>
                                        </StackPanel>
                                    </Border>
                                </Grid>
                            </Border>

                            <Border x:Name="CardGameDscp" Background="{DynamicResource BgCard}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="15" Margin="0,0,0,12">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Margin="0,0,20,0">
                                        <TextBlock x:Name="HdrDscp" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                                        <TextBlock x:Name="DescDscp" Foreground="{DynamicResource TextDim}" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,6"/>
                                        <TextBlock x:Name="StatusDscp" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}"/>
                                    </StackPanel>
                                    <CheckBox x:Name="TglGameDscp" Grid.Column="1" Style="{StaticResource BTToggleSwitch}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <Border x:Name="CardGameAffinity" Background="{DynamicResource BgCard}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="15" Margin="0,0,0,12">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Margin="0,0,20,0">
                                        <TextBlock x:Name="HdrAffinity" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                                        <TextBlock x:Name="DescAffinity" Foreground="{DynamicResource TextDim}" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,6"/>
                                        <TextBlock x:Name="StatusAffinity" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}"/>
                                    </StackPanel>
                                    <CheckBox x:Name="TglGameAffinity" Grid.Column="1" Style="{StaticResource BTToggleSwitch}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <Border x:Name="CardGameDx11" Background="{DynamicResource BgCard}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="15" Margin="0,0,0,12">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Margin="0,0,20,0">
                                        <TextBlock x:Name="HdrDx11" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                                        <TextBlock x:Name="DescDx11" Foreground="{DynamicResource TextDim}" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,6"/>
                                        <TextBlock x:Name="StatusDx11" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}"/>
                                    </StackPanel>
                                    <CheckBox x:Name="TglGameDx11" Grid.Column="1" Style="{StaticResource BTToggleSwitch}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <Border x:Name="CardGameNvTel" Background="{DynamicResource BgCard}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="15" Margin="0,0,0,4">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Margin="0,0,20,0">
                                        <TextBlock x:Name="HdrNvTel" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                                        <TextBlock x:Name="DescNvTel" Foreground="{DynamicResource TextDim}" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,6"/>
                                        <TextBlock x:Name="StatusNvTel" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}"/>
                                    </StackPanel>
                                    <CheckBox x:Name="TglGameNvTel" Grid.Column="1" Style="{StaticResource BTToggleSwitch}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Border>
            </Grid>

            <!-- ====================================================================== -->
            <!-- ABA 3: LIMPEZA PROFUNDA (DISM++ DEEP CLEAN)                            -->
            <!-- ====================================================================== -->
            <Grid Grid.Row="1" x:Name="ViewDeepClean" Visibility="Collapsed" Margin="12,8,12,6">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <Border Grid.Row="0" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="14,10" Margin="0,0,0,8">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                            <TextBlock x:Name="HdrDeepCleanTitle" Text="Deep System Cleanup (DISM++ Engine)" FontFamily="Consolas" FontSize="15.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                            <TextBlock x:Name="SubDeepCleanDesc" Text="Select system caches, WinSxS superseded components, logs, and temporary files to purge safely." Foreground="{DynamicResource TextDim}" FontSize="11.5" Margin="0,2,0,0"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock x:Name="LblCleanTotalSize" Text="Estimated: Requires scan" FontFamily="Consolas" FontSize="12" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" VerticalAlignment="Center" Margin="0,0,14,0"/>
                            <Button x:Name="BtnCleanScan" Content="🔍 Scan Space" Style="{StaticResource BTButton}" BorderBrush="#8B5CF6" Margin="0,0,6,0"/>
                            <Button x:Name="BtnCleanDefault" Content="Default" Style="{StaticResource BTButton}" Margin="0,0,6,0"/>
                            <Button x:Name="BtnCleanAll" Content="Select All" Style="{StaticResource BTButton}" Margin="0,0,6,0"/>
                            <Button x:Name="BtnCleanNone" Content="None" Style="{StaticResource BTButton}" Margin="0,0,10,0"/>
                            <Button x:Name="BtnCleanExecute" Content="🧹 Clean Selected" Style="{StaticResource BTButton}" Background="#7C3AED" Foreground="#FFFFFF" BorderBrush="#A78BFA" FontWeight="Bold" Margin="0"/>
                        </StackPanel>
                    </Grid>
                </Border>

                <Grid Grid.Row="1">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Coluna Esquerda -->
                    <Border Grid.Column="0" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Margin="0,0,5,0" Padding="16,12">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel x:Name="PanelCleanLeft">
                                <CheckBox x:Name="CatExpired" IsChecked="True" Style="{StaticResource BTCheck}" FontFamily="Consolas" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,4"/>
                                <StackPanel Margin="20,0,0,10">
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnWinSxSSuperseded" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzWinSxSSuperseded" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnDismResidual" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzDismResidual" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnChromeOldBackup" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzChromeOldBackup" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                </StackPanel>

                                <CheckBox x:Name="CatSystem" IsChecked="True" Style="{StaticResource BTCheck}" FontFamily="Consolas" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,4,0,4"/>
                                <StackPanel Margin="20,0,0,10">
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnWerReports" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzWerReports" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnWinEvents" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzWinEvents" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnWinUpdateHistory" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzWinUpdateHistory" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnDamagedAppx" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzDamagedAppx" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnRestorePoints" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzRestorePoints" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                </StackPanel>

                                <CheckBox x:Name="CatApps" IsChecked="True" Style="{StaticResource BTCheck}" FontFamily="Consolas" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,4,0,4"/>
                                <StackPanel Margin="20,0,0,4">
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnPackageCache" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzPackageCache" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnDefenderHistory" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzDefenderHistory" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                </StackPanel>
                            </StackPanel>
                        </ScrollViewer>
                    </Border>

                    <!-- Coluna Direita -->
                    <Border Grid.Column="1" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Margin="5,0,0,0" Padding="16,12">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel x:Name="PanelCleanRight">
                                <CheckBox x:Name="CatCache" IsChecked="True" Style="{StaticResource BTCheck}" FontFamily="Consolas" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,4"/>
                                <StackPanel Margin="20,0,0,10">
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnWinDownloadCache" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzWinDownloadCache" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnDeliveryOptCache" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzDeliveryOptCache" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnRdpClientCache" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzRdpClientCache" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnNetAssemblyCache" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzNetAssemblyCache" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnPrefetchFiles" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzPrefetchFiles" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnThumbnailCache" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzThumbnailCache" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnWinInetWebCache" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzWinInetWebCache" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnWinInetCookies" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzWinInetCookies" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                </StackPanel>

                                <CheckBox x:Name="CatTemp" IsChecked="True" Style="{StaticResource BTCheck}" FontFamily="Consolas" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,4,0,4"/>
                                <StackPanel Margin="20,0,0,4">
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnWinSxSTemp" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzWinSxSTemp" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnWindowsLogs" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzWindowsLogs" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnTempFiles" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzTempFiles" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnRecycleBin" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzRecycleBin" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnCrashDumps" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzCrashDumps" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnMaJunkFiles" IsChecked="True" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzMaJunkFiles" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                        <CheckBox x:Name="ClnIdmTempFiles" IsChecked="False" Style="{StaticResource BTCheck}"/>
                                        <TextBlock x:Name="SzIdmTempFiles" Grid.Column="1" FontFamily="Consolas" FontSize="11.5" Foreground="{DynamicResource TextDim}" VerticalAlignment="Center"/>
                                    </Grid>
                                </StackPanel>
                            </StackPanel>
                        </ScrollViewer>
                    </Border>
                </Grid>
            </Grid>

            <!-- ====================================================================== -->
            <!-- ABA 4: ADVANCED                                                        -->
            <!-- ====================================================================== -->
            <Grid Grid.Row="1" x:Name="ViewAdvanced" Visibility="Collapsed" Margin="20">
                <StackPanel HorizontalAlignment="Center" VerticalAlignment="Top" Width="680" Margin="0,20,0,0">
                    <TextBlock x:Name="HdrAdvTabTitle" Text="Advanced" FontSize="26" FontWeight="Bold" Foreground="{DynamicResource TextMain}" HorizontalAlignment="Center" Margin="0,0,0,20"/>

                    <Border Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="5" Padding="24" Margin="0,0,0,16">
                        <StackPanel>
                            <TextBlock x:Name="HdrWinUpdateCard" Text="Windows Update" FontSize="17" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,8"/>
                            <TextBlock x:Name="DescWinUpdateCard" Foreground="{DynamicResource TextDim}" FontSize="12.5" TextWrapping="Wrap" Margin="0,0,0,12"/>
                            <TextBlock x:Name="StatusWinUpdateCard" Text="Status: Checking..." FontWeight="Bold" Foreground="{DynamicResource TextMain}" FontSize="12.5" Margin="0,0,0,14"/>
                            <WrapPanel Orientation="Horizontal">
                                <Button x:Name="BtnDisableWinUpdate" Style="{StaticResource BTButton}" Padding="18,7"/>
                                <Button x:Name="BtnRestoreWinUpdate" Style="{StaticResource BTButton}" Background="#7C3AED" Foreground="#FFFFFF" BorderBrush="#A78BFA" Padding="18,7"/>
                            </WrapPanel>
                        </StackPanel>
                    </Border>

                    <Border Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="5" Padding="24">
                        <StackPanel>
                            <TextBlock x:Name="HdrNetResetCard" FontSize="17" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,8"/>
                            <TextBlock x:Name="DescNetResetCard" Foreground="{DynamicResource TextDim}" FontSize="12.5" TextWrapping="Wrap" Margin="0,0,0,14"/>
                            <WrapPanel Orientation="Horizontal">
                                <Button x:Name="BtnAdvCleanmgr" Style="{StaticResource BTButton}" Background="#7C3AED" Foreground="#FFFFFF" BorderBrush="#A78BFA" Padding="16,7"/>
                                <Button x:Name="BtnAdvCleanCache" Style="{StaticResource BTButton}" Padding="16,7"/>
                                <Button x:Name="BtnAdvFlushNet" Style="{StaticResource BTButton}" Padding="16,7"/>
                            </WrapPanel>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </Grid>

            <!-- 4. RODAPÉ -->
            <Border Grid.Row="2" Background="{DynamicResource BgHeader}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="0,1,0,0" Padding="16,0">
                <Grid VerticalAlignment="Center">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <TextBlock Grid.Column="0" x:Name="LblFooterNote" Foreground="{DynamicResource PurpleHeader}" FontSize="12" VerticalAlignment="Center" TextWrapping="Wrap" Margin="0,0,16,0"/>

                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="BtnRunTweaks" Style="{StaticResource BTButton}" Background="#7C3AED" Foreground="#FFFFFF" BorderBrush="#A78BFA" Padding="20,8" FontWeight="Bold" Margin="0,0,8,0"/>
                        <Button x:Name="BtnUndoTweaks" Style="{StaticResource BTButton}" Padding="18,8" Margin="0"/>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

if (Test-Path $script:IconPath) {
    try {
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object System.Uri($script:IconPath, [System.UriKind]::Absolute)))
    } catch {
        Write-BTLog "Aviso ao carregar ícone da janela: $($_.Exception.Message)" "WARN"
    }
}

$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
    $el = $window.FindName($_.Name)
    if ($null -ne $el) {
        Set-Variable -Name $_.Name -Value $el -Scope Script
    } else {
        Write-Warning "[BetterTitus] Elemento XAML não encontrado: $($_.Name)"
    }
}

# ==============================================================================
# HELPERS DE EXECUÇÃO, SERVIÇOS, BACKUPS E HARDWARE
# ==============================================================================
function Invoke-SafeTweak ([string]$Title, [scriptblock]$Action, [scriptblock]$Verify = $null) {
    try {
        & $Action
        if ($null -ne $Verify) {
            if (& $Verify) { Write-BTLog "$Title -> Aplicado com sucesso" "OK" }
            else { Write-BTLog "$Title -> Aplicado parcialmente" "PARTIAL" }
        } else {
            Write-BTLog "$Title -> OK" "OK"
        }
    } catch {
        Write-BTLog "$Title -> Falha: $($_.Exception.Message)" "ERROR"
    }
}

function Get-ServiceStartModeFast ([string]$ServiceName) {
    return (Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName" "Start" -1)
}

function Set-ServiceStartModeSafe ([string]$ServiceName, [int]$StartValue) {
    if ($StartValue -notin @(2, 3, 4)) {
        Write-BTLog "Valor Start inválido ($StartValue) ignorado para o serviço $ServiceName." "WARN"
        return $false
    }
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
    if (-not (Test-Path $regPath)) { return $false }

    Set-Reg $regPath "Start" $StartValue "DWord"
    if ($StartValue -eq 4) {
        try {
            $svc = Get-Service -Name $ServiceName -ErrorAction Stop
            if ($svc.Status -ne 'Stopped') {
                Stop-Service -Name $ServiceName -ErrorAction Stop
                $svc.Refresh()
                if ($svc.Status -ne 'Stopped') {
                    Write-BTLog "Serviço $ServiceName marcado como Disabled, mas permanece $($svc.Status)." "WARN"
                }
            }
        } catch {
            Write-BTLog "Não foi possível parar imediatamente o serviço $ServiceName ($($_.Exception.Message)). Terá efeito após reiniciar." "WARN"
        }
    }
    return $true
}

function Backup-CoreServicesState ([string[]]$ServiceNames) {
    $existing = @{}
    if (Test-Path $script:CoreSvcBackup) {
        try {
            $loaded = Get-Content $script:CoreSvcBackup -Raw | ConvertFrom-Json
            foreach ($p in $loaded.PSObject.Properties) { $existing[$p.Name] = $p.Value }
        } catch {}
    }
    $changed = $false
    foreach ($svcName in $ServiceNames) {
        if (-not $existing.ContainsKey($svcName)) {
            $st = Get-ServiceStartModeFast $svcName
            if ($st -in @(2, 3, 4)) {
                $svcObj = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                $existing[$svcName] = [PSCustomObject]@{
                    Start      = $st
                    WasRunning = ($null -ne $svcObj -and $svcObj.Status -eq 'Running')
                }
                $changed = $true
            }
        }
    }
    if ($changed -and $existing.Count -gt 0) {
        $existing | ConvertTo-Json -Depth 3 | Set-Content -Path $script:CoreSvcBackup -Encoding UTF8 -Force
    }
}

function Restore-CoreServicesState ([string[]]$ServiceNames) {
    $saved = @{}
    if (Test-Path $script:CoreSvcBackup) {
        try {
            $loaded = Get-Content $script:CoreSvcBackup -Raw | ConvertFrom-Json
            foreach ($p in $loaded.PSObject.Properties) { $saved[$p.Name] = $p.Value }
        } catch {}
    }
    $modified = $false
    foreach ($svcName in $ServiceNames) {
        if ($saved.ContainsKey($svcName)) {
            $entry = $saved[$svcName]
            $st = [int]$entry.Start
            if ($st -notin @(2, 3, 4)) { $st = 3 }
            [void](Set-ServiceStartModeSafe $svcName $st)
            $wasRun = ($entry.WasRunning -is [bool] -and $entry.WasRunning) -or ($entry.WasRunning.ToString() -ieq "true")
            if ($wasRun) { Start-Service -Name $svcName -ErrorAction SilentlyContinue }
            $saved.Remove($svcName)
            $modified = $true
        } else {
            if ((Get-ServiceStartModeFast $svcName) -ne -1) {
                [void](Set-ServiceStartModeSafe $svcName 3)
            }
        }
    }
    if ($modified) {
        if ($saved.Count -gt 0) { $saved | ConvertTo-Json -Depth 3 | Set-Content -Path $script:CoreSvcBackup -Encoding UTF8 -Force }
        else { Remove-Item $script:CoreSvcBackup -Force -ErrorAction SilentlyContinue }
    }
}

function Test-ScheduledTaskSafe ([string]$TaskPath, [string]$TaskName) {
    return ($null -ne (Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue))
}

function Get-CleanId ([string]$exeName) { return ($exeName -replace '[^a-zA-Z0-9]', '_') }

function Initialize-HardwareCache {
    $cores = [Environment]::ProcessorCount
    $threads = [Environment]::ProcessorCount
    try {
        $procs = Get-CimInstance Win32_Processor -OperationTimeoutSec 4 -ErrorAction Stop
        $cSum = ($procs | Measure-Object -Property NumberOfCores -Sum).Sum
        $tSum = ($procs | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        if ($cSum -ge 1) { $cores = $cSum }
        if ($tSum -ge 1) { $threads = $tSum }
    } catch {
        Write-BTLog "Timeout/erro WMI ao ler CPU; usando fallback ($threads threads)." "WARN"
    }

    $ramKB = [int64]0
    try {
        $ramBytes = (Get-CimInstance Win32_PhysicalMemory -OperationTimeoutSec 4 -ErrorAction Stop | Measure-Object -Property Capacity -Sum).Sum
        if ($ramBytes -gt 0) { $ramKB = [int64]($ramBytes / 1KB) }
    } catch {
        Write-BTLog "Timeout/erro WMI ao ler memória física: $($_.Exception.Message)" "WARN"
    }

    $hasNv = $false
    try {
        $gpuNames = ((Get-CimInstance Win32_VideoController -OperationTimeoutSec 4 -ErrorAction Stop).Name -join " ")
        $hasNv = ($gpuNames -match 'NVIDIA') -or ((Get-ServiceStartModeFast "NVDisplay.ContainerLocalSystem") -ne -1) -or ((Get-ServiceStartModeFast "NvContainerLocalSystem") -ne -1)
    } catch {
        $hasNv = ((Get-ServiceStartModeFast "NVDisplay.ContainerLocalSystem") -ne -1) -or ((Get-ServiceStartModeFast "NvContainerLocalSystem") -ne -1)
    }

    $osSku = 0
    try {
        $osCim = Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 4 -ErrorAction Stop
        if ($osCim) { $osSku = [int]$osCim.OperatingSystemSKU }
    } catch {}

    return [PSCustomObject]@{
        Cores      = $cores
        Threads    = $threads
        RamKB      = $ramKB
        HasNvidia  = $hasNv
        OsSku      = $osSku
    }
}

function Refresh-NvidiaPresence {
    $prev = $script:HwInfo.HasNvidia
    $hasNv = ((Get-ServiceStartModeFast "NVDisplay.ContainerLocalSystem") -ne -1) -or ((Get-ServiceStartModeFast "NvContainerLocalSystem") -ne -1)
    if (-not $hasNv) {
        try {
            $gpuNames = ((Get-CimInstance Win32_VideoController -OperationTimeoutSec 3 -ErrorAction Stop).Name -join " ")
            $hasNv = ($gpuNames -match 'NVIDIA')
        } catch {}
    }
    $script:HwInfo.HasNvidia = $hasNv
    if ($prev -ne $hasNv) {
        Write-BTLog "Cache de hardware NVIDIA atualizado: HasNvidia = $hasNv" "INFO"
    }
}

$script:HwInfo = Initialize-HardwareCache
$ramDisp = if ($script:HwInfo.RamKB -gt 0) { "$([math]::Round($script:HwInfo.RamKB / 1048576, 1)) GB" } else { "Não detectada" }
Write-BTLog "Hardware: $($script:HwInfo.Cores) Cores / $($script:HwInfo.Threads) Threads | RAM: $ramDisp | NVIDIA: $($script:HwInfo.HasNvidia) | OS SKU: $($script:HwInfo.OsSku)" "INFO"

$script:GameStateCache = @{ Dscp = $false; Affinity = $false; Dx11State = "NONE"; NvTel = $false; Exe = ""; IsValorant = $false }
$script:WinUpdateDisabledCache = $false

$script:SafeManualServices = @(
    "MapsBroker", "Fax", "WerSvc", "RetailDemo", "RemoteRegistry",
    "WpcMonSvc", "PhoneSvc", "wisvc", "icssvc", "WalletService"
)

$script:OptionalScheduledTasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
)

$script:AllowedNvServices = @("NVDisplay.ContainerLocalSystem", "NvContainerLocalSystem")

function Restore-NvidiaBackupForGame ([string]$GameId) {
    $bkpFile = "$script:ConfigDir\nv_backup_$GameId.json"
    if (Test-Path $bkpFile) {
        try {
            $bkp = Get-Content $bkpFile -Raw | ConvertFrom-Json
            foreach ($entry in $bkp) {
                $svcName = $entry.Name.ToString()
                if ($svcName -notin $script:AllowedNvServices) {
                    Write-BTLog "Nome de serviço não permitido ignorado no backup NVIDIA: $svcName" "WARN"
                    continue
                }
                $startVal = [int]$entry.Start
                if ($startVal -notin @(2, 3, 4)) { $startVal = 2 }
                $reg = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
                if (Test-Path $reg) {
                    Set-ItemProperty -Path $reg -Name "Start" -Value $startVal -Type DWord -Force -ErrorAction SilentlyContinue
                    $wasRun = ($entry.WasRunning -is [bool] -and $entry.WasRunning) -or ($entry.WasRunning.ToString() -ieq "true")
                    if ($wasRun) { Start-Service -Name $svcName -ErrorAction SilentlyContinue }
                }
            }
            Remove-Item $bkpFile -Force -ErrorAction SilentlyContinue
            Write-BTLog "Estado original dos serviços NVIDIA restaurado para [$GameId]." "OK"
        } catch {
            Write-BTLog "Erro ao restaurar backup NVIDIA [$GameId]: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ==============================================================================
# PERSISTÊNCIA DE CONFIGURAÇÕES (IDIOMA E TEMA)
# ==============================================================================
function Load-UserAppSettings {
    $uiCultureName = [System.Globalization.CultureInfo]::InstalledUICulture.Name
    $defLang = if ($uiCultureName -like "pt*") { "PT" } else { "EN" }
    $cfg = [PSCustomObject]@{ Lang = $defLang; IsDark = $true }
    if (Test-Path $script:SettingsJson) {
        try {
            $loaded = Get-Content $script:SettingsJson -Raw | ConvertFrom-Json
            if ($loaded.Lang -in @("PT", "EN")) { $cfg.Lang = $loaded.Lang }
            if ($null -ne $loaded.IsDark) { $cfg.IsDark = [bool]$loaded.IsDark }
        } catch {}
    }
    return $cfg
}

function Save-UserAppSettings {
    try {
        [PSCustomObject]@{
            Lang   = $script:Lang
            IsDark = $script:isDark
        } | ConvertTo-Json -Depth 2 | Set-Content -Path $script:SettingsJson -Encoding UTF8 -Force
    } catch {}
}

$appSettings = Load-UserAppSettings
$script:Lang = $appSettings.Lang
$script:isDark = $appSettings.IsDark

# ==============================================================================
# DICIONÁRIO CENTRALIZADO DE TEXTOS E TOOLTIPS BILÍNGUES (PT-BR & EN)
# ==============================================================================
$script:ControlMeta = @{
    "ChkActivity"        = @{ PT="Histórico de Atividades - Desativar (?)"; EN="Activity History - Disable (?)";
                              TipPT="O que faz: Desativa a coleta da Linha do Tempo e histórico de arquivos abertos.`nBenefício: Maior privacidade e menos gravações em disco em segundo plano.";
                              TipEN="What it does: Disables Windows Activity Feed and timeline tracking.`nBenefit: Improved privacy and reduced background disk writes." }
    "ChkConsumer"        = @{ PT="Recursos do Consumidor (Apps Sugeridos) - Desativar (?)"; EN="ConsumerFeatures (Silent Bloatware) - Disable (?)";
                              TipPT="O que faz: Impede o Windows de baixar aplicativos patrocinados automaticamente.`nNota: Em edições Home/Pro já instaladas, afeta principalmente novas contas de usuário.";
                              TipEN="What it does: Stops Windows from silently installing sponsored Store apps.`nNote: On existing Home/Pro installs, applies primarily to new user profiles." }
    "ChkDelivery"        = @{ PT="Otimização de Entrega (Updates P2P) - Desativar (?)"; EN="Delivery Optimization (P2P Updates) - Disable (?)";
                              TipPT="O que faz: Desativa o envio peer-to-peer (P2P) de atualizações do Windows para outros PCs.`nBenefício: Evita picos de ping e uso oculto do seu upload durante jogos.";
                              TipEN="What it does: Disables P2P uploading of Windows Updates to other PCs.`nBenefit: Prevents random ping spikes and hidden upload usage." }
    "ChkEndTask"         = @{ PT="Finalizar Tarefa na Barra de Tarefas - Ativar (?)"; EN="End Task With Right Click on Taskbar - Enable (?)";
                              TipPT="O que faz: Adiciona 'Finalizar tarefa' ao clicar com botão direito na Barra de Tarefas (Win 11).`nBenefício: Fecha jogos ou apps travados rapidamente.";
                              TipEN="What it does: Adds 'End task' directly to the Taskbar right-click menu (Win 11).`nBenefit: Quickly force-close frozen apps or games." }
    "ChkFolderDisc"      = @{ PT="Descoberta Automática de Pastas do Explorer - Desativar (?)"; EN="File Explorer Automatic Folder Discovery - Disable (?)";
                              TipPT="O que faz: Impede o Explorer de tentar adivinhar o tipo de mídia de cada pasta.`nBenefício: Pastas com milhares de arquivos abrem instantaneamente.";
                              TipEN="What it does: Stops Explorer from scanning folders to guess media type.`nBenefit: Much faster folder loading in File Explorer." }
    "ChkHibernation"     = @{ PT="Hibernação do Sistema - Desativar (?)"; EN="Hibernation - Disable (?)";
                              TipPT="O que faz: Desativa a hibernação e remove o arquivo oculto hiberfil.sys.`nNota: Desativar a hibernação também desativa automaticamente a Inicialização Rápida (Fast Startup).";
                              TipEN="What it does: Disables hibernation and deletes hiberfil.sys.`nNote: Disabling hibernation automatically disables Fast Startup." }
    "ChkLocation"        = @{ PT="Rastreamento de Localização - Desativar (?)"; EN="Location Tracking - Disable (?)";
                              TipPT="O que faz: Bloqueia o acesso global de geolocalização do sistema.`nBenefício: Mais privacidade e menos serviços em segundo plano.";
                              TipEN="What it does: Denies global system geolocation access.`nBenefit: Better privacy and fewer background polls." }
    "ChkMemCompression"  = @{ PT="Compactação de Memória (Memory Compression) - Desativar (?)"; EN="Memory Compression - Disable (?)";
                              TipPT="O que faz: Desativa a compressão de páginas na RAM executada pelo processo System.`nBenefício: Reduz overhead de CPU e micro-stutters em PCs com 16GB+ RAM.";
                              TipEN="What it does: Disables Windows RAM page compression handled by System.`nBenefit: Reduces CPU overhead and micro-stutters on 16GB+ RAM systems." }
    "ChkStoreSearch"     = @{ PT="Resultados da Microsoft Store na Busca - Desativar (?)"; EN="Microsoft Store Search Results - Disable (?)";
                              TipPT="O que faz: Remove a sugestão 'Procurar um aplicativo na Microsoft Store'.";
                              TipEN="What it does: Removes 'Look for an app in the Microsoft Store' prompts." }
    "ChkDeviceCompanion" = @{ PT="Impedir Apps Complementares de Dispositivos - Ativar (?)"; EN="Prevent Device Companion Apps - Enable (?)";
                              TipPT="O que faz: Bloqueia o download automático de softwares de fabricantes via Windows Update.";
                              TipEN="What it does: Prevents Windows from auto-installing vendor companion apps when plugging peripherals." }
    "ChkServicesMan"     = @{ PT="Serviços em Segundo Plano - Definir como Manual (?)"; EN="Background Services - Set to Manual (?)";
                              TipPT="O que faz: Altera 10 serviços secundários seguros para Manual (com backup para reversão exata).";
                              TipEN="What it does: Sets 10 safe non-essential services to Manual (with backup for exact revert)." }
    "ChkTelemetry"       = @{ PT="Telemetria e Coleta de Dados - Desativar (?)"; EN="Telemetry & Data Collection - Disable (?)";
                              TipPT="O que faz: Define AllowTelemetry=0 e desativa DiagTrack (com backup do estado original).`nNota: O Windows Home/Pro limita o nível mínimo a 1 (Básico).";
                              TipEN="What it does: Sets AllowTelemetry=0 and disables DiagTrack (backing up original state).`nNote: Windows Home/Pro enforces minimum level 1 (Basic)." }
    "ChkWidgets"         = @{ PT="Widgets da Barra de Tarefas - Remover (?)"; EN="Widgets (News & Interests) - Remove (?)";
                              TipPT="O que faz: Desativa o painel de Widgets/Notícias via registro e política Dsh (preserva demais políticas).";
                              TipEN="What it does: Disables Taskbar Widgets/News via registry and Dsh policy (preserves other policies)." }
    "ChkWPBT"            = @{ PT="Tabela Binária da Plataforma (WPBT) - Desativar (?)"; EN="Windows Platform Binary Table (WPBT) - Disable (?)";
                              TipPT="O que faz: Impede que o BIOS/UEFI injete executáveis de fabricantes no Windows.";
                              TipEN="What it does: Blocks motherboard firmware from injecting vendor software during boot." }
    "ChkSearchIdx"       = @{ PT="Indexação do Windows Search - Desativar (?)"; EN="Windows Search Indexing - Disable (?)";
                              TipPT="O que faz: Desativa o serviço WSearch de indexação contínua de arquivos (salva estado anterior para reversão).";
                              TipEN="What it does: Disables the WSearch continuous file indexing service (saves original state for revert)." }

    "ChkBgApps"          = @{ PT="Aplicativos da Loja em Segundo Plano - Desativar (?)"; EN="Background Store Apps - Disable (?)";
                              TipPT="O que faz: Impede apps UWP da Microsoft Store de rodarem ocultos em segundo plano.";
                              TipEN="What it does: Prevents Microsoft Store UWP apps from running in the background." }
    "ChkOptTasks"        = @{ PT="Tarefas Agendadas de Telemetria - Desativar (?)"; EN="Optional Telemetry Scheduled Tasks - Disable (?)";
                              TipPT="O que faz: Desativa tarefas agendadas de coleta (salva individualmente quais estavam ativas antes).";
                              TipEN="What it does: Disables scheduled telemetry tasks (saves each task's individual state before disabling)." }
    "ChkReservedStorage" = @{ PT="Armazenamento Reservado do Windows - Desativar (?)"; EN="Windows Reserved Storage - Disable (?)";
                              TipPT="O que faz: Desativa a reserva automática de ~7 GB usada pelo Windows Update.";
                              TipEN="What it does: Disables the ~7 GB storage partition reserved for Windows Updates." }
    "ChkExplorerGallery" = @{ PT="Galeria e Início no Explorer (Win 11) - Ocultar (?)"; EN="File Explorer Home & Gallery (Win 11) - Hide (?)";
                              TipPT="O que faz: Remove os atalhos 'Galeria' e 'Início' do painel esquerdo do Explorer.";
                              TipEN="What it does: Hides Gallery and Home clutter from the Win 11 Explorer sidebar." }
    "ChkGameDVR"         = @{ PT="GameDVR e Captura Xbox - Desativar (?)"; EN="GameDVR & Xbox Background Capture - Disable (?)";
                              TipPT="O que faz: Desativa gravação em segundo plano, AppCapture e política AllowGameDVR.";
                              TipEN="What it does: Disables background recording, AppCapture, and AllowGameDVR policy." }
    "ChkIPv4Pref"        = @{ PT="Rede IPv6 - Definir IPv4 como Preferencial (?)"; EN="IPv6 - Set IPv4 as Preferred (?)";
                              TipPT="O que faz: Define DisabledComponents=32 (salva o valor original antes) para priorizar IPv4 sem quebrar VPNs.";
                              TipEN="What it does: Sets DisabledComponents=32 (backs up previous value) to prefer IPv4 without breaking VPNs." }
    "ChkTeredo"          = @{ PT="Túnel Teredo IPv6 - Desativar (?)"; EN="Teredo Tunneling - Disable (?)";
                              TipPT="O que faz: Desativa a interface de tunelamento legado Teredo via netsh (validando código de saída) e política.";
                              TipEN="What it does: Disables legacy Teredo IPv6 tunneling via netsh (checking exit code) and policy." }
    "ChkMenuDelay"       = @{ PT="Atraso de Menus (Zero Delay 0ms) - Ativar (?)"; EN="MenuShowDelay (Zero Delay 0ms) - Enable (?)";
                              TipPT="O que faz: Muda MenuShowDelay de 400ms para 0ms.";
                              TipEN="What it does: Changes MenuShowDelay from 400ms to 0ms." }
    "ChkEdgeDebloat"     = @{ PT="Processos em Segundo Plano do Edge - Desativar (?)"; EN="Microsoft Edge Background Processes - Disable (?)";
                              TipPT="O que faz: Desativa Startup Boost e execução em segundo plano do Edge (reversão remove apenas os 2 valores criados).";
                              TipEN="What it does: Disables Edge Startup Boost and Background Mode (revert removes only the 2 created values)." }
    "ChkNetThrottle"     = @{ PT="Limitação de Rede (Network Throttling) - Otimizar (?)"; EN="Network Throttling Index - Optimize (?)";
                              TipPT="O que faz: Define NetworkThrottlingIndex=0xFFFFFFFF e SystemResponsiveness=0.";
                              TipEN="What it does: Sets NetworkThrottlingIndex=0xFFFFFFFF and SystemResponsiveness=0." }
    "ChkPowerThrottle"   = @{ PT="Estrangulamento de Energia (Power Throttling) - Desativar (?)"; EN="Power Throttling - Disable (?)";
                              TipPT="O que faz: Define PowerThrottlingOff=1 no controle de energia da CPU (não recomendado para notebooks na bateria).";
                              TipEN="What it does: Sets PowerThrottlingOff=1 (not recommended on laptop battery)." }
    "ChkClassicContext"  = @{ PT="Menu de Contexto Clássico (Win 11) - Ativar (?)"; EN="Right-Click Menu Classic Layout (Win 11) - Enable (?)";
                              TipPT="O que faz: Restaura o menu de botão direito completo no Windows 11.";
                              TipEN="What it does: Restores the full classic right-click context menu on Win 11." }
    "ChkStorageSense"    = @{ PT="Sensor de Armazenamento Automático - Desativar (?)"; EN="Storage Sense Automatic Cleanup - Disable (?)";
                              TipPT="O que faz: Desativa a varredura periódica automática de disco do Windows.";
                              TipEN="What it does: Disables automatic periodic Storage Sense scans." }
    "ChkSvcHost"         = @{ PT="Divisão de Processos SvcHost - Ajustar para sua RAM (?)"; EN="SvcHost Split Threshold - Match Physical RAM (?)";
                              TipPT="O que faz: Ajusta SvcHostSplitThresholdInKB exatamente para sua RAM física (padrão Windows: 3670016 KB / 3.5 GB).";
                              TipEN="What it does: Matches SvcHostSplitThresholdInKB to your physical RAM (Windows default: 3670016 KB / 3.5 GB)." }
    "ChkUsbSuspend"      = @{ PT="Suspensão Seletiva USB - Desativar (?)"; EN="USB Selective Suspend - Disable (?)";
                              TipPT="O que faz: Impede o Windows de desligar portas USB ociosas.";
                              TipEN="What it does: Prevents Windows from powering down idle USB ports." }
    "ChkBestPerf"        = @{ PT="Efeitos Visuais - Ajustar para Melhor Desempenho (?)"; EN="Visual Effects - Set to Best Performance (?)";
                              TipPT="O que faz: Desativa animações pesadas de janelas e transparências desnecessárias.";
                              TipEN="What it does: Disables heavy window animations and shadows." }
    "ChkWinAI"           = @{ PT="Windows AI (Copilot e Recall) - Desativar (?)"; EN="Windows AI (Copilot & Recall) - Disable (?)";
                              TipPT="O que faz: Desativa políticas do Windows Copilot e Windows Recall (preservando demais políticas do sistema).";
                              TipEN="What it does: Disables Windows Copilot and Recall policies (preserving other system policies)." }

    "ChkBitLocker"       = @{ PT="BitLocker (Criptografia de Disco) - Desativar [CONFIRMAÇÃO DUPLA] (?)"; EN="BitLocker (Drive Encryption) - Disable [DOUBLE CONFIRM] (?)";
                              TipPT="Inicia a descriptografia da unidade do sistema (C:) em segundo plano se o BitLocker estiver ativo.";
                              TipEN="Starts background decryption of the system drive (C:) if BitLocker is enabled." }
    "ChkHVCI"            = @{ PT="HVCI (Integridade de Memória / Core Isolation) - Desativar [REINICIAR] (?)"; EN="HVCI (Memory Integrity / Core Isolation) - Disable [RESTART] (?)";
                              TipPT="Desativa HVCI para ganhar FPS. Desmarque e clique em Aplicar ou Reverter para reativar.";
                              TipEN="Disables HVCI for higher FPS. Uncheck and click Apply or Revert to re-enable." }
    "ChkCpuMitigations"  = @{ PT="Mitigações de CPU (Spectre/Meltdown) - Desativar [REINICIAR] (?)"; EN="CPU Mitigations (Spectre/Meltdown) - Disable [RESTART] (?)";
                              TipPT="Desativa mitigações Spectre/Meltdown para menor latência de syscalls.";
                              TipEN="Disables Spectre/Meltdown mitigations for lower syscall overhead." }

    "TglBsod"            = @{ PT="Tela Azul Detalhada (BSoD Verbose + Sem Auto-Reboot)"; EN="BSoD Verbose Mode (+ Disable Auto-Reboot)"; TipPT="Exibe códigos técnicos na Tela Azul e impede reinício imediato (salva AutoReboot original)."; TipEN="Shows technical parameters on Blue Screen errors and disables auto-reboot (backs up original AutoReboot)." }
    "TglDarkWin"         = @{ PT="Tema Escuro para o Windows"; EN="Dark Theme for Windows"; TipPT="Alterna o tema escuro nativo do Windows e notifica o shell em tempo real."; TipEN="Toggles Windows native Dark Mode and notifies the shell in real time." }
    "TglLongPaths"       = @{ PT="Habilitar Caminhos Longos (>260 caracteres)"; EN="Enable Long Paths (>260 chars)"; TipPT="Remove o limite legado de 260 caracteres em nomes de pastas/arquivos."; TipEN="Removes legacy 260-character file path limit." }
    "TglFastStart"       = @{ PT="Inicialização Rápida (Fast Startup)"; EN="Fast Startup (Hiberboot)"; TipPT="Indisponível se a Hibernação estiver desativada (requer hiberfil.sys)."; TipEN="Unavailable when Hibernation is disabled (requires hiberfil.sys)." }
    "TglFileExt"         = @{ PT="Mostrar Extensões de Arquivos no Explorer"; EN="File Explorer File Extensions"; TipPT="Exibe .exe, .zip, .ps1 no Windows Explorer imediatamente."; TipEN="Shows file extensions like .exe and .zip in Explorer immediately." }
    "TglHiddenFiles"     = @{ PT="Mostrar Arquivos Ocultos no Explorer"; EN="File Explorer Hidden Files"; TipPT="Exibe pastas ocultas como AppData e ProgramData imediatamente."; TipEN="Reveals hidden system folders like AppData and ProgramData immediately." }
    "TglGameMode"        = @{ PT="Modo de Jogo (Game Mode)"; EN="Game Mode"; TipPT="Prioriza recursos de CPU/GPU para jogos."; TipEN="Prioritizes CPU/GPU for games." }
    "TglAcrylic"         = @{ PT="Desfoque Acrílico na Tela de Login"; EN="Logon Screen Acrylic Blur"; TipPT="Ativa ou remove o efeito de desfoque na tela de bloqueio."; TipEN="Toggles the acrylic blur effect on the Windows sign-in screen." }
    "TglVerboseLogon"    = @{ PT="Mensagens Detalhadas de Inicialização/Logon"; EN="Logon Verbose Mode"; TipPT="Exibe qual serviço está iniciando/encerrando durante o boot."; TipEN="Displays detailed status messages during startup and shutdown." }
    "TglMouseAccel"      = @{ PT="Aceleração do Ponteiro do Mouse"; EN="Mouse Acceleration"; TipPT="Desative para precisão linear 1:1 em jogos competitivos (aplica na hora via SystemParametersInfo)."; TipEN="Turn OFF for true 1:1 raw linear mouse movement in FPS games (applies live via SystemParametersInfo)." }
    "TglMmProfile"       = @{ PT="Perfil Multimídia de Jogos (MMCSS)"; EN="Multimedia Gaming Profile (MMCSS)"; TipPT="Define GPU Priority=8, Priority=6 e Scheduling Category=High (com backup para restauração exata)."; TipEN="Sets GPU Priority=8, Priority=6, and High scheduling category (with backup for exact restore)." }
    "TglNumLock"         = @{ PT="Ativar Num Lock ao Ligar"; EN="Num Lock on Startup"; TipPT="Mantém o teclado numérico ativado automaticamente no boot."; TipEN="Automatically enables Num Lock when Windows starts." }
    "TglBingSearch"      = @{ PT="Pesquisa Web do Bing no Menu Iniciar"; EN="Start Menu Bing Search"; TipPT="Desative para deixar a busca do Menu Iniciar 100% local."; TipEN="Turn OFF to make Start Menu search 100% local and instant." }
    "TglStartRecs"       = @{ PT="Recomendações no Menu Iniciar"; EN="Start Menu Recommendations"; TipPT="Desative para remover arquivos recentes e sugestões do Menu Iniciar."; TipEN="Turn OFF to hide recommended files and tips in Start Menu." }
    "TglStickyKeys"      = @{ PT="Atalho das Teclas de Aderência (5x Shift)"; EN="Sticky Keys Shortcut (5x Shift)"; TipPT="Desative para nunca mais abrir o alerta ao apertar Shift 5x jogando."; TipEN="Turn OFF to prevent the popup when pressing Shift 5 times in-game." }
    "TglCenterTaskbar"   = @{ PT="Ícones Centralizados na Barra de Tarefas"; EN="Taskbar Centered Icons"; TipPT="Alterna os ícones da Barra de Tarefas do Win 11 entre Centro e Esquerda."; TipEN="Switches Win 11 taskbar alignment between Center and Left." }
    "TglSearchIcon"      = @{ PT="Ícone de Pesquisa na Barra de Tarefas"; EN="Taskbar Search Icon"; TipPT="Mostra ou oculta a lupa/caixa de pesquisa na Barra de Tarefas."; TipEN="Shows or hides the search box/icon on the taskbar." }
    "TglTaskView"        = @{ PT="Botão Visão de Tarefas na Barra"; EN="Taskbar Task View Icon"; TipPT="Mostra ou oculta o botão de múltiplas áreas de trabalho."; TipEN="Shows or hides the Task View button on the taskbar." }
    "TglSnap"            = @{ PT="Ajuste Automático de Janelas (Window Snap)"; EN="Window Snapping"; TipPT="Permite encaixar janelas nas bordas da tela ao arrastá-las."; TipEN="Toggles automatic window snapping to screen edges." }

    # Aba Limpeza Profunda
    "CatExpired"           = @{ PT="Arquivos Expirados"; EN="Expired Files"; TipPT="Componentes substituídos do Windows, resíduos do DISM e backups antigos do Chrome."; TipEN="Superseded Windows components, DISM leftovers, and old Chrome backups." }
    "ClnWinSxSSuperseded"  = @{ PT="Assemblies Substituído no WinSxS (?)"; EN="Superseded Assemblies in WinSxS (?)"; TipPT="Executa DISM /StartComponentCleanup para remover componentes antigos substituídos."; TipEN="Runs DISM /StartComponentCleanup to remove old superseded components." }
    "ClnDismResidual"      = @{ PT="Arquivos residuais de versões anteriores do Dism (?)"; EN="Residual files from previous Dism versions (?)"; TipPT="Remove logs antigos (.bak) e pastas temporárias do DISM."; TipEN="Removes old .bak logs and temporary folders from DISM." }
    "ClnChromeOldBackup"   = @{ PT="Arquivos de backup de versão antiga do Chrome (?)"; EN="Old Chrome version backup files (?)"; TipPT="Remove apenas pastas de versões antigas (old_*) e caches temporários do Chrome, preservando o instalador da versão atual."; TipEN="Removes only old version folders (old_*) and Chrome temp caches, preserving the current version's installer." }

    "CatSystem"            = @{ PT="Sistema"; EN="System"; TipPT="Relatórios de erros, logs de eventos, histórico do Windows Update, pacotes Appx e pontos de restauração."; TipEN="Error reports, event logs, Windows Update history, damaged Appx, and restore points." }
    "ClnWerReports"        = @{ PT="Relatório de Erros do Windows (?)"; EN="Windows Error Reporting (?)"; TipPT="Limpa relatórios de falhas e arquivos de diagnóstico do WER."; TipEN="Clears crash reports and diagnostic archives from WER." }
    "ClnWinEvents"         = @{ PT="Eventos do Windows (?)"; EN="Windows Event Logs (?)"; TipPT="Limpa os logs do Visualizador de Eventos do Windows."; TipEN="Clears Windows Event Viewer logs." }
    "ClnWinUpdateHistory"  = @{ PT="Histórico de instalação do Windows Update (?)"; EN="Windows Update Installation History (?)"; TipPT="Para o serviço wuauserv temporariamente e remove logs antigos do DataStore do Windows Update."; TipEN="Temporarily stops wuauserv and removes old DataStore logs from Windows Update." }
    "ClnDamagedAppx"       = @{ PT="Damaged Appx (?)"; EN="Damaged Appx Packages (?)"; TipPT="Limpa caches temporários e resíduos de pacotes UWP/Appx."; TipEN="Cleans temporary caches and leftovers from UWP/Appx packages." }
    "ClnRestorePoints"     = @{ PT="Pontos de restauração do sistema (?)"; EN="System Restore Points (?)"; TipPT="ATENÇÃO: Remove TODOS os Pontos de Restauração do Sistema (VSS), incluindo pontos criados automaticamente pelo Windows Update."; TipEN="WARNING: Deletes ALL System Restore Points (VSS), including rollback points created by Windows Update." }

    "CatCache"             = @{ PT="Arquivos de Cache"; EN="Cache Files"; TipPT="Caches de download do Windows Update, Delivery Optimization, RDP, .NET, Prefetch, Miniaturas e WinINet."; TipEN="Windows Update, Delivery Optimization, RDP, .NET, Prefetch, Thumbnails, and WinINet caches." }
    "ClnWinDownloadCache"  = @{ PT="Cache de download do Windows (?)"; EN="Windows Download Cache (?)"; TipPT="Para wuauserv/bits e limpa os pacotes baixados em SoftwareDistribution\Download."; TipEN="Stops wuauserv/bits and clears downloaded update installers inside SoftwareDistribution\Download." }
    "ClnDeliveryOptCache"  = @{ PT="Delivery Optimization Cache (?)"; EN="Delivery Optimization Cache (?)"; TipPT="Remove arquivos em cache do serviço Otimização de Entrega."; TipEN="Removes cached files stored by the Delivery Optimization service." }
    "ClnRdpClientCache"    = @{ PT="Terminal Server Client Cache (?)"; EN="Terminal Server Client Cache (?)"; TipPT="Limpa o cache de bitmaps da Área de Trabalho Remota (mstsc.exe)."; TipEN="Clears Remote Desktop Connection bitmap cache files." }
    "ClnNetAssemblyCache"  = @{ PT="Cache do NET assembly (?)"; EN=".NET Assembly Cache (?)"; TipPT="Remove arquivos temporários compilados e logs de uso do .NET Framework."; TipEN="Removes temporary compiled files and usage logs from .NET Framework." }
    "ClnPrefetchFiles"     = @{ PT="Arquivos prefetch do Windows (?)"; EN="Windows Prefetch Files (?)"; TipPT="Limpa arquivos .pf antigos da pasta C:\Windows\Prefetch."; TipEN="Clears old .pf files from C:\Windows\Prefetch." }
    "ClnThumbnailCache"    = @{ PT="Cache de Miniatura (Reinicia Explorer) (?)"; EN="Thumbnail Cache (Restarts Explorer) (?)"; TipPT="Encerra o explorer.exe antes de apagar thumbcache_*.db e iconcache_*.db e inicia apenas se o Windows não o tiver reiniciado."; TipEN="Stops explorer.exe before deleting thumbcache_*.db and iconcache_*.db and starts it only if Windows has not restarted it." }
    "ClnWinInetWebCache"   = @{ PT="Cache Web do WinINet (?)"; EN="WinINet Web Cache (?)"; TipPT="Limpa o cache de arquivos temporários da API WinINet."; TipEN="Clears temporary internet cache files managed by WinINet." }
    "ClnWinInetCookies"    = @{ PT="Cookies do WinINet (?)"; EN="WinINet Cookies (?)"; TipPT="Limpa cookies armazenados pela pilha WinINet do Windows."; TipEN="Clears cookies stored by the Windows WinINet stack." }

    "CatApps"              = @{ PT="Aplicações"; EN="Applications"; TipPT="Caches internos de pacotes da Store e histórico do Windows Defender."; TipEN="Internal Store package caches and Windows Defender protection history." }
    "ClnPackageCache"      = @{ PT="Pasta de cache de pacote (?)"; EN="Package Cache Folder (?)"; TipPT="Limpa caches locais temporários de pacotes UWP/Store em LocalCache."; TipEN="Clears temporary local caches inside UWP/Store app LocalCache folders." }
    "ClnDefenderHistory"   = @{ PT="Windows Defender Histórico de Proteção (?)"; EN="Windows Defender Protection History (?)"; TipPT="Limpa o histórico de verificações e detecções antigas do Microsoft Defender."; TipEN="Clears old scan logs and protection history from Microsoft Defender." }

    "CatTemp"              = @{ PT="Arquivos Temporários"; EN="Temporary Files"; TipPT="Temporários do WinSxS, Logs, Temp, Lixeira, Crash Dumps, resíduos de atualização e IDM."; TipEN="WinSxS temp, Logs, Temp folders, Recycle Bin, Crash Dumps, upgrade junk, and IDM temp." }
    "ClnWinSxSTemp"        = @{ PT="Arquivos Temporários WinSxS (?)"; EN="WinSxS Temporary Files (?)"; TipPT="Remove arquivos temporários pendentes em C:\Windows\WinSxS\Temp."; TipEN="Removes pending temporary files inside C:\Windows\WinSxS\Temp." }
    "ClnWindowsLogs"       = @{ PT="Log do Windows (?)"; EN="Windows Logs (?)"; TipPT="Limpa arquivos de log antigos (.log) em Windows\Logs e Panther."; TipEN="Clears old .log files in Windows\Logs and Panther." }
    "ClnTempFiles"         = @{ PT="Arquivos Temporários (?)"; EN="Temporary Files (?)"; TipPT="Limpa arquivos temporários do usuário (%TEMP%) e do sistema (C:\Windows\Temp)."; TipEN="Clears user (%TEMP%) and system (C:\Windows\Temp) temporary files." }
    "ClnRecycleBin"        = @{ PT="Estação de reciclagem (?)"; EN="Recycle Bin (?)"; TipPT="Esvazia permanentemente a Lixeira de todas as unidades locais."; TipEN="Permanently empties the Recycle Bin across all local drives." }
    "ClnCrashDumps"        = @{ PT="Arquivos de despejo (.dmp) do Sistema e Apps (?)"; EN="System and Application .dmp files (?)"; TipPT="Remove arquivos MEMORY.DMP, Minidump e CrashDumps."; TipEN="Removes MEMORY.DMP, Minidump, and CrashDumps." }
    "ClnMaJunkFiles"       = @{ PT="Arquivos inúteis de MA (?)"; EN="MA / Upgrade Junk Files (?)"; TipPT="Remove resíduos de atualizações de recursos do Windows."; TipEN="Removes Windows feature upgrade leftovers." }
    "ClnIdmTempFiles"      = @{ PT="Internet Download Manager temporary files (?)"; EN="Internet Download Manager temporary files (?)"; TipPT="Limpa downloads temporários incompletos do IDM (DwnlData). AVISO: Feche o IDM antes para não corromper downloads em andamento."; TipEN="Clears incomplete temporary IDM downloads (DwnlData). WARNING: Close IDM first to avoid corrupting active downloads." }
}

function Refresh-CachedStatusLabels {
    $valExtraPT = if ($script:GameStateCache.IsValorant) { " + Auto-Encerrar RiotClient" } else { "" }
    $valExtraEN = if ($script:GameStateCache.IsValorant) { " + Auto-Close RiotClient" } else { "" }

    if ($script:Lang -eq "PT") {
        $LblCpuTopology.Text = "CPU: $($script:HwInfo.Cores) Núcleos / $($script:HwInfo.Threads) Threads"
        $LblCpuMaskInfo.Text = if ($script:HwInfo.Threads -gt 64) { "Grupo >64 Threads (Não suportado)" } else { "Afinidade Bitwise: Sem CPU 0" }

        $StatusDscp.Text = if ($script:GameStateCache.Dscp) { "Status: ATIVADO (Prioridade de rede DSCP 46 ativa)" } else { "Status: Desativado" }
        $StatusAffinity.Text = if ($script:HwInfo.Threads -gt 64) {
            "Status: Indisponível (CPU com mais de 64 threads usa Processor Groups)"
        } elseif ($script:GameStateCache.Affinity) {
            "Status: ATIVADO (Alta Prioridade + Bitwise Sem CPU 0$valExtraPT)"
        } else {
            "Status: Desativado"
        }
        $StatusDx11.Text = switch ($script:GameStateCache.Dx11State) {
            "APPLIED"  { "Status: ATIVADO no Registro (Flags 0x211 aplicado)" }
            "WATCHING" { "Status: MONITORANDO (Aplicação automática na próxima abertura)" }
            default    { "Status: Desativado" }
        }
        $StatusNvTel.Text = if (-not $script:HwInfo.HasNvidia) {
            "Status: Indisponível (GPU/Serviços NVIDIA não detectados neste PC)"
        } elseif ($script:GameStateCache.NvTel) {
            "Status: ATIVADO (Pausa serviços NVIDIA ao jogar e restaura ao fechar)"
        } else {
            "Status: Desativado"
        }
        $StatusWinUpdateCard.Text = if ($script:WinUpdateDisabledCache) { "Status: Desativado (wuauserv, UsoSvc e WaaSMedicSvc bloqueados)." } else { "Status: Ativo (Padrão do Windows)." }
    } else {
        $LblCpuTopology.Text = "CPU: $($script:HwInfo.Cores) Cores / $($script:HwInfo.Threads) Threads"
        $LblCpuMaskInfo.Text = if ($script:HwInfo.Threads -gt 64) { "Group >64 Threads (Unsupported)" } else { "Bitwise Affinity: No CPU 0" }

        $StatusDscp.Text = if ($script:GameStateCache.Dscp) { "Status: ENABLED (DSCP 46 network priority active)" } else { "Status: Disabled" }
        $StatusAffinity.Text = if ($script:HwInfo.Threads -gt 64) {
            "Status: Unavailable (CPUs over 64 threads use Processor Groups)"
        } elseif ($script:GameStateCache.Affinity) {
            "Status: ENABLED (High Priority + Bitwise No-CPU0$valExtraEN)"
        } else {
            "Status: Disabled"
        }
        $StatusDx11.Text = switch ($script:GameStateCache.Dx11State) {
            "APPLIED"  { "Status: ENABLED in Registry (Flags 0x211 applied)" }
            "WATCHING" { "Status: WATCHING (Auto-applies on next game launch)" }
            default    { "Status: Disabled" }
        }
        $StatusNvTel.Text = if (-not $script:HwInfo.HasNvidia) {
            "Status: Unavailable (NVIDIA GPU/services not detected on this PC)"
        } elseif ($script:GameStateCache.NvTel) {
            "Status: ENABLED (Pauses NVIDIA services in-game & restores on exit)"
        } else {
            "Status: Disabled"
        }
        $StatusWinUpdateCard.Text = if ($script:WinUpdateDisabledCache) { "Status: Disabled (wuauserv, UsoSvc & WaaSMedicSvc blocked)." } else { "Status: Active (Windows Default)." }
    }
}

function Set-AppLanguage ([string]$langCode, [bool]$Persist = $true) {
    $script:Lang = $langCode
    if ($Persist) { Save-UserAppSettings }

    foreach ($key in $script:ControlMeta.Keys) {
        $ctrl = Get-Variable -Name $key -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $ctrl) {
            $meta = $script:ControlMeta[$key]
            $ctrl.Content = if ($langCode -eq "PT") { $meta.PT } else { $meta.EN }
            $ctrl.ToolTip = if ($langCode -eq "PT") { $meta.TipPT } else { $meta.TipEN }
        }
    }

    if ($langCode -eq "PT") {
        $BtnLangPT.Background = "#7C3AED"; $BtnLangPT.Foreground = "#FFFFFF"; $BtnLangPT.BorderBrush = "#A78BFA"
        $BtnLangEN.Background = "Transparent"; $BtnLangEN.ClearValue([System.Windows.Controls.Control]::ForegroundProperty); $BtnLangEN.BorderBrush = "Transparent"

        $BtnNavTweaks.Content = "Otimizações"; $BtnNavGaming.Content = "Gaming"; $BtnNavDeepClean.Content = "Limpeza Profunda"; $BtnNavAdvanced.Content = "Avançado"
        $LblSearchPlaceholder.Text = "Pesquisar otimização, jogo ou limpeza..."
        $LblRecTitle.Text = "Seleções Recomendadas:"
        $BtnPresetStd.Content = "Padrão"; $BtnPresetMin.Content = "Mínimo"; $BtnPresetAdv.Content = "Avançado"
        $BtnPresetClr.Content = "Desmarcar Tudo"; $BtnSelectInstalled.Content = "Detectar Otimizações Ativas"
        $LblNativeTools.Text = "Ferramentas Nativas do Windows:"
        $BtnOpenCleanmgr.Content = "🧹 Limpeza de Disco (cleanmgr)"
        $BtnCreateRestore.Content = "🛡️ Criar Ponto de Restauração"

        $HdrEssential.Text = "Otimizações Essenciais"
        $HdrAdvCaution.Text = "Otimizações Avançadas - CUIDADO"
        $HdrSecOverhead.Text = "Segurança e Overhead de CPU (Requer Confirmação)"
        $LblDnsSet.Text = "DNS - Definir para:"
        $HdrCustomize.Text = "Personalizar Preferências (Tempo Real)"
        $LblMpo.Text = "Sobreposição Multiplano (MPO):"
        $HdrPerfPlans.Text = "Planos de Energia - NÃO USAR EM NOTEBOOKS"
        $BtnUltDisable.Content = "Perfil Desempenho Máximo - Desativar (Restaurar Anterior)"
        $BtnUltEnable.Content = "Perfil Desempenho Máximo - Ativar (Ultimate)"

        $HdrGameList.Text = "Competitive Games"
        $SubGameList.Text = "Selecione um jogo para gerenciar otimizações automáticas."
        $HdrAddCustomGame.Text = "Adicionar Jogo Personalizado"
        $LblGameName.Text = "Nome do Jogo:"
        $LblGameExe.Text = "Executável (.exe):"
        $BtnBrowseExe.Content = "Procurar..."
        $BtnAddGame.Content = "Adicionar Jogo"
        $BtnRemoveGame.Content = "Remover Selecionado"

        $HdrDscp.Text = "Priorizar Rota de Jogo"
        $DescDscp.Text = "Prioriza o tráfego de rede do jogo selecionado usando política QoS DSCP 46 para reduzir jitter e perda de pacotes."
        $HdrAffinity.Text = "Prioridade Alta + Afinidade Otimizada"
        $DescAffinity.Text = "Aplica prioridade Alta e libera a CPU lógica 0 via máscara bitwise (preservando demais cores) ao iniciar o jogo. No VALORANT, encerra o RiotClientServices assim que o jogo estabiliza."
        $HdrDx11.Text = "Remover Latência de Tela Cheia"
        $DescDx11.Text = "Ajusta o comportamento de tela cheia exclusiva (DX11 Flags 0x211) no registro para reduzir input lag apenas para o jogo selecionado."
        $HdrNvTel.Text = "Desativar Telemetria NVIDIA"
        $DescNvTel.Text = "Pausa automaticamente os serviços de container/telemetria NVIDIA enquanto o jogo está aberto e restaura exatamente o estado original ao fechar (isolado por jogo)."

        $HdrDeepCleanTitle.Text = "Limpeza Profunda do Sistema (Motor Nativo C# / DISM++)"
        $SubDeepCleanDesc.Text = "Selecione caches do sistema, componentes substituídos do WinSxS, logs e arquivos temporários. Todos os logs saem no terminal PowerShell."
        $BtnCleanScan.Content = "🔍 Verificar Espaço"
        $BtnCleanDefault.Content = "Padrão"
        $BtnCleanAll.Content = "Marcar Tudo"
        $BtnCleanNone.Content = "Nenhum"
        $BtnCleanExecute.Content = "🧹 Limpar Selecionados"

        $HdrAdvTabTitle.Text = "Avançado"
        $HdrWinUpdateCard.Text = "Windows Update"
        $DescWinUpdateCard.Text = "Desativa os serviços de atualização (wuauserv, UsoSvc, WaaSMedicSvc) e bloqueia reinicializações automáticas. Restaurar devolve o estado original salvo do Windows."
        $BtnDisableWinUpdate.Content = "Desativar Windows Update"
        $BtnRestoreWinUpdate.Content = "Restaurar Windows Update"
        $HdrNetResetCard.Text = "Manutenção do Sistema e Pilha de Rede"
        $DescNetResetCard.Text = "Abra a ferramenta nativa de Limpeza de Disco do Windows (cleanmgr.exe), limpe caches temporários ou redefina a pilha de rede Winsock/DNS."
        $BtnAdvCleanmgr.Content = "Abrir Limpeza de Disco (cleanmgr)"
        $BtnAdvCleanCache.Content = "Limpar Temp e Prefetch"
        $BtnAdvFlushNet.Content = "Resetar Rede e Limpar DNS"

        $LblFooterNote.Text = "Nota: Passe o mouse sobre (?) para ver detalhes. Todo o histórico detalhado das operações é exibido diretamente no console do PowerShell."
        $BtnRunTweaks.Content = "Aplicar Otimizações"
        $BtnUndoTweaks.Content = "Reverter Selecionadas"
    } else {
        $BtnLangEN.Background = "#7C3AED"; $BtnLangEN.Foreground = "#FFFFFF"; $BtnLangEN.BorderBrush = "#A78BFA"
        $BtnLangPT.Background = "Transparent"; $BtnLangPT.ClearValue([System.Windows.Controls.Control]::ForegroundProperty); $BtnLangPT.BorderBrush = "Transparent"

        $BtnNavTweaks.Content = "Tweaks"; $BtnNavGaming.Content = "Gaming"; $BtnNavDeepClean.Content = "Deep Clean"; $BtnNavAdvanced.Content = "Advanced"
        $LblSearchPlaceholder.Text = "Search tweaks, games or cleanup..."
        $LblRecTitle.Text = "Recommended Selections:"
        $BtnPresetStd.Content = "Standard"; $BtnPresetMin.Content = "Minimal"; $BtnPresetAdv.Content = "Advanced"
        $BtnPresetClr.Content = "Clear All"; $BtnSelectInstalled.Content = "Detect Active Optimizations"
        $LblNativeTools.Text = "Native Windows Tools:"
        $BtnOpenCleanmgr.Content = "🧹 Disk Cleanup (cleanmgr)"
        $BtnCreateRestore.Content = "🛡️ Create Restore Point"

        $HdrEssential.Text = "Essential Tweaks"
        $HdrAdvCaution.Text = "Advanced Tweaks - CAUTION"
        $HdrSecOverhead.Text = "Security & CPU Overhead (Confirmation Required)"
        $LblDnsSet.Text = "DNS - Set to:"
        $HdrCustomize.Text = "Customize Preferences (Real-Time)"
        $LblMpo.Text = "Multiplane Overlay (MPO):"
        $HdrPerfPlans.Text = "Performance Plans - NOT FOR LAPTOPS"
        $BtnUltDisable.Content = "Ultimate Performance Profile - Disable (Restore Previous)"
        $BtnUltEnable.Content = "Ultimate Performance Profile - Enable"

        $HdrGameList.Text = "Competitive Games"
        $SubGameList.Text = "Select a game to manage automatic optimizations."
        $HdrAddCustomGame.Text = "Add Custom Game"
        $LblGameName.Text = "Game Name:"
        $LblGameExe.Text = "Executable (.exe):"
        $BtnBrowseExe.Content = "Browse..."
        $BtnAddGame.Content = "Add to List"
        $BtnRemoveGame.Content = "Remove Selected"

        $HdrDscp.Text = "Prioritize Game Route"
        $DescDscp.Text = "Prioritizes network traffic for the selected game using QoS DSCP 46 policy to reduce jitter and packet latency."
        $HdrAffinity.Text = "High Priority + Optimized Affinity"
        $DescAffinity.Text = "Automatically applies High priority and unchecks Logical CPU 0 via bitwise mask when the game starts. For VALORANT, closes RiotClientServices once the game stabilizes."
        $HdrDx11.Text = "Remove Fullscreen Latency"
        $DescDx11.Text = "Applies targeted DX11 fullscreen optimization flags (0x211) exclusively for the selected game to lower display input lag."
        $HdrNvTel.Text = "Disable NVIDIA Telemetry"
        $DescNvTel.Text = "Automatically pauses NVIDIA container/telemetry services while the game runs and restores their exact original state when you exit (per-game isolated backup)."

        $HdrDeepCleanTitle.Text = "Deep System Cleanup (Native C# / DISM++ Engine)"
        $SubDeepCleanDesc.Text = "Select system caches, WinSxS superseded components, logs, and temporary files. All verbose logs output directly to the PowerShell terminal."
        $BtnCleanScan.Content = "🔍 Scan Space"
        $BtnCleanDefault.Content = "Default"
        $BtnCleanAll.Content = "Select All"
        $BtnCleanNone.Content = "None"
        $BtnCleanExecute.Content = "🧹 Clean Selected"

        $HdrAdvTabTitle.Text = "Advanced"
        $HdrWinUpdateCard.Text = "Windows Update"
        $DescWinUpdateCard.Text = "Disables Windows Update services (wuauserv, UsoSvc, WaaSMedicSvc) and prevents forced automatic restarts. Restore returns services to saved original settings."
        $BtnDisableWinUpdate.Content = "Disable Windows Update"
        $BtnRestoreWinUpdate.Content = "Restore Windows Update"
        $HdrNetResetCard.Text = "System Maintenance & Network Stack"
        $DescNetResetCard.Text = "Launch the official Windows Disk Cleanup utility (cleanmgr.exe), purge temporary caches, or reset the Winsock/TCP-IP network stack."
        $BtnAdvCleanmgr.Content = "Launch Disk Cleanup (cleanmgr)"
        $BtnAdvCleanCache.Content = "Purge Temp & Prefetch"
        $BtnAdvFlushNet.Content = "Reset Network & Flush DNS"

        $LblFooterNote.Text = "Note: Hover over (?) to view details. Full verbose logs of all actions are printed directly in the PowerShell console."
        $BtnRunTweaks.Content = "Apply Selected Tweaks"
        $BtnUndoTweaks.Content = "Revert Selected Tweaks"
    }
    Update-CleanSizeLabels
    Refresh-CachedStatusLabels
}

$BtnLangEN.Add_Click({ Set-AppLanguage "EN" $true })
$BtnLangPT.Add_Click({ Set-AppLanguage "PT" $true })

# ==============================================================================
# TEMAS (DARK & LIGHT COMPLETOS), CONTROLES DA JANELA E BUSCA MULTI-ABA
# ==============================================================================
function Apply-AppTheme ([bool]$darkMode) {
    $script:isDark = $darkMode
    $bc = New-Object System.Windows.Media.BrushConverter
    if ($darkMode) {
        $window.Resources["BgMain"]          = $bc.ConvertFromString("#111017")
        $window.Resources["BgPanel"]         = $bc.ConvertFromString("#171520")
        $window.Resources["BgCard"]          = $bc.ConvertFromString("#111017")
        $window.Resources["BgCardHover"]     = $bc.ConvertFromString("#211D30")
        $window.Resources["BgCardSelected"]  = $bc.ConvertFromString("#282042")
        $window.Resources["BgHeader"]        = $bc.ConvertFromString("#0C0B10")
        $window.Resources["BgInput"]         = $bc.ConvertFromString("#221E30")
        $window.Resources["BgBtn"]           = $bc.ConvertFromString("#221E30")
        $window.Resources["BgBtnHover"]      = $bc.ConvertFromString("#2F2944")
        $window.Resources["BorderSubtle"]    = $bc.ConvertFromString("#2E2942")
        $window.Resources["BorderHighlight"] = $bc.ConvertFromString("#8B5CF6")
        $window.Resources["TextMain"]        = $bc.ConvertFromString("#F3F4F6")
        $window.Resources["TextDim"]         = $bc.ConvertFromString("#9CA3AF")
        $window.Resources["PurpleHeader"]    = $bc.ConvertFromString("#A78BFA")
        $BtnTheme.Content = "☀"
    } else {
        $window.Resources["BgMain"]          = $bc.ConvertFromString("#F4F2FA")
        $window.Resources["BgPanel"]         = $bc.ConvertFromString("#FFFFFF")
        $window.Resources["BgCard"]          = $bc.ConvertFromString("#F8F7FC")
        $window.Resources["BgCardHover"]     = $bc.ConvertFromString("#EDE9FE")
        $window.Resources["BgCardSelected"]  = $bc.ConvertFromString("#DDD6FE")
        $window.Resources["BgHeader"]        = $bc.ConvertFromString("#EAE6F8")
        $window.Resources["BgInput"]         = $bc.ConvertFromString("#FFFFFF")
        $window.Resources["BgBtn"]           = $bc.ConvertFromString("#EDE9FE")
        $window.Resources["BgBtnHover"]      = $bc.ConvertFromString("#DDD6FE")
        $window.Resources["BorderSubtle"]    = $bc.ConvertFromString("#D4CCF0")
        $window.Resources["BorderHighlight"] = $bc.ConvertFromString("#7C3AED")
        $window.Resources["TextMain"]        = $bc.ConvertFromString("#1E1B4B")
        $window.Resources["TextDim"]         = $bc.ConvertFromString("#5B5578")
        $window.Resources["PurpleHeader"]    = $bc.ConvertFromString("#6D28D9")
        $BtnTheme.Content = "🌙"
    }
    Switch-Tab $script:CurrentTab
}

$script:CurrentTab = "Tweaks"
function Switch-Tab ([string]$tab) {
    $script:CurrentTab = $tab
    $ViewTweaks.Visibility    = if ($tab -eq "Tweaks")    { "Visible" } else { "Collapsed" }
    $ViewGaming.Visibility    = if ($tab -eq "Gaming")    { "Visible" } else { "Collapsed" }
    $ViewDeepClean.Visibility = if ($tab -eq "DeepClean") { "Visible" } else { "Collapsed" }
    $ViewAdvanced.Visibility  = if ($tab -eq "Advanced")  { "Visible" } else { "Collapsed" }

    $inactiveBg = if ($script:isDark) { "#221E30" } else { "#EDE9FE" }
    foreach ($pair in @(
        @($BtnNavTweaks, "Tweaks"),
        @($BtnNavGaming, "Gaming"),
        @($BtnNavDeepClean, "DeepClean"),
        @($BtnNavAdvanced, "Advanced")
    )) {
        $btn = $pair[0]; $name = $pair[1]
        if ($tab -eq $name) {
            $btn.Background = "#7C3AED"
            $btn.Foreground = "#FFFFFF"
        } else {
            $btn.Background = $inactiveBg
            $btn.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
        }
    }
}
$BtnNavTweaks.Add_Click({ Switch-Tab "Tweaks" })
$BtnNavGaming.Add_Click({ Switch-Tab "Gaming" })
$BtnNavDeepClean.Add_Click({ Switch-Tab "DeepClean" })
$BtnNavAdvanced.Add_Click({ Switch-Tab "Advanced" })

$TitleBar.Add_MouseLeftButtonDown({
    param($sender, $e)
    if ($e.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        try { $window.DragMove() } catch {}
    }
})

$BtnMin.Add_Click({ $window.WindowState = 'Minimized' })

$script:IsCustomMaximized = $false
$script:NormalBounds = @{ Left = 0; Top = 0; Width = 1360; Height = 860 }
$BtnMax.Add_Click({
    if (-not $script:IsCustomMaximized) {
        $script:NormalBounds.Left   = $window.Left
        $script:NormalBounds.Top    = $window.Top
        $script:NormalBounds.Width  = $window.Width
        $script:NormalBounds.Height = $window.Height

        $wa = [System.Windows.SystemParameters]::WorkArea
        $window.Left   = $wa.Left
        $window.Top    = $wa.Top
        $window.Width  = $wa.Width
        $window.Height = $wa.Height
        $RootBorder.CornerRadius = New-Object System.Windows.CornerRadius(0)
        $script:IsCustomMaximized = $true
    } else {
        $window.Left   = $script:NormalBounds.Left
        $window.Top    = $script:NormalBounds.Top
        $window.Width  = $script:NormalBounds.Width
        $window.Height = $script:NormalBounds.Height
        $RootBorder.CornerRadius = New-Object System.Windows.CornerRadius(5)
        $script:IsCustomMaximized = $false
    }
})
$BtnClose.Add_Click({ $window.Close() })

$BtnTheme.Add_Click({
    Apply-AppTheme (-not $script:isDark)
    Save-UserAppSettings
})

$TxtSearch.Add_TextChanged({
    $q = $TxtSearch.Text.Trim().ToLower()
    $hasQuery = -not [string]::IsNullOrWhiteSpace($q)

    # 1. Filtrar Aba Tweaks
    foreach ($ctrl in ($PanelLeft.Children + $PanelRight.Children)) {
        if ($ctrl -is [System.Windows.Controls.CheckBox]) {
            $txt = if ($null -ne $ctrl.Content) { $ctrl.Content.ToString().ToLower() } else { "" }
            $ctrl.Visibility = if (-not $hasQuery -or $txt.Contains($q)) { 'Visible' } else { 'Collapsed' }
        }
    }

    # 2. Filtrar Aba Deep Clean
    foreach ($it in $script:CleanItems) {
        $txt = if ($null -ne $it.Chk.Content) { $it.Chk.Content.ToString().ToLower() } else { "" }
        $rowGrid = $it.Chk.Parent
        if ($rowGrid -is [System.Windows.Controls.Grid]) {
            $rowGrid.Visibility = if (-not $hasQuery -or $txt.Contains($q)) { 'Visible' } else { 'Collapsed' }
        }
    }

    # 3. Filtrar Aba Gaming (Cards e Seleção de Jogo)
    $gameCards = @(
        @($CardGameDscp, $HdrDscp, $DescDscp),
        @($CardGameAffinity, $HdrAffinity, $DescAffinity),
        @($CardGameDx11, $HdrDx11, $DescDx11),
        @($CardGameNvTel, $HdrNvTel, $DescNvTel)
    )
    foreach ($gc in $gameCards) {
        $card = $gc[0]; $hdr = $gc[1]; $desc = $gc[2]
        $combined = ("$($hdr.Text) $($desc.Text)").ToLower()
        $card.Visibility = if (-not $hasQuery -or $combined.Contains($q)) { 'Visible' } else { 'Collapsed' }
    }
    if ($hasQuery) {
        for ($i = 0; $i -lt $script:GameList.Count; $i++) {
            $g = $script:GameList[$i]
            if ($g.Name.ToLower().Contains($q) -or $g.Exe.ToLower().Contains($q)) {
                if ($LstGames.SelectedIndex -ne $i) { $LstGames.SelectedIndex = $i }
                break
            }
        }
    }
})

# ==============================================================================
# LIMPEZA DE DISCO NATIVA (cleanmgr.exe) E PONTO DE RESTAURAÇÃO
# ==============================================================================
function Start-NativeDiskCleanup {
    $cleanmgrPath = "$env:SystemRoot\System32\cleanmgr.exe"
    if (Test-Path $cleanmgrPath) {
        Start-Process -FilePath $cleanmgrPath -ArgumentList "/d $env:SystemDrive"
        Write-BTLog "Limpador de Disco nativo aberto (cleanmgr.exe)." "OK"
    } else {
        Write-BTLog "cleanmgr.exe não encontrado em System32." "ERROR"
    }
}
$BtnOpenCleanmgr.Add_Click({ Start-NativeDiskCleanup })
$BtnAdvCleanmgr.Add_Click({ Start-NativeDiskCleanup })

$BtnCreateRestore.Add_Click({
    Invoke-SafeTweak "Criar Ponto de Restauração (BetterTitus)" {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" "SystemRestorePointCreationFrequency" 0
        Checkpoint-Computer -Description "BetterTitus_RestorePoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    }
})

# ==============================================================================
# MOTOR ASSÍNCRONO DA ABA "LIMPEZA PROFUNDA"
# ==============================================================================
$script:CleanScannedBytes = @{}
$userLocalAppData = Join-Path $script:UserCtx.UserProfile "AppData\Local"
$userRoamingAppData = Join-Path $script:UserCtx.UserProfile "AppData\Roaming"
$userTempPath = Join-Path $userLocalAppData "Temp"

$script:CleanItems = @(
    @{ Id="WinSxSSuperseded"; Chk=$ClnWinSxSSuperseded; Sz=$SzWinSxSSuperseded; Cat="Expired"; Default=$true; Mode="DISM"; Paths=@() },
    @{ Id="DismResidual";     Chk=$ClnDismResidual;     Sz=$SzDismResidual;     Cat="Expired"; Default=$true; Mode="PATH"; Paths=@("$env:windir\Logs\DISM\*.bak", "$env:windir\Temp\DISM*") },
    @{ Id="ChromeOldBackup";  Chk=$ClnChromeOldBackup;  Sz=$SzChromeOldBackup;  Cat="Expired"; Default=$true; Mode="PATH"; Paths=@("$userLocalAppData\Google\Chrome\User Data\*\old_*", "$userLocalAppData\Google\Chrome\Temp\*", "${env:ProgramFiles}\Google\Chrome\Application\old_*") },

    @{ Id="WerReports";       Chk=$ClnWerReports;       Sz=$SzWerReports;       Cat="System";  Default=$true; Mode="PATH"; Paths=@("$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*", "$userLocalAppData\Microsoft\Windows\WER\ReportArchive\*", "$userLocalAppData\Microsoft\Windows\WER\ReportQueue\*") },
    @{ Id="WinEvents";        Chk=$ClnWinEvents;        Sz=$SzWinEvents;        Cat="System";  Default=$true; Mode="EVTX"; Paths=@("$env:windir\System32\winevt\Logs\*.evtx") },
    @{ Id="WinUpdateHistory"; Chk=$ClnWinUpdateHistory; Sz=$SzWinUpdateHistory; Cat="System";  Default=$true; Mode="WUHIST"; Paths=@("$env:windir\SoftwareDistribution\DataStore\Logs\*", "$env:windir\SoftwareDistribution\ReportingEvents.log") },
    @{ Id="DamagedAppx";      Chk=$ClnDamagedAppx;      Sz=$SzDamagedAppx;      Cat="System";  Default=$true; Mode="PATH"; Paths=@("$userLocalAppData\Packages\*\TempState\*", "$userLocalAppData\Packages\*\AC\Temp\*") },
    @{ Id="RestorePoints";    Chk=$ClnRestorePoints;    Sz=$SzRestorePoints;    Cat="System";  Default=$true; Mode="VSS";  Paths=@() },

    @{ Id="WinDownloadCache"; Chk=$ClnWinDownloadCache; Sz=$SzWinDownloadCache; Cat="Cache";   Default=$true; Mode="WUDL"; Paths=@("$env:windir\SoftwareDistribution\Download\*") },
    @{ Id="DeliveryOptCache"; Chk=$ClnDeliveryOptCache; Sz=$SzDeliveryOptCache; Cat="Cache";   Default=$true; Mode="DO";   Paths=@("$env:windir\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*") },
    @{ Id="RdpClientCache";   Chk=$ClnRdpClientCache;   Sz=$SzRdpClientCache;   Cat="Cache";   Default=$true; Mode="PATH"; Paths=@("$userLocalAppData\Microsoft\Terminal Server Client\Cache\*") },
    @{ Id="NetAssemblyCache"; Chk=$ClnNetAssemblyCache; Sz=$SzNetAssemblyCache; Cat="Cache";   Default=$true; Mode="PATH"; Paths=@("$env:windir\Microsoft.NET\Framework\*\Temporary ASP.NET Files\*", "$env:windir\Microsoft.NET\Framework64\*\Temporary ASP.NET Files\*", "$userLocalAppData\Microsoft\CLR_v*\UsageLogs\*") },
    @{ Id="PrefetchFiles";    Chk=$ClnPrefetchFiles;    Sz=$SzPrefetchFiles;    Cat="Cache";   Default=$true; Mode="PATH"; Paths=@("$env:windir\Prefetch\*.pf", "$env:windir\Prefetch\*.db") },
    @{ Id="ThumbnailCache";   Chk=$ClnThumbnailCache;   Sz=$SzThumbnailCache;   Cat="Cache";   Default=$true; Mode="THUMB";Paths=@("$userLocalAppData\Microsoft\Windows\Explorer\thumbcache_*.db", "$userLocalAppData\Microsoft\Windows\Explorer\iconcache_*.db") },
    @{ Id="WinInetWebCache";  Chk=$ClnWinInetWebCache;  Sz=$SzWinInetWebCache;  Cat="Cache";   Default=$true; Mode="PATH"; Paths=@("$userLocalAppData\Microsoft\Windows\INetCache\*") },
    @{ Id="WinInetCookies";   Chk=$ClnWinInetCookies;   Sz=$SzWinInetCookies;   Cat="Cache";   Default=$true; Mode="PATH"; Paths=@("$userLocalAppData\Microsoft\Windows\INetCookies\*") },

    @{ Id="PackageCache";     Chk=$ClnPackageCache;     Sz=$SzPackageCache;     Cat="Apps";    Default=$true; Mode="PATH"; Paths=@("$userLocalAppData\Packages\*\LocalCache\*") },
    @{ Id="DefenderHistory";  Chk=$ClnDefenderHistory;  Sz=$SzDefenderHistory;  Cat="Apps";    Default=$true; Mode="PATH"; Paths=@("$env:ProgramData\Microsoft\Windows Defender\Scans\History\Service\*", "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Results\*") },

    @{ Id="WinSxSTemp";       Chk=$ClnWinSxSTemp;       Sz=$SzWinSxSTemp;       Cat="Temp";    Default=$true; Mode="PATH"; Paths=@("$env:windir\WinSxS\Temp\*") },
    @{ Id="WindowsLogs";      Chk=$ClnWindowsLogs;      Sz=$SzWindowsLogs;      Cat="Temp";    Default=$true; Mode="PATH"; Paths=@("$env:windir\Logs\CBS\*.log", "$env:windir\Logs\DISM\*.log", "$env:windir\Panther\*.log", "$env:windir\*.log") },
    @{ Id="TempFiles";        Chk=$ClnTempFiles;        Sz=$SzTempFiles;        Cat="Temp";    Default=$true; Mode="PATH"; Paths=@("$userTempPath\*", "$env:windir\Temp\*") },
    @{ Id="RecycleBin";       Chk=$ClnRecycleBin;       Sz=$SzRecycleBin;       Cat="Temp";    Default=$true; Mode="BIN";  Paths=@() },
    @{ Id="CrashDumps";       Chk=$ClnCrashDumps;       Sz=$SzCrashDumps;       Cat="Temp";    Default=$true; Mode="PATH"; Paths=@("$env:windir\Minidump\*", "$env:windir\MEMORY.DMP", "$userLocalAppData\CrashDumps\*") },
    @{ Id="MaJunkFiles";      Chk=$ClnMaJunkFiles;      Sz=$SzMaJunkFiles;      Cat="Temp";    Default=$true; Mode="PATH"; Paths=@("$env:windir\SoftwareDistribution\PostRebootEventCache.V2\*", "$env:SystemDrive\`$Windows.~BT\*", "$env:SystemDrive\`$Windows.~WS\*") },
    @{ Id="IdmTempFiles";     Chk=$ClnIdmTempFiles;     Sz=$SzIdmTempFiles;     Cat="Temp";    Default=$false;Mode="PATH"; Paths=@("$userRoamingAppData\IDM\DwnlData\*") }
)

function Format-ByteSize ([int64]$bytes) {
    if ($bytes -ge 1GB) { return ("{0:N2} GB" -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ("{0:N2} MB" -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ("{0:N1} KB" -f ($bytes / 1KB)) }
    return "0.0 MB"
}

function Update-CleanSizeLabels {
    if ($null -eq $script:CleanScannedBytes) { $script:CleanScannedBytes = @{} }
    $reqText = if ($script:Lang -eq "PT") { "Requer verificar" } else { "Requires scan" }
    [int64]$selectedTotal = 0
    $hasAnyScan = ($script:CleanScannedBytes.Count -gt 0)

    foreach ($item in $script:CleanItems) {
        if ($script:CleanScannedBytes.ContainsKey($item.Id)) {
            $val = $script:CleanScannedBytes[$item.Id]
            if ($val -eq -2) {
                $item.Sz.Text = "DISM / WinSxS"
                $item.Sz.Foreground = "#A78BFA"
            } elseif ($val -eq -3) {
                $item.Sz.Text = if ($script:Lang -eq "PT") { "Cópias VSS" } else { "VSS Shadows" }
                $item.Sz.Foreground = "#F59E0B"
            } else {
                $item.Sz.Text = Format-ByteSize $val
                $item.Sz.Foreground = if ($val -gt 0) { "#4ADE80" } else { "#9CA3AF" }
                if ($item.Chk.IsChecked) { $selectedTotal += $val }
            }
        } else {
            $item.Sz.Text = $reqText
            $item.Sz.Foreground = "#9CA3AF"
        }
    }

    if (-not $script:CleanJobRunning) {
        if ($script:Lang -eq "PT") {
            $LblCleanTotalSize.Text = if ($hasAnyScan) { "Selecionado: $(Format-ByteSize $selectedTotal)" } else { "Estimado: Requer verificar" }
        } else {
            $LblCleanTotalSize.Text = if ($hasAnyScan) { "Selected: $(Format-ByteSize $selectedTotal)" } else { "Estimated: Requires scan" }
        }
    }
}

$script:syncingCleanCat = $false
function Bind-CategoryCheckbox ($catChk, [string]$catKey) {
    $catChk.Tag = $catKey
    $catChk.Add_Checked({
        param($sender, $e)
        if ($script:syncingCleanCat) { return }
        $script:syncingCleanCat = $true
        $key = $sender.Tag
        foreach ($it in ($script:CleanItems | Where-Object { $_.Cat -eq $key })) { $it.Chk.IsChecked = $true }
        $script:syncingCleanCat = $false
        Update-CleanSizeLabels
    })
    $catChk.Add_Unchecked({
        param($sender, $e)
        if ($script:syncingCleanCat) { return }
        $script:syncingCleanCat = $true
        $key = $sender.Tag
        foreach ($it in ($script:CleanItems | Where-Object { $_.Cat -eq $key })) { $it.Chk.IsChecked = $false }
        $script:syncingCleanCat = $false
        Update-CleanSizeLabels
    })
}
Bind-CategoryCheckbox $CatExpired "Expired"
Bind-CategoryCheckbox $CatSystem  "System"
Bind-CategoryCheckbox $CatCache   "Cache"
Bind-CategoryCheckbox $CatApps    "Apps"
Bind-CategoryCheckbox $CatTemp    "Temp"

foreach ($it in $script:CleanItems) {
    $it.Chk.Add_Checked({ Update-CleanSizeLabels })
    $it.Chk.Add_Unchecked({ Update-CleanSizeLabels })
}

$BtnCleanDefault.Add_Click({
    $script:syncingCleanCat = $true
    foreach ($it in $script:CleanItems) { $it.Chk.IsChecked = $it.Default }
    $CatExpired.IsChecked = $true; $CatSystem.IsChecked = $true; $CatCache.IsChecked = $true; $CatApps.IsChecked = $true; $CatTemp.IsChecked = $true
    $script:syncingCleanCat = $false
    Update-CleanSizeLabels
    Write-BTLog "Seleção padrão de Limpeza Profunda restaurada (24 itens)." "INFO"
})

$BtnCleanAll.Add_Click({
    $script:syncingCleanCat = $true
    foreach ($it in $script:CleanItems) { $it.Chk.IsChecked = $true }
    $CatExpired.IsChecked = $true; $CatSystem.IsChecked = $true; $CatCache.IsChecked = $true; $CatApps.IsChecked = $true; $CatTemp.IsChecked = $true
    $script:syncingCleanCat = $false
    Update-CleanSizeLabels
})

$BtnCleanNone.Add_Click({
    $script:syncingCleanCat = $true
    foreach ($it in $script:CleanItems) { $it.Chk.IsChecked = $false }
    $CatExpired.IsChecked = $false; $CatSystem.IsChecked = $false; $CatCache.IsChecked = $false; $CatApps.IsChecked = $false; $CatTemp.IsChecked = $false
    $script:syncingCleanCat = $false
    Update-CleanSizeLabels
})

$script:CleanJobRunning = $false
function Start-AsyncDeepCleanJob ([string]$JobType, [array]$WorkList) {
    if ($script:CleanJobRunning) { return }
    $script:CleanJobRunning = $true
    $BtnCleanScan.IsEnabled = $false
    $BtnCleanExecute.IsEnabled = $false

    if ($null -eq $script:CleanScannedBytes) { $script:CleanScannedBytes = @{} }

    $sync = [hashtable]::Synchronized(@{
        Done       = $false
        CurrentIdx = 0
        TotalCount = $WorkList.Count
        Results    = [System.Collections.Concurrent.ConcurrentDictionary[string, int64]]::new()
        Logs       = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
        FreedBytes = [int64]0
        ScanBytes  = [int64]0
    })

    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
        param($JobType, $WorkList, $Sync, $DllPath)
        try {
            if (-not ([System.Management.Automation.PSTypeName]'BetterTitus.FastCleaner').Type) {
                if (Test-Path $DllPath) { Add-Type -Path $DllPath -ErrorAction Stop }
            }
            function Enqueue-Log ([string]$m, [string]$l = "INFO") {
                $Sync.Logs.Enqueue(@{ Msg = $m; Lvl = $l })
            }
            function Fmt-Size ([int64]$b) {
                if ($b -ge 1GB) { return ("{0:N2} GB" -f ($b / 1GB)) }
                if ($b -ge 1MB) { return ("{0:N2} MB" -f ($b / 1MB)) }
                if ($b -ge 1KB) { return ("{0:N1} KB" -f ($b / 1KB)) }
                return "0.0 MB"
            }
            function Get-RecycleBinPatterns {
                $pats = @()
                $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
                foreach ($d in $drives) {
                    $pats += "$($d.DeviceID)\`$Recycle.Bin\*"
                }
                if ($pats.Count -eq 0) { $pats += "$env:SystemDrive\`$Recycle.Bin\*" }
                return $pats
            }
            function Get-SystemFreeBytes {
                try {
                    return [int64](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" -ErrorAction SilentlyContinue).FreeSpace
                } catch { return [int64]0 }
            }

            $idx = 0
            foreach ($item in $WorkList) {
                $idx++
                $Sync.CurrentIdx = $idx
                if ($JobType -eq "SCAN") {
                    if ($item.Mode -eq "DISM") {
                        $Sync.Results[$item.Id] = -2
                    } elseif ($item.Mode -eq "VSS") {
                        $Sync.Results[$item.Id] = -3
                    } elseif ($item.Mode -eq "BIN") {
                        $binPats = Get-RecycleBinPatterns
                        [int64]$sz = [BetterTitus.FastCleaner]::GetPatternSize($binPats)
                        $Sync.Results[$item.Id] = $sz
                        $Sync.ScanBytes += $sz
                        if ($sz -gt 0) { Enqueue-Log "$($item.Label) -> $(Fmt-Size $sz)" "INFO" }
                    } else {
                        [int64]$sz = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                        $Sync.Results[$item.Id] = $sz
                        $Sync.ScanBytes += $sz
                        if ($sz -gt 0) { Enqueue-Log "$($item.Label) -> $(Fmt-Size $sz)" "INFO" }
                    }
                } elseif ($JobType -eq "CLEAN") {
                    try {
                        [int64]$freed = 0
                        switch ($item.Mode) {
                            "DISM" {
                                $freeBefore = Get-SystemFreeBytes
                                Enqueue-Log "Executando DISM /StartComponentCleanup (aguarde)..." "INFO"
                                & dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet | Out-Null
                                $freeAfter = Get-SystemFreeBytes
                                $freed = [math]::Max(0, ($freeAfter - $freeBefore))
                                $Sync.Results[$item.Id] = -2
                            }
                            "VSS" {
                                $freeBefore = Get-SystemFreeBytes
                                & vssadmin.exe delete shadows /for=$env:SystemDrive /all /quiet 2>$null | Out-Null
                                $freeAfter = Get-SystemFreeBytes
                                $freed = [math]::Max(0, ($freeAfter - $freeBefore))
                                $Sync.Results[$item.Id] = -3
                            }
                            "EVTX" {
                                [int64]$before = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                foreach ($log in @("Application", "System", "Setup", "Windows PowerShell")) {
                                    & wevtutil.exe cl "$log" 2>$null
                                }
                                [int64]$after = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                $freed = [math]::Max(0, ($before - $after))
                                $Sync.Results[$item.Id] = $after
                            }
                            "WUHIST" {
                                $wuSvc = Get-Service "wuauserv" -ErrorAction SilentlyContinue
                                $wuWasRunning = ($null -ne $wuSvc -and $wuSvc.Status -eq 'Running')
                                if ($wuWasRunning) { Stop-Service -Name "wuauserv" -ErrorAction SilentlyContinue }
                                [int64]$before = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                [BetterTitus.FastCleaner]::CleanPattern($item.Paths)
                                [int64]$after = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                if ($wuWasRunning) { Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue }
                                $freed = [math]::Max(0, ($before - $after))
                                $Sync.Results[$item.Id] = $after
                            }
                            "WUDL" {
                                $wuSvc = Get-Service "wuauserv" -ErrorAction SilentlyContinue
                                $bitsSvc = Get-Service "bits" -ErrorAction SilentlyContinue
                                $wuWasRunning = ($null -ne $wuSvc -and $wuSvc.Status -eq 'Running')
                                $bitsWasRunning = ($null -ne $bitsSvc -and $bitsSvc.Status -eq 'Running')
                                if ($wuWasRunning) { Stop-Service -Name "wuauserv" -ErrorAction SilentlyContinue }
                                if ($bitsWasRunning) { Stop-Service -Name "bits" -ErrorAction SilentlyContinue }
                                [int64]$before = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                [BetterTitus.FastCleaner]::CleanPattern($item.Paths)
                                [int64]$after = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                if ($bitsWasRunning) { Start-Service -Name "bits" -ErrorAction SilentlyContinue }
                                if ($wuWasRunning) { Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue }
                                $freed = [math]::Max(0, ($before - $after))
                                $Sync.Results[$item.Id] = $after
                            }
                            "DO" {
                                [int64]$before = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
                                    Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
                                }
                                [BetterTitus.FastCleaner]::CleanPattern($item.Paths)
                                [int64]$after = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                $freed = [math]::Max(0, ($before - $after))
                                $Sync.Results[$item.Id] = $after
                            }
                            "THUMB" {
                                [int64]$before = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                $expProcs = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
                                if ($expProcs) {
                                    $expProcs | Stop-Process -Force -ErrorAction SilentlyContinue
                                    Start-Sleep -Milliseconds 800
                                }
                                [BetterTitus.FastCleaner]::CleanPattern($item.Paths)
                                [int64]$after = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                if (-not (Get-Process -Name "explorer" -ErrorAction SilentlyContinue)) {
                                    Start-Process "explorer.exe"
                                }
                                $freed = [math]::Max(0, ($before - $after))
                                $Sync.Results[$item.Id] = $after
                            }
                            "BIN" {
                                $binPats = Get-RecycleBinPatterns
                                [int64]$before = [BetterTitus.FastCleaner]::GetPatternSize($binPats)
                                $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
                                foreach ($d in $drives) {
                                    $letter = $d.DeviceID.TrimEnd(':')
                                    Clear-RecycleBin -DriveLetter $letter -Force -ErrorAction SilentlyContinue
                                }
                                [int64]$after = [BetterTitus.FastCleaner]::GetPatternSize($binPats)
                                $freed = [math]::Max(0, ($before - $after))
                                $Sync.Results[$item.Id] = $after
                            }
                            default {
                                [int64]$before = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                [BetterTitus.FastCleaner]::CleanPattern($item.Paths)
                                [int64]$after = [BetterTitus.FastCleaner]::GetPatternSize($item.Paths)
                                $freed = [math]::Max(0, ($before - $after))
                                $Sync.Results[$item.Id] = $after
                            }
                        }
                        $Sync.FreedBytes += $freed
                        Enqueue-Log "$($item.Label) -> Limpo ($(Fmt-Size $freed) efetivamente liberados)" "OK"
                    } catch {
                        Enqueue-Log "$($item.Label) -> Erro: $($_.Exception.Message)" "ERROR"
                    }
                }
            }
        } catch {
            $Sync.Logs.Enqueue(@{ Msg = "Erro fatal no worker de limpeza: $($_.Exception.Message)"; Lvl = "ERROR" })
        } finally {
            $Sync.Done = $true
        }
    }).AddArgument($JobType).AddArgument($WorkList).AddArgument($sync).AddArgument($script:CleanerDll)

    $asyncHandle = $ps.BeginInvoke()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(80)
    $timer.Tag = [PSCustomObject]@{
        Sync        = $sync
        JobType     = $JobType
        PS          = $ps
        AsyncHandle = $asyncHandle
    }

    $timer.Add_Tick({
        param($sender, $e)
        $ctx  = $sender.Tag
        $sync = $ctx.Sync

        $entry = $null
        while ($sync.Logs.TryDequeue([ref]$entry)) {
            Write-BTLog $entry.Msg $entry.Lvl
        }
        foreach ($kv in $sync.Results.GetEnumerator()) {
            $script:CleanScannedBytes[$kv.Key] = $kv.Value
        }
        Update-CleanSizeLabels

        if ($script:Lang -eq "PT") {
            $LblCleanTotalSize.Text = if ($ctx.JobType -eq "SCAN") { "Verificando... ($($sync.CurrentIdx)/$($sync.TotalCount))" } else { "Limpando... ($($sync.CurrentIdx)/$($sync.TotalCount))" }
        } else {
            $LblCleanTotalSize.Text = if ($ctx.JobType -eq "SCAN") { "Scanning... ($($sync.CurrentIdx)/$($sync.TotalCount))" } else { "Cleaning... ($($sync.CurrentIdx)/$($sync.TotalCount))" }
        }

        if ($sync.Done -or $ctx.AsyncHandle.IsCompleted) {
            $sender.Stop()
            try { $ctx.PS.EndInvoke($ctx.AsyncHandle) } catch {}
            $ctx.PS.Dispose()
            $script:CleanJobRunning = $false
            $BtnCleanScan.IsEnabled = $true
            $BtnCleanExecute.IsEnabled = $true
            Update-CleanSizeLabels

            if ($ctx.JobType -eq "SCAN") {
                Write-BTLog "=== VERIFICAÇÃO CONCLUÍDA: $(Format-ByteSize $sync.ScanBytes) DETECTADOS ===" "OK"
            } else {
                Write-BTLog "=== LIMPEZA PROFUNDA CONCLUÍDA | ESPAÇO EFETIVAMENTE LIBERADO: $(Format-ByteSize $sync.FreedBytes) ===" "OK"
            }
        }
    })
    $timer.Start()
}

$BtnCleanScan.Add_Click({
    Write-BTLog "=== INICIANDO VERIFICAÇÃO DE ESPAÇO (LIMPEZA PROFUNDA) ===" "HEADER"
    $payload = @()
    foreach ($it in $script:CleanItems) {
        $payload += [PSCustomObject]@{
            Id    = $it.Id
            Mode  = $it.Mode
            Paths = $it.Paths
            Label = ($it.Chk.Content.ToString() -replace '\s*\(\?\)$', '')
        }
    }
    Start-AsyncDeepCleanJob "SCAN" $payload
})

$BtnCleanExecute.Add_Click({
    $selected = @($script:CleanItems | Where-Object { $_.Chk.IsChecked -eq $true })
    if ($selected.Count -eq 0) {
        Write-BTLog "Nenhum item selecionado na Limpeza Profunda." "WARN"
        return
    }

    if ($ClnRestorePoints.IsChecked) {
        $rpMsg = if ($script:Lang -eq "PT") {
            "A opção 'Pontos de restauração do sistema' está marcada e apagará TODOS os pontos de restauração (incluindo os do Windows Update). Deseja continuar?"
        } else {
            "'System Restore Points' is checked and will delete ALL existing restore points (including Windows Update rollback points). Continue?"
        }
        if ([System.Windows.MessageBox]::Show($rpMsg, "BetterTitus - Deep Clean", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -ne [System.Windows.MessageBoxResult]::Yes) {
            return
        }
    }

    if ($ClnRecycleBin.IsChecked) {
        $binMsg = if ($script:Lang -eq "PT") {
            "A opção 'Estação de reciclagem' (Lixeira) está marcada e excluirá permanentemente os arquivos da Lixeira. Deseja continuar?"
        } else {
            "'Recycle Bin' is checked and will permanently delete all files in the Recycle Bin. Continue?"
        }
        if ([System.Windows.MessageBox]::Show($binMsg, "BetterTitus - Recycle Bin", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -ne [System.Windows.MessageBoxResult]::Yes) {
            return
        }
    }

    Write-BTLog "=== INICIANDO LIMPEZA PROFUNDA ($($selected.Count) ITENS) ===" "HEADER"
    $payload = @()
    foreach ($it in $selected) {
        $payload += [PSCustomObject]@{
            Id    = $it.Id
            Mode  = $it.Mode
            Paths = $it.Paths
            Label = ($it.Chk.Content.ToString() -replace '\s*\(\?\)$', '')
        }
    }
    Start-AsyncDeepCleanJob "CLEAN" $payload
})

# ==============================================================================
# LISTA DE JOGOS E WORKERS ISOLADOS
# ==============================================================================
$script:DefaultGames = @(
    [PSCustomObject]@{ Name = "VALORANT";         Exe = "VALORANT-Win64-Shipping.exe";       FullPath = ""; Custom = $false; Badge = "" },
    [PSCustomObject]@{ Name = "Counter-Strike 2"; Exe = "cs2.exe";                           FullPath = ""; Custom = $false; Badge = "" },
    [PSCustomObject]@{ Name = "Fortnite";         Exe = "FortniteClient-Win64-Shipping.exe"; FullPath = ""; Custom = $false; Badge = "" },
    [PSCustomObject]@{ Name = "Apex Legends";     Exe = "r5apex.exe";                        FullPath = ""; Custom = $false; Badge = "" },
    [PSCustomObject]@{ Name = "Overwatch 2";      Exe = "Overwatch.exe";                     FullPath = ""; Custom = $false; Badge = "" }
)

$script:GameList = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
foreach ($g in $script:DefaultGames) { $script:GameList.Add($g) }

if (Test-Path $script:GamesJson) {
    try {
        $saved = Get-Content $script:GamesJson -Raw | ConvertFrom-Json
        foreach ($sg in $saved) {
            if ($sg.Exe -and -not ($script:GameList | Where-Object { $_.Exe -ieq $sg.Exe })) {
                $script:GameList.Add([PSCustomObject]@{
                    Name     = $sg.Name
                    Exe      = $sg.Exe
                    FullPath = if ($sg.FullPath) { $sg.FullPath } else { "" }
                    Custom   = $true
                    Badge    = "CUSTOM"
                })
            }
        }
    } catch {}
}

$LstGames.ItemsSource = $script:GameList
if ($script:GameList.Count -gt 0) { $LstGames.SelectedIndex = 0 }

function Save-CustomGames {
    $customs = @($script:GameList | Where-Object { $_.Custom -eq $true } | Select-Object Name, Exe, FullPath)
    if ($customs.Count -gt 0) {
        $customs | ConvertTo-Json -Depth 2 | Set-Content -Path $script:GamesJson -Encoding UTF8
    } else {
        Remove-Item $script:GamesJson -Force -ErrorAction SilentlyContinue
    }
}

$script:SelectedBrowsePath = ""
$BtnBrowseExe.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "Executable Files (*.exe)|*.exe"
    if ($dlg.ShowDialog() -eq $true) {
        $script:SelectedBrowsePath = $dlg.FileName
        $TxtCustomGameExe.Text     = [System.IO.Path]::GetFileName($dlg.FileName)
        if ([string]::IsNullOrWhiteSpace($TxtCustomGameName.Text)) {
            $TxtCustomGameName.Text = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)
        }
    }
})

$BtnAddGame.Add_Click({
    $gName = $TxtCustomGameName.Text.Trim()
    $gExe  = $TxtCustomGameExe.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($gName) -or [string]::IsNullOrWhiteSpace($gExe)) {
        Write-BTLog "Informe o nome do jogo e selecione o executável (.exe)." "WARN"
        return
    }
    $gExe = [System.IO.Path]::GetFileName($gExe)
    if ($gExe -notmatch '^[a-zA-Z0-9_\-\.\x27\s]+\.exe$') {
        Write-BTLog "Nome de executável inválido: $gExe" "ERROR"
        return
    }
    if ($script:GameList | Where-Object { $_.Exe -ieq $gExe }) {
        Write-BTLog "O executável $gExe já está na lista." "WARN"
        return
    }

    $script:GameList.Add([PSCustomObject]@{
        Name     = $gName
        Exe      = $gExe
        FullPath = $script:SelectedBrowsePath
        Custom   = $true
        Badge    = "CUSTOM"
    })
    Save-CustomGames
    $LstGames.SelectedIndex = $script:GameList.Count - 1
    $TxtCustomGameName.Text = ""; $TxtCustomGameExe.Text = ""; $script:SelectedBrowsePath = ""
    Write-BTLog "Jogo personalizado adicionado: $gName." "OK"
})

$BtnRemoveGame.Add_Click({
    $idx = $LstGames.SelectedIndex
    if ($idx -lt 0 -or $idx -ge $script:GameList.Count) {
        Write-BTLog "Nenhum jogo selecionado para remover." "WARN"
        return
    }
    $sel = $script:GameList[$idx]
    if (-not $sel.Custom) {
        Write-BTLog "Jogos pré-configurados não podem ser removidos." "WARN"
        return
    }
    $id = Get-CleanId $sel.Exe
    @("BetterTitus_Affinity_$id", "BetterTitus_DX11Watch_$id", "BetterTitus_NvTel_$id") | ForEach-Object {
        Stop-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $_ -Confirm:$false -ErrorAction SilentlyContinue
    }
    Remove-Item "$script:ConfigDir\Affinity_$id.ps1", "$script:ConfigDir\DX11Watch_$id.ps1", "$script:ConfigDir\NvTel_$id.ps1" -Force -ErrorAction SilentlyContinue
    Restore-NvidiaBackupForGame $id
    Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\BetterTitus_$id" -Recurse -Force -ErrorAction SilentlyContinue

    $script:GameList.RemoveAt($idx)
    Save-CustomGames
    if ($script:GameList.Count -gt 0) { $LstGames.SelectedIndex = 0 }
    Write-BTLog "Jogo removido junto com suas tarefas: $($sel.Name)." "OK"
})

# ==============================================================================
# OTIMIZAÇÕES DE GAMING (DSCP 46, AFINIDADE BITWISE, DX11 0x211, NVIDIA ISOLADO)
# ==============================================================================
$script:loadingGameUI = $false

function Get-SelectedGameSafe {
    $idx = $LstGames.SelectedIndex
    if ($idx -lt 0 -or $idx -ge $script:GameList.Count) { return $null }
    return $script:GameList[$idx]
}

function Update-SelectedGameUI {
    $game = Get-SelectedGameSafe
    if ($null -eq $game) { return }
    $script:loadingGameUI = $true

    $exe  = $game.Exe
    $id   = Get-CleanId $exe
    $script:GameStateCache.Exe = $exe
    $script:GameStateCache.IsValorant = ($exe -ieq "VALORANT-Win64-Shipping.exe")

    $LblSelectedGameTitle.Text = $game.Name
    $LblSelectedGameExe.Text   = $exe

    $isDscpActive = ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\BetterTitus_$id" "DSCP Value" "") -eq "46")
    $script:GameStateCache.Dscp = $isDscpActive
    $TglGameDscp.IsChecked = $isDscpActive
    $StatusDscp.Foreground = if ($isDscpActive) { "#4ADE80" } else { "#9CA3AF" }

    $TglGameAffinity.IsEnabled = ($script:HwInfo.Threads -le 64)
    $isAffActive = ($script:HwInfo.Threads -le 64) -and (Test-ScheduledTaskSafe "\" "BetterTitus_Affinity_$id")
    $script:GameStateCache.Affinity = $isAffActive
    $TglGameAffinity.IsChecked = $isAffActive
    $StatusAffinity.Foreground = if ($script:HwInfo.Threads -gt 64) { "#F59E0B" } elseif ($isAffActive) { "#4ADE80" } else { "#9CA3AF" }

    $gcsChildren = Resolve-RegPath "HKCU:\System\GameConfigStore\Children"
    $dxFlagsVal = $null
    if (Test-Path $gcsChildren) {
        foreach ($sub in (Get-ChildItem $gcsChildren -ErrorAction SilentlyContinue)) {
            $mExe = (Get-ItemProperty $sub.PSPath -Name "MatchedExeFullPath" -ErrorAction SilentlyContinue).MatchedExeFullPath
            if ($mExe -and ($mExe -like "*\$exe" -or $mExe -ieq $exe)) {
                $dxFlagsVal = (Get-ItemProperty $sub.PSPath -Name "Flags" -ErrorAction SilentlyContinue).Flags
                break
            }
        }
    }
    $hasDxTask = Test-ScheduledTaskSafe "\" "BetterTitus_DX11Watch_$id"
    if ($dxFlagsVal -eq 0x211 -or $dxFlagsVal -eq 529) {
        $script:GameStateCache.Dx11State = "APPLIED"; $TglGameDx11.IsChecked = $true; $StatusDx11.Foreground = "#4ADE80"
    } elseif ($hasDxTask) {
        $script:GameStateCache.Dx11State = "WATCHING"; $TglGameDx11.IsChecked = $true; $StatusDx11.Foreground = "#A78BFA"
    } else {
        $script:GameStateCache.Dx11State = "NONE"; $TglGameDx11.IsChecked = $false; $StatusDx11.Foreground = "#9CA3AF"
    }

    $TglGameNvTel.IsEnabled = $script:HwInfo.HasNvidia
    $isNvActive = $script:HwInfo.HasNvidia -and (Test-ScheduledTaskSafe "\" "BetterTitus_NvTel_$id")
    $script:GameStateCache.NvTel = $isNvActive
    $TglGameNvTel.IsChecked = $isNvActive
    $StatusNvTel.Foreground = if (-not $script:HwInfo.HasNvidia) { "#F59E0B" } elseif ($isNvActive) { "#4ADE80" } else { "#9CA3AF" }

    Refresh-CachedStatusLabels
    $script:loadingGameUI = $false
}

$LstGames.Add_SelectionChanged({ Update-SelectedGameUI })

$TglGameDscp.Add_Checked({
    if ($script:loadingGameUI) { return }
    $game = Get-SelectedGameSafe; if ($null -eq $game) { return }
    $exe = $game.Exe; $id = Get-CleanId $exe
    $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\BetterTitus_$id"
    Invoke-SafeTweak "Priorizar Rota de Jogo ($exe)" {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\QoS" "Do not use NLA" "1" "String"
        Set-Reg $qosPath "Version" "1.0" "String"; Set-Reg $qosPath "Application Name" $exe "String"
        Set-Reg $qosPath "Protocol" "*" "String"; Set-Reg $qosPath "Local Port" "*" "String"
        Set-Reg $qosPath "Local IP" "*" "String"; Set-Reg $qosPath "Local IP Prefix Length" "*" "String"
        Set-Reg $qosPath "Remote Port" "*" "String"; Set-Reg $qosPath "Remote IP" "*" "String"
        Set-Reg $qosPath "Remote IP Prefix Length" "*" "String"; Set-Reg $qosPath "DSCP Value" "46" "String"
        Set-Reg $qosPath "Throttle Rate" "-1" "String"
    } { (Get-Reg $qosPath "DSCP Value" "") -eq "46" }
    Update-SelectedGameUI
})
$TglGameDscp.Add_Unchecked({
    if ($script:loadingGameUI) { return }
    $game = Get-SelectedGameSafe; if ($null -eq $game) { return }
    $id = Get-CleanId $game.Exe
    Invoke-SafeTweak "Remover Prioridade de Rota ($($game.Exe))" {
        Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\BetterTitus_$id" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Update-SelectedGameUI
})

$TglGameAffinity.Add_Checked({
    if ($script:loadingGameUI) { return }
    if ($script:HwInfo.Threads -gt 64) {
        Write-BTLog "Afinidade automática abortada: CPU possui $($script:HwInfo.Threads) threads (>64 utiliza Processor Groups)." "WARN"
        $script:loadingGameUI = $true; $TglGameAffinity.IsChecked = $false; $script:loadingGameUI = $false
        return
    }
    $game = Get-SelectedGameSafe; if ($null -eq $game) { return }
    $exe = $game.Exe; $procName = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    $id = Get-CleanId $exe; $taskName = "BetterTitus_Affinity_$id"
    $isVal = if ($exe -ieq "VALORANT-Win64-Shipping.exe") { '$true' } else { '$false' }

    # Escape seguro para nomes contendo apóstrofos (ex: game's.exe)
    $psSafeExe  = $exe.Replace("'", "''")
    $psSafeProc = $procName.Replace("'", "''")
    $wmiSafeExe = $exe.Replace("\", "\\").Replace("'", "\'")

    Invoke-SafeTweak "Prioridade Alta + Afinidade Bitwise ($exe)" {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        # Limpar eventuais chaves antigas IFEO PerfOptions obsoletas
        Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" -Recurse -Force -ErrorAction SilentlyContinue

        $scriptPath = "$script:ConfigDir\Affinity_$id.ps1"
        $workerCode = @"
`$exeName = '$psSafeExe'
`$procBase = '$psSafeProc'
`$isValorant = $isVal
`$logFile = '$script:ConfigDir\worker_affinity_$id.log'

function Optimize-RunningTarget {
    `$foundGame = `$false
    `$windowReady = `$false
    for (`$i = 0; `$i -lt 10; `$i++) {
        `$procs = @(Get-Process -Name `$procBase -ErrorAction SilentlyContinue)
        if (`$procs.Count -gt 0) {
            `$foundGame = `$true
            foreach (`$p in `$procs) {
                try {
                    `$curMask = `$p.ProcessorAffinity.ToInt64()
                    `$newMask = `$curMask -band (-bnot 1L)
                    if (`$newMask -gt 0 -and `$curMask -ne `$newMask) { `$p.ProcessorAffinity = [IntPtr]`$newMask }
                    if (`$p.PriorityClass -ne 'High') { `$p.PriorityClass = 'High' }
                    if (`$p.MainWindowHandle -ne [IntPtr]::Zero) { `$windowReady = `$true }
                } catch {}
            }
        }
        if (`$windowReady) { break }
        Start-Sleep -Milliseconds 1500
    }
    if (`$isValorant -and `$foundGame -and `$windowReady) {
        Get-Process -Name 'RiotClientServices' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

Optimize-RunningTarget
Unregister-Event -SourceIdentifier 'BT_ProcWatch_$id' -ErrorAction SilentlyContinue
Register-WmiEvent -Query "SELECT * FROM __InstanceCreationEvent WITHIN 2 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = '$wmiSafeExe'" -SourceIdentifier 'BT_ProcWatch_$id' -ErrorAction SilentlyContinue

while (`$true) {
    try {
        `$evt = Wait-Event -SourceIdentifier 'BT_ProcWatch_$id' -Timeout 60
        if (`$evt) {
            Remove-Event -EventIdentifier `$evt.EventIdentifier -ErrorAction SilentlyContinue
            Optimize-RunningTarget
        } else {
            if (Get-Process -Name `$procBase -ErrorAction SilentlyContinue) {
                Optimize-RunningTarget
            }
        }
    } catch {
        "`$(Get-Date -Format o) [ERROR] `$(`$_.Exception.Message)" | Out-File -FilePath `$logFile -Append -Encoding UTF8
        Start-Sleep -Seconds 5
    }
}
"@
        Set-Content -Path $scriptPath -Value $workerCode -Encoding UTF8 -Force
        $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
        $trigger   = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    } { (Test-ScheduledTaskSafe "\" $taskName) }
    Update-SelectedGameUI
})

$TglGameAffinity.Add_Unchecked({
    if ($script:loadingGameUI) { return }
    $game = Get-SelectedGameSafe; if ($null -eq $game) { return }
    $exe = $game.Exe; $procName = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    $id = Get-CleanId $exe; $taskName = "BetterTitus_Affinity_$id"
    Invoke-SafeTweak "Desativar Afinidade ($exe)" {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item "$script:ConfigDir\Affinity_$id.ps1" -Force -ErrorAction SilentlyContinue
        Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $restoredMask = $_.ProcessorAffinity.ToInt64() -bor 1L
                $_.ProcessorAffinity = [IntPtr]$restoredMask
                $_.PriorityClass = 'Normal'
            } catch {}
        }
    }
    Update-SelectedGameUI
})

$TglGameDx11.Add_Checked({
    if ($script:loadingGameUI) { return }
    $game = Get-SelectedGameSafe; if ($null -eq $game) { return }
    $exe = $game.Exe; $id = Get-CleanId $exe; $dxTaskName = "BetterTitus_DX11Watch_$id"
    $children = Resolve-RegPath "HKCU:\System\GameConfigStore\Children"
    $psSafeExe = $exe.Replace("'", "''")

    Invoke-SafeTweak "Remover Latência de Tela Cheia ($exe)" {
        $found = $false
        if (Test-Path $children) {
            foreach ($sub in (Get-ChildItem $children -ErrorAction SilentlyContinue)) {
                $mExe = (Get-ItemProperty $sub.PSPath -Name "MatchedExeFullPath" -ErrorAction SilentlyContinue).MatchedExeFullPath
                if ($mExe -and ($mExe -like "*\$exe" -or $mExe -ieq $exe)) {
                    Set-ItemProperty -Path $sub.PSPath -Name "Flags" -Value 0x211 -Type DWord -Force -ErrorAction Stop
                    $found = $true
                }
            }
        }
        if (-not $found) {
            $watchScript = "$script:ConfigDir\DX11Watch_$id.ps1"
            $watchCode = @"
`$children = '$children'
`$targetExe = '$psSafeExe'
if (Test-Path `$children) {
    foreach (`$sub in (Get-ChildItem `$children -ErrorAction SilentlyContinue)) {
        `$mExe = (Get-ItemProperty `$sub.PSPath -Name 'MatchedExeFullPath' -ErrorAction SilentlyContinue).MatchedExeFullPath
        if (`$mExe -and (`$mExe -like "*\`$targetExe" -or `$mExe -ieq `$targetExe)) {
            Set-ItemProperty -Path `$sub.PSPath -Name 'Flags' -Value 0x211 -Type DWord -Force
            Unregister-ScheduledTask -TaskName '$dxTaskName' -Confirm:`$false -ErrorAction SilentlyContinue
            Remove-Item '$watchScript' -Force -ErrorAction SilentlyContinue
            break
        }
    }
}
"@
            Set-Content -Path $watchScript -Value $watchCode -Encoding UTF8 -Force
            $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watchScript`""
            $trigger   = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 30)
            $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
            Register-ScheduledTask -TaskName $dxTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        }
    }
    Update-SelectedGameUI
})

$TglGameDx11.Add_Unchecked({
    if ($script:loadingGameUI) { return }
    $game = Get-SelectedGameSafe; if ($null -eq $game) { return }
    $exe = $game.Exe; $id = Get-CleanId $exe; $dxTaskName = "BetterTitus_DX11Watch_$id"
    Invoke-SafeTweak "Reverter Latência Tela Cheia ($exe)" {
        Stop-ScheduledTask -TaskName $dxTaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $dxTaskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item "$script:ConfigDir\DX11Watch_$id.ps1" -Force -ErrorAction SilentlyContinue
        $children = Resolve-RegPath "HKCU:\System\GameConfigStore\Children"
        if (Test-Path $children) {
            foreach ($sub in (Get-ChildItem $children -ErrorAction SilentlyContinue)) {
                $mExe = (Get-ItemProperty $sub.PSPath -Name "MatchedExeFullPath" -ErrorAction SilentlyContinue).MatchedExeFullPath
                if ($mExe -and ($mExe -like "*\$exe" -or $mExe -ieq $exe)) {
                    Set-ItemProperty -Path $sub.PSPath -Name "Flags" -Value 0x11 -Type DWord -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    Update-SelectedGameUI
})

$TglGameNvTel.Add_Checked({
    if ($script:loadingGameUI) { return }
    $game = Get-SelectedGameSafe; if ($null -eq $game) { return }
    $exe = $game.Exe; $procName = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    $id = Get-CleanId $exe; $nvTaskName = "BetterTitus_NvTel_$id"
    $gameNvBkp = "$script:ConfigDir\nv_backup_$id.json"

    $psSafeExe  = $exe.Replace("'", "''")
    $psSafeProc = $procName.Replace("'", "''")
    $wmiSafeExe = $exe.Replace("\", "\\").Replace("'", "\'")

    $msg = if ($script:Lang -eq "PT") {
        "Aviso de Funcionalidade:`n`nEnquanto $($game.Name) estiver aberto, os serviços NVDisplay.ContainerLocalSystem e NvContainerLocalSystem serão pausados.`n`nIsso pausa temporariamente o NVIDIA Overlay (ShadowPlay) e o Painel de Controle NVIDIA durante a partida. Ao fechar o jogo (ou reiniciar em caso de crash), o estado original exato será restaurado sem interferir em outros jogos.`n`nDeseja ativar para $($game.Name)?"
    } else {
        "Feature Notice:`n`nWhile $($game.Name) is running, NVDisplay.ContainerLocalSystem and NvContainerLocalSystem will be temporarily paused.`n`nThis temporarily pauses NVIDIA Overlay (ShadowPlay) and NVIDIA Control Panel in-game. Upon closing the game (or after any unexpected crash/reboot), each service's exact original configuration is restored per-game.`n`nEnable for $($game.Name)?"
    }
    $res = [System.Windows.MessageBox]::Show($msg, "BetterTitus - NVIDIA Telemetry", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Information)
    if ($res -ne [System.Windows.MessageBoxResult]::Yes) {
        $script:loadingGameUI = $true; $TglGameNvTel.IsChecked = $false; $script:loadingGameUI = $false
        return
    }

    Invoke-SafeTweak "Desativar Telemetria NVIDIA ($exe)" {
        Stop-ScheduledTask -TaskName $nvTaskName -ErrorAction SilentlyContinue
        $scriptPath = "$script:ConfigDir\NvTel_$id.ps1"
        $nvCode = @"
`$exeName  = '$psSafeExe'
`$procBase = '$psSafeProc'
`$bkpFile  = '$gameNvBkp'
`$logFile  = '$script:ConfigDir\worker_nvtel_$id.log'
`$nvSvcs   = @('NVDisplay.ContainerLocalSystem', 'NvContainerLocalSystem')

function Restore-NvOriginalState {
    if (Test-Path `$bkpFile) {
        try {
            `$saved = Get-Content `$bkpFile -Raw | ConvertFrom-Json
            foreach (`$item in `$saved) {
                `$sName = `$item.Name.ToString()
                if (`$sName -notin `$nvSvcs) { continue }
                `$st = [int]`$item.Start
                if (`$st -notin @(2,3,4)) { `$st = 2 }
                `$reg = "HKLM:\SYSTEM\CurrentControlSet\Services\`$sName"
                if (Test-Path `$reg) {
                    Set-ItemProperty -Path `$reg -Name 'Start' -Value `$st -Type DWord -Force -ErrorAction SilentlyContinue
                    `$wasRun = (`$item.WasRunning -is [bool] -and `$item.WasRunning) -or (`$item.WasRunning.ToString() -ieq 'true')
                    if (`$wasRun) { Start-Service -Name `$sName -ErrorAction SilentlyContinue }
                }
            }
            Remove-Item `$bkpFile -Force -ErrorAction SilentlyContinue
        } catch {}
    }
}

function Pause-NvDuringGame {
    if (-not (Test-Path `$bkpFile)) {
        `$snapshot = @()
        foreach (`$s in `$nvSvcs) {
            `$reg = "HKLM:\SYSTEM\CurrentControlSet\Services\`$s"
            if (Test-Path `$reg) {
                `$startVal = [int](Get-ItemProperty -Path `$reg -Name 'Start' -ErrorAction SilentlyContinue).Start
                if (`$startVal -notin @(2,3,4)) { `$startVal = 2 }
                `$svcObj   = Get-Service -Name `$s -ErrorAction SilentlyContinue
                `$snapshot += [PSCustomObject]@{ Name = `$s; Start = `$startVal; WasRunning = (`$null -ne `$svcObj -and `$svcObj.Status -eq 'Running') }
            }
        }
        if (`$snapshot.Count -gt 0) {
            `$snapshot | ConvertTo-Json -Depth 2 | Set-Content -Path `$bkpFile -Encoding UTF8 -Force
        }
    }
    foreach (`$s in `$nvSvcs) {
        `$reg = "HKLM:\SYSTEM\CurrentControlSet\Services\`$s"
        if (Test-Path `$reg) {
            Set-ItemProperty -Path `$reg -Name 'Start' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
            Stop-Service -Name `$s -ErrorAction SilentlyContinue
        }
    }
}

if (-not (Get-Process -Name `$procBase -ErrorAction SilentlyContinue)) {
    Restore-NvOriginalState
}

try {
    Unregister-Event -SourceIdentifier 'BT_NvWatch_$id' -ErrorAction SilentlyContinue
    Register-WmiEvent -Query "SELECT * FROM __InstanceCreationEvent WITHIN 3 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = '$wmiSafeExe'" -SourceIdentifier 'BT_NvWatch_$id' -ErrorAction SilentlyContinue

    while (`$true) {
        try {
            if (-not (Get-Process -Name `$procBase -ErrorAction SilentlyContinue)) {
                `$evt = Wait-Event -SourceIdentifier 'BT_NvWatch_$id' -Timeout 60
                if (`$evt) { Remove-Event -EventIdentifier `$evt.EventIdentifier -ErrorAction SilentlyContinue }
            }
            if (Get-Process -Name `$procBase -ErrorAction SilentlyContinue) {
                Pause-NvDuringGame
                while (Get-Process -Name `$procBase -ErrorAction SilentlyContinue) {
                    Start-Sleep -Seconds 3
                }
                Restore-NvOriginalState
            }
        } catch {
            "`$(Get-Date -Format o) [ERROR] `$(`$_.Exception.Message)" | Out-File -FilePath `$logFile -Append -Encoding UTF8
            Start-Sleep -Seconds 5
        }
    }
} finally {
    Restore-NvOriginalState
}
"@
        Set-Content -Path $scriptPath -Value $nvCode -Encoding UTF8 -Force
        $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
        $trigger   = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $nvTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskName $nvTaskName -ErrorAction SilentlyContinue
    } { Test-ScheduledTaskSafe "\" $nvTaskName }
    Update-SelectedGameUI
})

$TglGameNvTel.Add_Unchecked({
    if ($script:loadingGameUI) { return }
    $game = Get-SelectedGameSafe; if ($null -eq $game) { return }
    $exe = $game.Exe; $id = Get-CleanId $exe; $nvTaskName = "BetterTitus_NvTel_$id"
    Invoke-SafeTweak "Desativar Gerenciamento NVIDIA ($exe)" {
        Stop-ScheduledTask -TaskName $nvTaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $nvTaskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item "$script:ConfigDir\NvTel_$id.ps1" -Force -ErrorAction SilentlyContinue
        Restore-NvidiaBackupForGame $id
    }
    Update-SelectedGameUI
})

# ==============================================================================
# DETECÇÃO ASSÍNCRONA DO SISTEMA (ZERO CONGELAMENTO NA UI)
# ==============================================================================
$script:loadingState = $false
$script:AppliedSecurityCache = @{ BitLocker = $false; HVCI = $false; Mitigations = $false }
$script:InitialTweakState = @{}

$SafeLeftChecks = @(
    $ChkActivity, $ChkConsumer, $ChkDelivery, $ChkEndTask, $ChkFolderDisc,
    $ChkHibernation, $ChkLocation, $ChkMemCompression, $ChkStoreSearch, $ChkDeviceCompanion,
    $ChkServicesMan, $ChkTelemetry, $ChkWidgets, $ChkWPBT, $ChkSearchIdx, $ChkBgApps,
    $ChkOptTasks, $ChkReservedStorage, $ChkExplorerGallery, $ChkGameDVR, $ChkIPv4Pref,
    $ChkTeredo, $ChkMenuDelay, $ChkEdgeDebloat, $ChkNetThrottle, $ChkPowerThrottle,
    $ChkClassicContext, $ChkStorageSense, $ChkSvcHost, $ChkUsbSuspend, $ChkBestPerf, $ChkWinAI
)
$AllLeftChecks = $SafeLeftChecks + @($ChkBitLocker, $ChkHVCI, $ChkCpuMitigations)

$ChkHibernation.Add_Checked({
    if (-not $script:loadingState -and $TglFastStart.IsChecked) {
        $TglFastStart.IsChecked = $false
        $TglFastStart.IsEnabled = $false
        Write-BTLog "Fast Startup desativado e bloqueado automaticamente pois requer Hibernação (hiberfil.sys)." "INFO"
    }
})
$ChkHibernation.Add_Unchecked({
    if (-not $script:loadingState) {
        $TglFastStart.IsEnabled = $true
    }
})

$script:SyncRunning = $false
function Sync-SystemStateAsync ([scriptblock]$OnComplete = $null) {
    if ($script:SyncRunning) { return }
    $script:SyncRunning = $true
    $BtnSelectInstalled.IsEnabled = $false

    Refresh-NvidiaPresence

    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
        param($UserRegRoot, $SafeManualServices, $RamKB, $SysDrive)

        function RPath([string]$p) {
            if ($p -like "HKCU:\*") { return ($UserRegRoot + "\" + $p.Substring(6)) }
            return $p
        }
        function RGet([string]$p, [string]$n, $def = $null) {
            try {
                $rp = RPath $p
                if (Test-Path $rp) {
                    $o = Get-ItemProperty -Path $rp -Name $n -ErrorAction SilentlyContinue
                    if ($null -ne $o) {
                        $pi = $o.PSObject.Properties[$n]
                        if ($null -ne $pi -and $null -ne $pi.Value) { return $pi.Value }
                    }
                }
            } catch {}
            return $def
        }
        function SvcStart([string]$s) { return (RGet "HKLM:\SYSTEM\CurrentControlSet\Services\$s" "Start" -1) }

        $memCompDisabled = $false
        if (Get-Command Get-MMAgent -ErrorAction SilentlyContinue) {
            try { $memCompDisabled = ((Get-MMAgent -ErrorAction SilentlyContinue).MemoryCompression -eq $false) } catch {}
        }

        $manualCount = 0; $existingCount = 0
        foreach ($svc in $SafeManualServices) {
            $st = SvcStart $svc
            if ($st -ne -1) { $existingCount++; if ($st -ge 3) { $manualCount++ } }
        }

        $ceipTask = Get-ScheduledTask -TaskPath "\Microsoft\Windows\Application Experience\" -TaskName "Microsoft Compatibility Appraiser" -ErrorAction SilentlyContinue

        $blOff = $false
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            try {
                $blVol = Get-BitLockerVolume -MountPoint $SysDrive -ErrorAction SilentlyContinue
                if ($null -ne $blVol -and $blVol.ProtectionStatus -eq 'Off' -and $blVol.VolumeStatus -eq 'FullyDecrypted') { $blOff = $true }
            } catch {}
        } else {
            $blOff = ((SvcStart "BDESVC") -eq 4)
        }

        $hibOff = ((RGet "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 1) -eq 0)
        $netThr = RGet "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 10
        $mpoDwm = RGet "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 0
        $mpoLeg = RGet "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DisableOverlays" 0

        return @{
            ChkActivity        = ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 1) -eq 0)
            ChkConsumer        = ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 0) -eq 1)
            ChkDelivery        = (((RGet "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 1) -eq 0) -or ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 1) -eq 0))
            ChkEndTask         = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask" 0) -eq 1)
            ChkFolderDisc      = ((RGet "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" "FolderType" "") -eq "NotSpecified")
            ChkHibernation     = $hibOff
            ChkLocation        = ((RGet "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Allow") -eq "Deny")
            ChkMemCompression  = $memCompDisabled
            ChkStoreSearch     = ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 0) -eq 1)
            ChkDeviceCompanion = ((RGet "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 0) -eq 1)
            ChkServicesMan     = ($existingCount -gt 0 -and ($manualCount -ge ([math]::Ceiling($existingCount * 0.7))))
            ChkTelemetry       = (((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1) -eq 0) -or ((SvcStart "DiagTrack") -eq 4))
            ChkWidgets         = (((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 1) -eq 0) -or ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 1) -eq 0))
            ChkWPBT            = ((RGet "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 0) -eq 1)
            ChkSearchIdx       = ((SvcStart "WSearch") -eq 4)
            ChkBgApps          = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 0) -eq 1)
            ChkOptTasks        = ($null -ne $ceipTask -and $ceipTask.State -eq 'Disabled')
            ChkReservedStorage = ((RGet "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "ShippedWithReserves" 1) -eq 0)
            ChkExplorerGallery = ((RGet "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 1) -eq 0)
            ChkGameDVR         = (((RGet "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 1) -eq 0) -or ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 1) -eq 0))
            ChkIPv4Pref        = ((RGet "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" 0) -eq 32)
            ChkTeredo          = ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" "Teredo_State" "") -eq "Disabled")
            ChkMenuDelay       = ((RGet "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400").ToString() -eq "0")
            ChkEdgeDebloat     = ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled" 1) -eq 0)
            ChkNetThrottle     = ($netThr -eq -1 -or $netThr -eq 0xffffffff -or $netThr -eq 4294967295)
            ChkPowerThrottle   = ((RGet "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 0) -eq 1)
            ChkClassicContext  = (Test-Path (RPath "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"))
            ChkStorageSense    = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 1) -eq 0)
            ChkSvcHost         = ($RamKB -gt 0 -and ([int64](RGet "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB" 3670016) -ge ($RamKB - 4096)))
            ChkUsbSuspend      = ((RGet "HKLM:\SYSTEM\CurrentControlSet\Services\USB" "DisableSelectiveSuspend" 0) -eq 1)
            ChkBestPerf        = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 0) -eq 2)
            ChkWinAI           = (((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 0) -eq 1) -or ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 0) -eq 1))
            ChkBitLocker       = $blOff
            ChkHVCI            = ((RGet "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1) -eq 0)
            ChkCpuMitigations  = (((RGet "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 0) -eq 3) -and ((RGet "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 0) -eq 3))

            TglBsod            = ((RGet "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 0) -eq 1)
            TglDarkWin         = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 1) -eq 0)
            TglLongPaths       = ((RGet "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 0) -eq 1)
            TglFastStart       = (-not $hibOff) -and ((RGet "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 1) -eq 1)
            TglFileExt         = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1) -eq 0)
            TglHiddenFiles     = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2) -eq 1)
            TglGameMode        = ((RGet "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1) -eq 1)
            TglAcrylic         = ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableAcrylicBackgroundOnLogon" 0) -eq 0)
            TglVerboseLogon    = ((RGet "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "VerboseStatus" 0) -eq 1)
            TglMouseAccel      = ((RGet "HKCU:\Control Panel\Mouse" "MouseSpeed" "1").ToString() -ne "0")
            TglMmProfile       = ((RGet "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 2) -eq 8)
            TglNumLock         = ((RGet "Registry::HKU\.DEFAULT\Control Panel\Keyboard" "InitialKeyboardIndicators" "0").ToString() -in @("2", "2147483650"))
            TglBingSearch      = (((RGet "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 0) -eq 0) -and ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 1) -ne 0))
            TglStartRecs       = ((RGet "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 0) -eq 0)
            TglStickyKeys      = ((RGet "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "510").ToString() -ne "506")
            TglCenterTaskbar   = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 1) -eq 1)
            TglSearchIcon      = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1) -ne 0)
            TglTaskView        = ((RGet "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 1) -eq 1)
            TglSnap            = ((RGet "HKCU:\Control Panel\Desktop" "WindowArrangementActive" "1").ToString() -eq "1")
            MpoIndex           = if ($mpoDwm -eq 5 -or $mpoLeg -eq 1) { 1 } else { 0 }
            WinUpdateDisabled  = ((SvcStart "wuauserv") -eq 4)
        }
    }).AddArgument($script:UserCtx.RegRoot).AddArgument($script:SafeManualServices).AddArgument($script:HwInfo.RamKB).AddArgument($env:SystemDrive)

    $handle = $ps.BeginInvoke()
    $syncTimer = New-Object System.Windows.Threading.DispatcherTimer
    $syncTimer.Interval = [TimeSpan]::FromMilliseconds(40)
    $syncTimer.Tag = [PSCustomObject]@{ PS = $ps; Handle = $handle; Callback = $OnComplete }

    $syncTimer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        if ($ctx.Handle.IsCompleted) {
            $sender.Stop()
            try {
                $resCollection = $ctx.PS.EndInvoke($ctx.Handle)
                $st = $resCollection[0]
                if ($null -ne $st) {
                    $script:loadingState = $true
                    foreach ($chk in $AllLeftChecks) {
                        if ($st.ContainsKey($chk.Name)) { $chk.IsChecked = [bool]$st[$chk.Name] }
                    }
                    $TglFastStart.IsEnabled = (-not [bool]$st["ChkHibernation"])

                    if ($script:HwInfo.RamKB -le 0) {
                        $ChkSvcHost.IsEnabled = $false
                        $ChkSvcHost.IsChecked = $false
                        Write-BTLog "Aviso: RAM física não detectada via WMI; ajuste de SvcHostSplitThreshold desabilitado." "WARN"
                    }

                    $script:AppliedSecurityCache.BitLocker   = [bool]$st["ChkBitLocker"]
                    $script:AppliedSecurityCache.HVCI        = [bool]$st["ChkHVCI"]
                    $script:AppliedSecurityCache.Mitigations = [bool]$st["ChkCpuMitigations"]

                    $script:InitialTweakState = @{}
                    foreach ($chk in $AllLeftChecks) {
                        $script:InitialTweakState[$chk.Name] = [bool]$chk.IsChecked
                    }

                    foreach ($tglName in @(
                        "TglBsod","TglDarkWin","TglLongPaths","TglFastStart","TglFileExt","TglHiddenFiles",
                        "TglGameMode","TglAcrylic","TglVerboseLogon","TglMouseAccel","TglMmProfile","TglNumLock",
                        "TglBingSearch","TglStartRecs","TglStickyKeys","TglCenterTaskbar","TglSearchIcon","TglTaskView","TglSnap"
                    )) {
                        $ctrl = Get-Variable -Name $tglName -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                        if ($null -ne $ctrl -and $st.ContainsKey($tglName)) { $ctrl.IsChecked = [bool]$st[$tglName] }
                    }
                    $CmbMPO.SelectedIndex = [int]$st["MpoIndex"]

                    $script:WinUpdateDisabledCache = [bool]$st["WinUpdateDisabled"]
                    $StatusWinUpdateCard.Foreground = if ($script:WinUpdateDisabledCache) { "#F87171" } else { "#4ADE80" }
                    Refresh-CachedStatusLabels
                    $script:loadingState = $false
                }
            } catch {
                Write-BTLog "Erro ao sincronizar estado do sistema: $($_.Exception.Message)" "ERROR"
                $script:loadingState = $false
            } finally {
                $ctx.PS.Dispose()
                $script:SyncRunning = $false
                $BtnSelectInstalled.IsEnabled = $true
                if ($null -ne $ctx.Callback) { & $ctx.Callback }
            }
        }
    })
    $syncTimer.Start()
}

# ==============================================================================
# INTERRUPTORES EM TEMPO REAL (COM BACKUP DE ESTADO ORIGINAL)
# ==============================================================================
$TglBsod.Add_Checked({
    if (-not $script:loadingState) {
        Invoke-SafeTweak "BSoD Verbose + No AutoReboot -> ON" {
            if (-not (Test-Path $script:CrashBackup)) {
                $curAuto = Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "AutoReboot" 1
                $curDisp = Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 0
                [PSCustomObject]@{ AutoReboot = [int]$curAuto; DisplayParameters = [int]$curDisp } | ConvertTo-Json | Set-Content -Path $script:CrashBackup -Encoding UTF8 -Force
            }
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 1
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "AutoReboot" 0
        }
    }
})
$TglBsod.Add_Unchecked({
    if (-not $script:loadingState) {
        Invoke-SafeTweak "BSoD Verbose -> Restaurar Original" {
            $origAuto = 1; $origDisp = 0
            if (Test-Path $script:CrashBackup) {
                try {
                    $bkp = Get-Content $script:CrashBackup -Raw | ConvertFrom-Json
                    $origAuto = [int]$bkp.AutoReboot
                    $origDisp = [int]$bkp.DisplayParameters
                } catch {}
                Remove-Item $script:CrashBackup -Force -ErrorAction SilentlyContinue
            }
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" $origDisp
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "AutoReboot" $origAuto
        }
    }
})

$TglDarkWin.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Dark Theme -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0; [BetterTitus.NativeMethods]::BroadcastSettingsChange() } } })
$TglDarkWin.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Dark Theme -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 1; [BetterTitus.NativeMethods]::BroadcastSettingsChange() } } })

$TglLongPaths.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Long Paths -> ON"  { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1 } } })
$TglLongPaths.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Long Paths -> OFF" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 0 } } })

$TglFastStart.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Fast Startup -> ON"  { powercfg.exe /hibernate on; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 1 } } })
$TglFastStart.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Fast Startup -> OFF" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0 } } })

$TglFileExt.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "File Extensions -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0; [BetterTitus.NativeMethods]::BroadcastSettingsChange() } } })
$TglFileExt.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "File Extensions -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1; [BetterTitus.NativeMethods]::BroadcastSettingsChange() } } })

$TglHiddenFiles.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Hidden Files -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1; [BetterTitus.NativeMethods]::BroadcastSettingsChange() } } })
$TglHiddenFiles.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Hidden Files -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2; [BetterTitus.NativeMethods]::BroadcastSettingsChange() } } })

$TglGameMode.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Game Mode -> ON"  { Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1 } } })
$TglGameMode.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Game Mode -> OFF" { Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 0 } } })

$TglAcrylic.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Logon Acrylic Blur -> ON"  { Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableAcrylicBackgroundOnLogon" } } })
$TglAcrylic.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Logon Acrylic Blur -> OFF" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableAcrylicBackgroundOnLogon" 1 } } })

$TglVerboseLogon.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Verbose Logon -> ON"  { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "VerboseStatus" 1 } } })
$TglVerboseLogon.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Verbose Logon -> OFF" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "VerboseStatus" 0 } } })

$TglMouseAccel.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Mouse Acceleration -> ON"  { Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "1" "String"; Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "6" "String"; Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "10" "String"; [BetterTitus.NativeMethods]::SetMouseAccel($true) } } })
$TglMouseAccel.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Mouse Acceleration -> OFF (1:1)" { Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"; Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"; Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"; [BetterTitus.NativeMethods]::SetMouseAccel($false) } } })

$TglMmProfile.Add_Checked({
    if (-not $script:loadingState) {
        Invoke-SafeTweak "Multimedia Gaming Profile -> ON" {
            $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            if (-not (Test-Path $script:MmBackup)) {
                [PSCustomObject]@{
                    GpuPriority        = [int](Get-Reg $mmPath "GPU Priority" 2)
                    Priority           = [int](Get-Reg $mmPath "Priority" 2)
                    SchedulingCategory = (Get-Reg $mmPath "Scheduling Category" "Medium").ToString()
                } | ConvertTo-Json | Set-Content -Path $script:MmBackup -Encoding UTF8 -Force
            }
            Set-Reg $mmPath "GPU Priority" 8
            Set-Reg $mmPath "Priority" 6
            Set-Reg $mmPath "Scheduling Category" "High" "String"
        }
    }
})
$TglMmProfile.Add_Unchecked({
    if (-not $script:loadingState) {
        Invoke-SafeTweak "Multimedia Gaming Profile -> Restaurar Original" {
            $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            $gpuP = 2; $prio = 2; $sched = "Medium"
            if (Test-Path $script:MmBackup) {
                try {
                    $bkp = Get-Content $script:MmBackup -Raw | ConvertFrom-Json
                    $gpuP  = [int]$bkp.GpuPriority
                    $prio  = [int]$bkp.Priority
                    $sched = $bkp.SchedulingCategory.ToString()
                } catch {}
                Remove-Item $script:MmBackup -Force -ErrorAction SilentlyContinue
            }
            Set-Reg $mmPath "GPU Priority" $gpuP
            Set-Reg $mmPath "Priority" $prio
            Set-Reg $mmPath "Scheduling Category" $sched "String"
        }
    }
})

$TglNumLock.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "NumLock on Startup -> ON"  { Set-Reg "Registry::HKU\.DEFAULT\Control Panel\Keyboard" "InitialKeyboardIndicators" "2" "String" } } })
$TglNumLock.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "NumLock on Startup -> OFF" { Set-Reg "Registry::HKU\.DEFAULT\Control Panel\Keyboard" "InitialKeyboardIndicators" "0" "String" } } })

$TglBingSearch.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Start Menu Bing Search -> ON"  { Remove-RegValueSafe "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions"; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 1 } } })
$TglBingSearch.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Start Menu Bing Search -> OFF" { Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0 } } })

$TglStartRecs.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Start Recommendations -> ON"  { Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" } } })
$TglStartRecs.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Start Recommendations -> OFF" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 1 } } })

$TglStickyKeys.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Sticky Keys -> ON"  { Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "510" "String" } } })
$TglStickyKeys.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Sticky Keys -> OFF" { Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" "String" } } })

$TglCenterTaskbar.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Taskbar Centered Icons -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 1; [BetterTitus.NativeMethods]::BroadcastSettingsChange() } } })
$TglCenterTaskbar.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Taskbar Centered Icons -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0; [BetterTitus.NativeMethods]::BroadcastSettingsChange() } } })

$TglSearchIcon.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Taskbar Search Icon -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1 } } })
$TglSearchIcon.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Taskbar Search Icon -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0 } } })

$TglTaskView.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Task View Icon -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 1 } } })
$TglTaskView.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Task View Icon -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0 } } })

$TglSnap.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Window Snapping -> ON"  { Set-Reg "HKCU:\Control Panel\Desktop" "WindowArrangementActive" "1" "String" } } })
$TglSnap.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Window Snapping -> OFF" { Set-Reg "HKCU:\Control Panel\Desktop" "WindowArrangementActive" "0" "String" } } })

$CmbMPO.Add_SelectionChanged({
    if (-not $script:loadingState) {
        if ($CmbMPO.SelectedIndex -eq 1) {
            Invoke-SafeTweak "Multiplane Overlay (MPO) -> Disabled" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 }
        } else {
            Invoke-SafeTweak "Multiplane Overlay (MPO) -> Enabled (Default)" {
                Remove-RegValueSafe "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode"
                Remove-RegValueSafe "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DisableOverlays"
            }
        }
    }
})

# Planos de Energia
$BtnUltEnable.Add_Click({
    Invoke-SafeTweak "Plano Desempenho Máximo (Ultimate)" {
        $curScheme = (powercfg /getactivescheme)
        if ($curScheme -match '([a-fA-F0-9\-]{36})' -and -not (Test-Path $script:PowerBackup)) {
            $matches[1] | Set-Content -Path $script:PowerBackup -Encoding UTF8 -Force
        }
        $existingGuid = (powercfg /list | Select-String "Ultimate Performance|Desempenho M" | ForEach-Object { if ($_.ToString() -match '([a-fA-F0-9\-]{36})') { $matches[1] } } | Select-Object -First 1)
        if (-not $existingGuid) {
            $dup = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
            if ($dup -match '([a-fA-F0-9\-]{36})') { $existingGuid = $matches[1] }
        }
        if ($existingGuid) {
            powercfg /setactive $existingGuid | Out-Null
        } else {
            throw "O plano Ultimate Performance não está disponível nesta edição/SKU do Windows ($($script:HwInfo.OsSku)) ou Modern Standby (S0)."
        }
    }
})

$BtnUltDisable.Add_Click({
    Invoke-SafeTweak "Restaurar Plano de Energia Anterior / Equilibrado" {
        $targetGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
        if (Test-Path $script:PowerBackup) {
            $savedGuid = (Get-Content $script:PowerBackup -Raw).Trim()
            if ($savedGuid -match '^[a-fA-F0-9\-]{36}$') { $targetGuid = $savedGuid }
            Remove-Item $script:PowerBackup -Force -ErrorAction SilentlyContinue
        }
        powercfg /setactive $targetGuid | Out-Null
    }
})

# Aba Advanced (Windows Update com Backup + WaaSMedicSvc)
$BtnDisableWinUpdate.Add_Click({
    Invoke-SafeTweak "Desativar Windows Update (wuauserv, UsoSvc, WaaSMedicSvc)" {
        Backup-CoreServicesState @("wuauserv", "UsoSvc", "WaaSMedicSvc")
        @("wuauserv", "UsoSvc", "WaaSMedicSvc") | ForEach-Object { [void](Set-ServiceStartModeSafe $_ 4) }
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
    }
    $script:WinUpdateDisabledCache = ((Get-ServiceStartModeFast "wuauserv") -eq 4)
    $StatusWinUpdateCard.Foreground = if ($script:WinUpdateDisabledCache) { "#F87171" } else { "#4ADE80" }
    Refresh-CachedStatusLabels
})

$BtnRestoreWinUpdate.Add_Click({
    Invoke-SafeTweak "Restaurar Windows Update" {
        Restore-CoreServicesState @("wuauserv", "UsoSvc", "WaaSMedicSvc")
        Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate"
    }
    $script:WinUpdateDisabledCache = ((Get-ServiceStartModeFast "wuauserv") -eq 4)
    $StatusWinUpdateCard.Foreground = if ($script:WinUpdateDisabledCache) { "#F87171" } else { "#4ADE80" }
    Refresh-CachedStatusLabels
})

$BtnAdvFlushNet.Add_Click({ Invoke-SafeTweak "Reset de Rede e Flush DNS" { ipconfig /flushdns | Out-Null; netsh winsock reset | Out-Null; netsh int ip reset | Out-Null } })
$BtnAdvCleanCache.Add_Click({ Invoke-SafeTweak "Limpeza de Pastas Temp e Prefetch" { [BetterTitus.FastCleaner]::CleanPattern(@("$userTempPath\*", "$env:windir\Temp\*", "$env:windir\Prefetch\*")) } })

# Presets Seguros
$BtnPresetClr.Add_Click({
    foreach ($c in $AllLeftChecks) { if ($c.Visibility -eq 'Visible') { $c.IsChecked = $false } }
    Write-BTLog "Seleção visível limpa." "INFO"
})
$BtnPresetMin.Add_Click({
    foreach ($c in $AllLeftChecks) { if ($c.Visibility -eq 'Visible') { $c.IsChecked = $false } }
    @($ChkActivity, $ChkConsumer, $ChkTelemetry, $ChkServicesMan) | ForEach-Object { if ($_.Visibility -eq 'Visible') { $_.IsChecked = $true } }
    Write-BTLog "Preset 'Minimal' selecionado." "INFO"
})
$BtnPresetStd.Add_Click({
    foreach ($c in $AllLeftChecks) { if ($c.Visibility -eq 'Visible') { $c.IsChecked = $false } }
    @($ChkActivity, $ChkConsumer, $ChkDelivery, $ChkEndTask, $ChkFolderDisc, $ChkHibernation, $ChkLocation, $ChkStoreSearch, $ChkDeviceCompanion, $ChkServicesMan, $ChkTelemetry, $ChkWidgets, $ChkWPBT) | ForEach-Object {
        if ($_.Visibility -eq 'Visible') { $_.IsChecked = $true }
    }
    Write-BTLog "Preset 'Standard' selecionado." "INFO"
})
$BtnPresetAdv.Add_Click({
    foreach ($c in $AllLeftChecks) { if ($c.Visibility -eq 'Visible') { $c.IsChecked = $false } }
    foreach ($c in $SafeLeftChecks) { if ($c.Visibility -eq 'Visible') { $c.IsChecked = $true } }
    Write-BTLog "Preset 'Advanced' selecionado (Proteções de Segurança mantidas fora por segurança)." "INFO"
})
$BtnSelectInstalled.Add_Click({
    Sync-SystemStateAsync { Write-BTLog "Estado real do Windows verificado e sincronizado." "OK" }
})

# ==============================================================================
# REVERSÃO INDIVIDUAL LIMPA (PRESERVANDO POLÍTICAS E BACKUPS ORIGINAIS)
# ==============================================================================
function Invoke-RevertSingleTweak ([string]$ChkName) {
    switch ($ChkName) {
        "ChkActivity"        { Invoke-SafeTweak "Reverter Histórico de Atividades" { Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed"; Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities"; Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" } }
        "ChkConsumer"        { Invoke-SafeTweak "Reverter ConsumerFeatures" { Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures"; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 1 } }
        "ChkDelivery"        { Invoke-SafeTweak "Reverter Delivery Optimization" { Remove-RegValueSafe "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode"; Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" } }
        "ChkEndTask"         { Invoke-SafeTweak "Reverter End Task na Barra" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask" 0 } }
        "ChkFolderDisc"      { Invoke-SafeTweak "Reverter Folder Discovery" { Remove-RegValueSafe "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" "FolderType" } }
        "ChkHibernation"     { Invoke-SafeTweak "Reverter Hibernação" { powercfg.exe /hibernate on; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 1 } }
        "ChkLocation"        { Invoke-SafeTweak "Reverter Localização" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Allow" "String" } }
        "ChkMemCompression"  { Invoke-SafeTweak "Reverter Compactação de Memória" { if (Get-Command Enable-MMAgent -ErrorAction SilentlyContinue) { Enable-MMAgent -MemoryCompression -ErrorAction Stop } } }
        "ChkStoreSearch"     { Invoke-SafeTweak "Reverter Store Search" { Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" } }
        "ChkDeviceCompanion" { Invoke-SafeTweak "Reverter Device Companion Apps" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 0 } }
        "ChkServicesMan"     {
            Invoke-SafeTweak "Reverter Serviços Secundários" {
                if (Test-Path $script:SvcBackup) {
                    $bkp = Get-Content $script:SvcBackup -Raw | ConvertFrom-Json
                    foreach ($entry in $bkp) {
                        $st = [int]$entry.Start
                        if ($st -in @(2, 3, 4)) { [void](Set-ServiceStartModeSafe $entry.Name $st) }
                    }
                    Remove-Item $script:SvcBackup -Force -ErrorAction SilentlyContinue
                } else {
                    foreach ($svc in $script:SafeManualServices) {
                        if ((Get-ServiceStartModeFast $svc) -ne -1) { [void](Set-ServiceStartModeSafe $svc 3) }
                    }
                }
            }
        }
        "ChkTelemetry"       {
            Invoke-SafeTweak "Reverter Telemetria" {
                Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry"
                Remove-RegValueSafe "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry"
                Restore-CoreServicesState @("DiagTrack", "dmwappushservice")
            }
        }
        "ChkWidgets"         {
            Invoke-SafeTweak "Reverter Widgets" {
                Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 1
                Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests"
            }
        }
        "ChkWPBT"            { Invoke-SafeTweak "Reverter WPBT" { Remove-RegValueSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" } }
        "ChkSearchIdx"       {
            Invoke-SafeTweak "Reverter Windows Search" {
                Restore-CoreServicesState @("WSearch")
            }
        }
        "ChkBgApps"          { Invoke-SafeTweak "Reverter Background Apps" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 0 } }
        "ChkOptTasks"        {
            Invoke-SafeTweak "Reverter Tarefas de Telemetria" {
                $savedTasks = @{}
                if (Test-Path $script:TasksBackup) {
                    try {
                        $loaded = Get-Content $script:TasksBackup -Raw | ConvertFrom-Json
                        foreach ($p in $loaded.PSObject.Properties) { $savedTasks[$p.Name] = [bool]$p.Value }
                    } catch {}
                    Remove-Item $script:TasksBackup -Force -ErrorAction SilentlyContinue
                }
                foreach ($t in $script:OptionalScheduledTasks) {
                    $shouldEnable = if ($savedTasks.ContainsKey($t)) { $savedTasks[$t] } else { $true }
                    if ($shouldEnable) {
                        $p = Split-Path $t -Parent; $n = Split-Path $t -Leaf
                        Enable-ScheduledTask -TaskPath "$p\" -TaskName $n -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            }
        }
        "ChkReservedStorage" { Invoke-SafeTweak "Reverter Armazenamento Reservado" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "ShippedWithReserves" 1; if (Get-Command Set-WindowsReservedStorageState -ErrorAction SilentlyContinue) { Set-WindowsReservedStorageState -State Enabled -ErrorAction SilentlyContinue } } }
        "ChkExplorerGallery" { Invoke-SafeTweak "Reverter Galeria/Início Explorer" { Set-Reg "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 1; Set-Reg "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" "System.IsPinnedToNameSpaceTree" 1 } }
        "ChkGameDVR"         {
            Invoke-SafeTweak "Reverter GameDVR" {
                Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 1
                Remove-RegValueSafe "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode"
                Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 1
                Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR"
            }
        }
        "ChkIPv4Pref"        {
            Invoke-SafeTweak "Reverter IPv4 Preferencial" {
                if (Test-Path $script:Ipv6Backup) {
                    $prev = [int](Get-Content $script:Ipv6Backup -Raw).Trim()
                    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" $prev
                    Remove-Item $script:Ipv6Backup -Force -ErrorAction SilentlyContinue
                } else {
                    Remove-RegValueSafe "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents"
                }
            }
        }
        "ChkTeredo"          {
            Invoke-SafeTweak "Reverter Teredo" {
                & netsh.exe interface teredo set state default | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "netsh retornou código de saída $LASTEXITCODE" }
                Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" "Teredo_State"
            }
        }
        "ChkMenuDelay"       { Invoke-SafeTweak "Reverter MenuShowDelay (400ms)" { Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" "String" } }
        "ChkEdgeDebloat"     {
            Invoke-SafeTweak "Reverter Edge Background (Remover Políticas Criadas)" {
                Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled"
                Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "StartupBoostEnabled"
            }
        }
        "ChkNetThrottle"     { Invoke-SafeTweak "Reverter Network Throttling" { Remove-RegValueSafe "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex"; Remove-RegValueSafe "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" } }
        "ChkPowerThrottle"   { Invoke-SafeTweak "Reverter Power Throttling" { Remove-RegValueSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" } }
        "ChkClassicContext"  { Invoke-SafeTweak "Reverter Menu Clássico Win 11" { Remove-RegValueSafe "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "(default)"; Remove-Item (Resolve-RegPath "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}") -Recurse -Force -ErrorAction SilentlyContinue } }
        "ChkStorageSense"    { Invoke-SafeTweak "Reverter Storage Sense" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 1 } }
        "ChkSvcHost"         { Invoke-SafeTweak "Reverter SvcHost Split (Padrão 3670016 KB)" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB" 3670016 } }
        "ChkUsbSuspend"      { Invoke-SafeTweak "Reverter USB Selective Suspend" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\USB" "DisableSelectiveSuspend" 0 } }
        "ChkBestPerf"        { Invoke-SafeTweak "Reverter Visual Effects" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 0 } }
        "ChkWinAI"           {
            Invoke-SafeTweak "Reverter Windows AI (Remover Valores Criados)" {
                Remove-RegValueSafe "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot"
                Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot"
                Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis"
                Remove-RegValueSafe "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffSavingSnapshots"
                Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 1
            }
        }
        "ChkBitLocker"       {
            Invoke-SafeTweak "Reverter BitLocker (Retomar Proteção Existente)" {
                if (Get-Command Resume-BitLocker -ErrorAction SilentlyContinue) {
                    $vol = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
                    if ($null -ne $vol -and $vol.KeyProtector.Count -gt 0) {
                        Resume-BitLocker -MountPoint $env:SystemDrive -ErrorAction Stop | Out-Null
                    } else {
                        Write-BTLog "BitLocker sem protetor de chave salvo: ative manualmente via Painel de Controle para gerar e salvar sua chave de recuperação." "WARN"
                    }
                } else {
                    [void](Set-ServiceStartModeSafe "BDESVC" 3)
                }
            }
        }
        "ChkHVCI"            {
            Invoke-SafeTweak "Reativar HVCI / Memory Integrity (Reinicie o PC)" {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1
            } { (Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0) -eq 1 }
        }
        "ChkCpuMitigations"  {
            Invoke-SafeTweak "Reativar Mitigações Spectre/Meltdown (Reinicie o PC)" {
                Remove-RegValueSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride"
                Remove-RegValueSafe "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask"
            }
        }
    }
}

# ==============================================================================
# APLICAR OTIMIZAÇÕES NA ORDEM SEGURA
# ==============================================================================
$BtnRunTweaks.Add_Click({
    $secSelected = @()
    if ($ChkBitLocker.IsChecked -and -not $script:AppliedSecurityCache.BitLocker) { $secSelected += "- Desativar BitLocker (Descriptografia de Disco em Background)" }
    if ($ChkHVCI.IsChecked -and -not $script:AppliedSecurityCache.HVCI)           { $secSelected += "- Desativar HVCI / Integridade de Memória (Pode afetar Vanguard/FACEIT)" }
    if ($ChkCpuMitigations.IsChecked -and -not $script:AppliedSecurityCache.Mitigations) { $secSelected += "- Desativar Mitigações Spectre/Meltdown (Menor proteção especulativa)" }

    $applySecurity = $true
    if ($secSelected.Count -gt 0) {
        $warnText = if ($script:Lang -eq "PT") {
            "CONFIRMAÇÃO DE SEGURANÇA OBRIGATÓRIA:`n`nVocê selecionou alterações que reduzem camadas de proteção do Windows para ganhar desempenho:`n`n$($secSelected -join "`n")`n`nDeseja prosseguir?"
        } else {
            "EXPLICIT SECURITY CONFIRMATION REQUIRED:`n`nYou selected optimizations that reduce Windows security layers for performance:`n`n$($secSelected -join "`n")`n`nProceed?"
        }
        $ans = [System.Windows.MessageBox]::Show($warnText, "BetterTitus - Security Confirmation", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($ans -ne [System.Windows.MessageBoxResult]::Yes) {
            $applySecurity = $false
            Write-BTLog "Alterações de Segurança (BitLocker/HVCI/Mitigações) canceladas pelo usuário." "WARN"
        }
    }

    $runBitlocker = $false
    if ($applySecurity -and $ChkBitLocker.IsChecked -and -not $script:AppliedSecurityCache.BitLocker) {
        $blWarn = if ($script:Lang -eq "PT") {
            "CONFIRMAÇÃO DUPLA — BITLOCKER:`n`nA descriptografia da unidade $env:SystemDrive pode demorar vários minutos ou horas dependendo do tamanho e tipo do SSD/HD.`n`nTem certeza absoluta que deseja desativar o BitLocker?"
        } else {
            "DOUBLE CONFIRMATION — BITLOCKER:`n`nDecrypting system drive $env:SystemDrive may take several minutes or hours depending on drive size and speed.`n`nAre you sure you want to disable BitLocker?"
        }
        if ([System.Windows.MessageBox]::Show($blWarn, "BetterTitus - BitLocker Warning", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Stop) -eq [System.Windows.MessageBoxResult]::Yes) {
            $runBitlocker = $true
        }
    }

    Write-BTLog "=== APLICANDO OTIMIZAÇÕES SELECIONADAS ===" "HEADER"

    # 1. REVERSÃO AUTOMÁTICA DOS ITENS DESMARCADOS PELO USUÁRIO
    $uncheckedRevertList = @()
    foreach ($chk in $AllLeftChecks) {
        if (-not $chk.IsChecked -and $script:InitialTweakState[$chk.Name] -eq $true) {
            $uncheckedRevertList += $chk.Name
        }
    }
    if ($uncheckedRevertList.Count -gt 0) {
        Write-BTLog "Detectados $($uncheckedRevertList.Count) itens desmarcados -> Revertendo..." "INFO"
        foreach ($itemName in $uncheckedRevertList) {
            Invoke-RevertSingleTweak $itemName
        }
    }

    # 2. APLICAR OS ITENS MARCADOS
    if ($ChkActivity.IsChecked)        { Invoke-SafeTweak "Desativar Histórico de Atividades" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 } }
    if ($ChkConsumer.IsChecked)        { Invoke-SafeTweak "Desativar ConsumerFeatures" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0 } }
    if ($ChkDelivery.IsChecked)        { Invoke-SafeTweak "Desativar Delivery Optimization P2P" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0 } }
    if ($ChkEndTask.IsChecked)         { Invoke-SafeTweak "Ativar End Task na Barra" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask" 1 } }
    if ($ChkFolderDisc.IsChecked)      { Invoke-SafeTweak "Desativar Folder Discovery" { Set-Reg "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" "FolderType" "NotSpecified" "String" } }
    if ($ChkHibernation.IsChecked)     { Invoke-SafeTweak "Desativar Hibernação" { powercfg.exe /hibernate off; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0 } }
    if ($ChkLocation.IsChecked)        { Invoke-SafeTweak "Desativar Localização" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Deny" "String" } }
    if ($ChkMemCompression.IsChecked)  { Invoke-SafeTweak "Desativar Compactação de Memória" { if (Get-Command Disable-MMAgent -ErrorAction SilentlyContinue) { Disable-MMAgent -MemoryCompression -ErrorAction Stop } } }
    if ($ChkStoreSearch.IsChecked)     { Invoke-SafeTweak "Desativar Store Search" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 1 } }
    if ($ChkDeviceCompanion.IsChecked) { Invoke-SafeTweak "Impedir Device Companion Apps" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 1 } }

    if ($ChkServicesMan.IsChecked) {
        Invoke-SafeTweak "Definir Serviços Secundários como Manual (com Backup)" {
            if (-not (Test-Path $script:SvcBackup)) {
                $bkpData = @()
                foreach ($svc in $script:SafeManualServices) {
                    $st = Get-ServiceStartModeFast $svc
                    if ($st -in @(2, 3, 4)) { $bkpData += [PSCustomObject]@{ Name = $svc; Start = $st } }
                }
                if ($bkpData.Count -gt 0) { $bkpData | ConvertTo-Json -Depth 2 | Set-Content -Path $script:SvcBackup -Encoding UTF8 -Force }
            }
            foreach ($svc in $script:SafeManualServices) {
                $cur = Get-ServiceStartModeFast $svc
                if ($cur -ne -1 -and $cur -ne 4) { [void](Set-ServiceStartModeSafe $svc 3) }
            }
        }
    }

    if ($ChkTelemetry.IsChecked) {
        Invoke-SafeTweak "Desativar Telemetria (com Backup DiagTrack)" {
            Backup-CoreServicesState @("DiagTrack", "dmwappushservice")
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
            [void](Set-ServiceStartModeSafe "DiagTrack" 4)
            [void](Set-ServiceStartModeSafe "dmwappushservice" 4)
        }
    }

    if ($ChkWidgets.IsChecked) { Invoke-SafeTweak "Remover Widgets" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0 } }
    if ($ChkWPBT.IsChecked)    { Invoke-SafeTweak "Desativar WPBT" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 1 } }
    if ($ChkSearchIdx.IsChecked) {
        Invoke-SafeTweak "Desativar Windows Search (com Backup WSearch)" {
            Backup-CoreServicesState @("WSearch")
            [void](Set-ServiceStartModeSafe "WSearch" 4)
        }
    }

    if ($ChkBgApps.IsChecked) { Invoke-SafeTweak "Desativar Background Apps" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1 } }
    if ($ChkOptTasks.IsChecked) {
        Invoke-SafeTweak "Desativar Tarefas de Telemetria (com Backup Individual)" {
            if (-not (Test-Path $script:TasksBackup)) {
                $tStates = @{}
                foreach ($t in $script:OptionalScheduledTasks) {
                    $p = Split-Path $t -Parent; $n = Split-Path $t -Leaf
                    $taskObj = Get-ScheduledTask -TaskPath "$p\" -TaskName $n -ErrorAction SilentlyContinue
                    if ($null -ne $taskObj) {
                        $tStates[$t] = ($taskObj.State -ne 'Disabled')
                    }
                }
                if ($tStates.Count -gt 0) {
                    $tStates | ConvertTo-Json -Depth 2 | Set-Content -Path $script:TasksBackup -Encoding UTF8 -Force
                }
            }
            foreach ($t in $script:OptionalScheduledTasks) {
                $p = Split-Path $t -Parent; $n = Split-Path $t -Leaf
                Disable-ScheduledTask -TaskPath "$p\" -TaskName $n -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    if ($ChkReservedStorage.IsChecked) { Invoke-SafeTweak "Desativar Armazenamento Reservado" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "ShippedWithReserves" 0; if (Get-Command Set-WindowsReservedStorageState -ErrorAction SilentlyContinue) { Set-WindowsReservedStorageState -State Disabled -ErrorAction SilentlyContinue } } }
    if ($ChkExplorerGallery.IsChecked) { Invoke-SafeTweak "Ocultar Galeria/Início Explorer" { Set-Reg "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 0; Set-Reg "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" "System.IsPinnedToNameSpaceTree" 0 } }
    if ($ChkGameDVR.IsChecked)         { Invoke-SafeTweak "Desativar GameDVR" { Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0; Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0 } }
    if ($ChkIPv4Pref.IsChecked) {
        Invoke-SafeTweak "Definir IPv4 como Preferencial (com Backup)" {
            if (-not (Test-Path $script:Ipv6Backup)) {
                $curDc = Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" 0
                [string]$curDc | Set-Content -Path $script:Ipv6Backup -Encoding UTF8 -Force
            }
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" 32
        }
    }
    if ($ChkTeredo.IsChecked) {
        Invoke-SafeTweak "Desativar Teredo" {
            & netsh.exe interface teredo set state disabled | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "netsh retornou código de saída $LASTEXITCODE" }
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" "Teredo_State" "Disabled" "String"
        }
    }
    if ($ChkMenuDelay.IsChecked)       { Invoke-SafeTweak "MenuShowDelay = 0ms" { Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String" } }
    if ($ChkEdgeDebloat.IsChecked)     { Invoke-SafeTweak "Desativar Processos Edge Background" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "StartupBoostEnabled" 0 } }
    if ($ChkNetThrottle.IsChecked)     { Invoke-SafeTweak "Otimizar Network Throttling" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xffffffff; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0 } }
    if ($ChkPowerThrottle.IsChecked)   { Invoke-SafeTweak "Desativar Power Throttling" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1 } }
    if ($ChkClassicContext.IsChecked)  { Invoke-SafeTweak "Ativar Menu Clássico Win 11" { Set-Reg "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "(default)" "" "String" } }
    if ($ChkStorageSense.IsChecked)    { Invoke-SafeTweak "Desativar Storage Sense" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 0 } }
    if ($ChkSvcHost.IsChecked -and $script:HwInfo.RamKB -gt 0) { Invoke-SafeTweak "Ajustar SvcHost Split ($($script:HwInfo.RamKB) KB)" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB" $script:HwInfo.RamKB } }
    if ($ChkUsbSuspend.IsChecked)      { Invoke-SafeTweak "Desativar USB Selective Suspend" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\USB" "DisableSelectiveSuspend" 1 } }
    if ($ChkBestPerf.IsChecked)        { Invoke-SafeTweak "Visual Effects -> Best Performance" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2 } }
    if ($ChkWinAI.IsChecked)           { Invoke-SafeTweak "Desativar Windows AI (Copilot/Recall)" { Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffSavingSnapshots" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0 } }

    if ($runBitlocker) {
        Invoke-SafeTweak "Desativar BitLocker ($env:SystemDrive)" {
            if (Get-Command Disable-BitLocker -ErrorAction SilentlyContinue) {
                Disable-BitLocker -MountPoint $env:SystemDrive -ErrorAction Stop | Out-Null
            } else {
                & manage-bde.exe -off $env:SystemDrive | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "manage-bde retornou código $LASTEXITCODE" }
            }
        }
    }
    if ($applySecurity -and $ChkHVCI.IsChecked -and -not $script:AppliedSecurityCache.HVCI) {
        Invoke-SafeTweak "Desativar HVCI / Memory Integrity (Requer Reinício)" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0 }
    }
    if ($applySecurity -and $ChkCpuMitigations.IsChecked -and -not $script:AppliedSecurityCache.Mitigations) {
        Invoke-SafeTweak "Desativar Mitigações Spectre/Meltdown (Requer Reinício)" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 3; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 3 }
    }

    # DNS (Inclui adaptadores físicos/virtuais mesmo desconectados)
    $dnsIdx = $CmbDNS.SelectedIndex
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -notmatch 'Loopback|Pseudo' }
    if ($dnsIdx -gt 0) {
        $dnsAddrs = switch ($dnsIdx) { 1 { @("1.1.1.1","1.0.0.1") } 2 { @("8.8.8.8","8.8.4.4") } 3 { @("9.9.9.9","149.112.112.112") } }
        Invoke-SafeTweak "Aplicar DNS ($($dnsAddrs -join ', '))" {
            foreach ($nic in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $dnsAddrs -ErrorAction SilentlyContinue }
            ipconfig /flushdns | Out-Null
        }
    } elseif ($dnsIdx -eq 0) {
        Invoke-SafeTweak "Restaurar DNS Padrão (DHCP)" {
            foreach ($nic in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue }
        }
    }

    [BetterTitus.NativeMethods]::BroadcastSettingsChange()
    Sync-SystemStateAsync { Write-BTLog "=== TODAS AS ALTERAÇÕES FORAM CONCLUÍDAS ===" "OK" }
})

# ==============================================================================
# REVERTER OTIMIZAÇÕES SELECIONADAS (UNDO)
# ==============================================================================
$BtnUndoTweaks.Add_Click({
    Write-BTLog "=== REVERTENDO OTIMIZAÇÕES SELECIONADAS ===" "HEADER"

    foreach ($chk in $AllLeftChecks) {
        if ($chk.IsChecked) {
            Invoke-RevertSingleTweak $chk.Name
        }
    }

    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -notmatch 'Loopback|Pseudo' }
    foreach ($nic in $adapters) { Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue }
    $CmbDNS.SelectedIndex = 0
    [BetterTitus.NativeMethods]::BroadcastSettingsChange()

    Sync-SystemStateAsync { Write-BTLog "=== REVERSÃO CONCLUÍDA ===" "OK" }
})

# ==============================================================================
# INICIALIZAÇÃO
# ==============================================================================
Apply-AppTheme $script:isDark
Set-AppLanguage $script:Lang $false
Update-SelectedGameUI
Sync-SystemStateAsync {
    Write-BTLog "BetterTitus pronto. Estado real do sistema sincronizado." "OK"
}
$window.ShowDialog() | Out-Null
