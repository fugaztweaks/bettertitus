# ==============================================================================
# BetterTitus - by fugaztweaks (Version 0.5 Beta)
# Windows Optimization & Competitive Gaming Utility
# ==============================================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# ==============================================================================
# DIRETÓRIO SEGURO COM ACL RESTRITA (ANTI-PRIVILEGE ESCALATION PARA SYSTEM TASKS)
# ==============================================================================
$script:ConfigDir  = "$env:ProgramData\BetterTitus"
$script:GamesJson  = "$script:ConfigDir\games.json"
$script:IconPath   = "$script:ConfigDir\BetterTitus.ico"
$script:NvBackup   = "$script:ConfigDir\nv_backup.json"

if (-not (Test-Path $script:ConfigDir)) {
    New-Item -Path $script:ConfigDir -ItemType Directory -Force | Out-Null
}
& icacls.exe $script:ConfigDir /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-32-545:(OI)(CI)RX" | Out-Null

# ==============================================================================
# GERADOR DE ÍCONE PERSONALIZADO (.ICO 256x256) NA IDENTIDADE ROXA BETTERTITUS
# ==============================================================================
function Ensure-BetterTitusIcon ([string]$OutIcoPath) {
    try {
        $size = 256
        $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
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
    } catch {}
}

Ensure-BetterTitusIcon $script:IconPath

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="BetterTitus - by fugaztweaks (Version 0.5 Beta)" 
        Height="890" Width="1340" MinHeight="750" MinWidth="1150"
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
        <!-- Identidade Visual BetterTitus (Dark Purple Palette) -->
        <SolidColorBrush x:Key="BgMain" Color="#111017"/>
        <SolidColorBrush x:Key="BgPanel" Color="#171520"/>
        <SolidColorBrush x:Key="BgHeader" Color="#0C0B10"/>
        <SolidColorBrush x:Key="BgBtn" Color="#221E30"/>
        <SolidColorBrush x:Key="BgBtnHover" Color="#2F2944"/>
        <SolidColorBrush x:Key="BgBtnActive" Color="#7C3AED"/>
        <SolidColorBrush x:Key="BorderSubtle" Color="#2E2942"/>
        <SolidColorBrush x:Key="BorderHighlight" Color="#8B5CF6"/>
        <SolidColorBrush x:Key="TextMain" Color="#F3F4F6"/>
        <SolidColorBrush x:Key="TextDim" Color="#9CA3AF"/>
        <SolidColorBrush x:Key="PurpleHeader" Color="#A78BFA"/>
        <SolidColorBrush x:Key="PurpleAccent" Color="#7C3AED"/>

        <!-- Estilo Global de ToolTip Refinado (Roxo Dark + Quebra de Linha) -->
        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="#1B172B"/>
            <Setter Property="Foreground" Value="#F3F4F6"/>
            <Setter Property="BorderBrush" Value="#8B5CF6"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="MaxWidth" Value="380"/>
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

        <!-- Botão Padrão -->
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
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Botão de Aba Superior -->
        <Style x:Key="NavTabBtn" TargetType="Button" BasedOn="{StaticResource BTButton}">
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="Padding" Value="18,5"/>
            <Setter Property="Margin" Value="3,0"/>
        </Style>

        <!-- CheckBox Refinada (Com ToolTip instantâneo ao passar o mouse) -->
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
                                    Background="#1B1826" BorderBrush="#4C446B" BorderThickness="1"
                                    VerticalAlignment="Center" HorizontalAlignment="Left">
                                <Path x:Name="chkMark" Data="M 2.5,6.5 L 5.5,9.5 L 11.5,3.5" Stroke="#FFFFFF" StrokeThickness="1.8" Visibility="Collapsed"/>
                            </Border>
                            <ContentPresenter Grid.Column="1" VerticalAlignment="Center" Margin="2,0,0,0"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="chkBox" Property="BorderBrush" Value="#A78BFA"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="chkBox" Property="Background" Value="#7C3AED"/>
                                <Setter TargetName="chkBox" Property="BorderBrush" Value="#A78BFA"/>
                                <Setter TargetName="chkMark" Property="Visibility" Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Interruptor Deslizante Roxo com Animação Suave -->
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
                                    Background="#242033" BorderBrush="#4C446B" BorderThickness="1"
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
                                <Setter TargetName="Track" Property="BorderBrush" Value="#A78BFA"/>
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

        <!-- Estilo Limpo e Profissional para a Lista de Jogos -->
        <Style x:Key="GameListBoxItemStyle" TargetType="ListBoxItem">
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Padding" Value="0"/>
            <Setter Property="Margin" Value="0,0,0,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="ItemBorder" Background="#161421" BorderBrush="#262238" BorderThickness="1" CornerRadius="5" Padding="14,10">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#211D30"/>
                                <Setter TargetName="ItemBorder" Property="BorderBrush" Value="#5B4699"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="#282042"/>
                                <Setter TargetName="ItemBorder" Property="BorderBrush" Value="#8B5CF6"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <!-- Borda Externa da Janela -->
    <Border Background="{DynamicResource BgMain}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="5">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="46"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="115"/>
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
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,14,0">
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
                                <Border Background="#2D2642" BorderBrush="#7C3AED" BorderThickness="1" CornerRadius="3" Padding="5,0" Margin="6,0,0,0" VerticalAlignment="Center">
                                    <TextBlock Text="Version 0.5 Beta" Foreground="#A78BFA" FontSize="10" FontWeight="SemiBold"/>
                                </Border>
                            </StackPanel>
                            <TextBlock Text="by fugaztweaks" Foreground="{DynamicResource TextDim}" FontSize="10" Margin="0,-1,0,0"/>
                        </StackPanel>
                    </StackPanel>

                    <!-- Abas de Navegação -->
                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="BtnNavTweaks" Content="Tweaks" Style="{StaticResource NavTabBtn}" Background="#7C3AED" BorderBrush="#A78BFA"/>
                        <Button x:Name="BtnNavGaming" Content="Gaming" Style="{StaticResource NavTabBtn}"/>
                        <Button x:Name="BtnNavAdvanced" Content="Advanced" Style="{StaticResource NavTabBtn}"/>
                    </StackPanel>

                    <!-- Barra de Busca Central -->
                    <Border Grid.Column="2" Background="#171520" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Height="28" Margin="18,0">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="30"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="TxtSearch" Grid.Column="0" Background="Transparent" Foreground="{DynamicResource TextMain}" BorderThickness="0" VerticalContentAlignment="Center" Padding="8,0" FontSize="12" CaretBrush="{DynamicResource TextMain}"/>
                            <TextBlock x:Name="LblSearchPlaceholder" Grid.Column="0" Text="Search tweaks or preferences..." Foreground="{DynamicResource TextDim}" VerticalAlignment="Center" Margin="10,0,0,0" IsHitTestVisible="False">
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
                            <TextBlock Grid.Column="1" Text="🔍" FontSize="11" Foreground="#A78BFA" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Grid>
                    </Border>

                    <!-- Seletor de Idioma em Barra (English | Português BR) -->
                    <Border Grid.Column="3" Background="#171520" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Height="28" Margin="0,0,12,0" Padding="2">
                        <StackPanel Orientation="Horizontal">
                            <Button x:Name="BtnLangEN" Content="English" Style="{StaticResource BTButton}" Margin="0" Padding="10,2" BorderThickness="0"/>
                            <Button x:Name="BtnLangPT" Content="Português (BR)" Style="{StaticResource BTButton}" Margin="2,0,0,0" Padding="10,2" BorderThickness="0"/>
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
            <!-- ABA 1: TWEAKS (Completa com Tooltips Bilíngues + Segurança Explícita)  -->
            <!-- ====================================================================== -->
            <Grid Grid.Row="1" x:Name="ViewTweaks" Visibility="Visible" Margin="12,8,12,4">
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
                            <Button x:Name="BtnOpenCleanmgr" Content="🧹 Disk Cleanup (cleanmgr)" Style="{StaticResource BTButton}" Background="#2D2642" BorderBrush="#8B5CF6"/>
                            <Button x:Name="BtnCreateRestore" Content="🛡️ Create Restore Point" Style="{StaticResource BTButton}" Background="#2D2642" BorderBrush="#8B5CF6" Margin="0,0,0,4"/>
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
                                <TextBlock x:Name="HdrCustomize" Text="Customize Preferences" FontFamily="Consolas" FontSize="15" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,6"/>

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
            <!-- ABA 2: GAMING (Lista Limpa + 4 Otimizações Competitivas Profissionais) -->
            <!-- ====================================================================== -->
            <Grid Grid.Row="1" x:Name="ViewGaming" Visibility="Collapsed" Margin="14,10,14,6">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="360"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Coluna Esquerda Gaming: Lista Limpa (Apenas Nome em Negrito + Tag Discreta) -->
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

                        <!-- ListBox Clean: Apenas Nome em Negrito e Tag Discreta quando Custom -->
                        <ListBox x:Name="LstGames" Grid.Row="1" Background="#111017" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" 
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
                                        <TextBlock Grid.Column="1" Text="{Binding Badge}" FontSize="10" FontWeight="SemiBold" Foreground="#A78BFA" VerticalAlignment="Center"/>
                                    </Grid>
                                </DataTemplate>
                            </ListBox.ItemTemplate>
                        </ListBox>

                        <!-- Card Adicionar Jogo Personalizado -->
                        <Border Grid.Row="2" Background="#111017" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="12" Margin="0,12,0,0">
                            <StackPanel>
                                <TextBlock x:Name="HdrAddCustomGame" Text="Add Custom Game" FontFamily="Consolas" FontSize="13.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,8"/>
                                
                                <TextBlock x:Name="LblGameName" Text="Game Name:" Foreground="{DynamicResource TextDim}" FontSize="11.5" Margin="0,0,0,2"/>
                                <TextBox x:Name="TxtCustomGameName" Background="#221E30" Foreground="{DynamicResource TextMain}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" Height="26" Padding="6,2" Margin="0,0,0,8"/>

                                <TextBlock x:Name="LblGameExe" Text="Executable (.exe):" Foreground="{DynamicResource TextDim}" FontSize="11.5" Margin="0,0,0,2"/>
                                <Grid Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox x:Name="TxtCustomGameExe" Grid.Column="0" Background="#221E30" Foreground="{DynamicResource TextMain}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" Height="26" Padding="6,2" IsReadOnly="True"/>
                                    <Button x:Name="BtnBrowseExe" Grid.Column="1" Content="Browse..." Style="{StaticResource BTButton}" Margin="6,0,0,0" Padding="12,2"/>
                                </Grid>

                                <UniformGrid Rows="1" Columns="2">
                                    <Button x:Name="BtnAddGame" Content="Add to List" Style="{StaticResource BTButton}" Background="#7C3AED" BorderBrush="#A78BFA"/>
                                    <Button x:Name="BtnRemoveGame" Content="Remove Selected" Style="{StaticResource BTButton}" Margin="0,0,0,4"/>
                                </UniformGrid>
                            </StackPanel>
                        </Border>
                    </Grid>
                </Border>

                <!-- Coluna Direita Gaming: 4 Cards de Otimização -->
                <Border Grid.Column="1" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Margin="8,0,0,0" Padding="20">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <!-- Cabeçalho do Jogo + Hardware -->
                            <Border Background="#111017" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="16,12" Margin="0,0,0,14">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" VerticalAlignment="Center">
                                        <TextBlock x:Name="LblSelectedGameTitle" Text="VALORANT" FontSize="20" FontWeight="Bold" Foreground="{DynamicResource TextMain}"/>
                                        <TextBlock x:Name="LblSelectedGameExe" Text="VALORANT-Win64-Shipping.exe" FontFamily="Consolas" FontSize="11.5" Foreground="#8B86A3" Margin="0,2,0,0"/>
                                    </StackPanel>
                                    <Border Grid.Column="1" Background="#221E30" BorderBrush="#7C3AED" BorderThickness="1" CornerRadius="4" Padding="14,6" VerticalAlignment="Center">
                                        <StackPanel>
                                            <TextBlock x:Name="LblCpuTopology" Text="CPU: Detecting..." FontFamily="Consolas" FontSize="11.5" Foreground="#A78BFA" FontWeight="Bold"/>
                                            <TextBlock x:Name="LblCpuMaskInfo" Text="No-CPU0 Mask: Calculating..." FontFamily="Consolas" FontSize="11" Foreground="{DynamicResource TextDim}"/>
                                        </StackPanel>
                                    </Border>
                                </Grid>
                            </Border>

                            <!-- Card 1: Priorizar Rota de Jogo -->
                            <Border Background="#111017" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="15" Margin="0,0,0,12">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Margin="0,0,20,0">
                                        <TextBlock x:Name="HdrDscp" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                                        <TextBlock x:Name="DescDscp" Foreground="{DynamicResource TextDim}" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,6"/>
                                        <TextBlock x:Name="StatusDscp" FontFamily="Consolas" FontSize="11.5" Foreground="#9CA3AF"/>
                                    </StackPanel>
                                    <CheckBox x:Name="TglGameDscp" Grid.Column="1" Style="{StaticResource BTToggleSwitch}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <!-- Card 2: Prioridade Alta + Afinidade Otimizada -->
                            <Border Background="#111017" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="15" Margin="0,0,0,12">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Margin="0,0,20,0">
                                        <TextBlock x:Name="HdrAffinity" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                                        <TextBlock x:Name="DescAffinity" Foreground="{DynamicResource TextDim}" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,6"/>
                                        <TextBlock x:Name="StatusAffinity" FontFamily="Consolas" FontSize="11.5" Foreground="#9CA3AF"/>
                                    </StackPanel>
                                    <CheckBox x:Name="TglGameAffinity" Grid.Column="1" Style="{StaticResource BTToggleSwitch}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <!-- Card 3: Remover Latência de Tela Cheia -->
                            <Border Background="#111017" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="15" Margin="0,0,0,12">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Margin="0,0,20,0">
                                        <TextBlock x:Name="HdrDx11" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                                        <TextBlock x:Name="DescDx11" Foreground="{DynamicResource TextDim}" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,6"/>
                                        <TextBlock x:Name="StatusDx11" FontFamily="Consolas" FontSize="11.5" Foreground="#9CA3AF"/>
                                    </StackPanel>
                                    <CheckBox x:Name="TglGameDx11" Grid.Column="1" Style="{StaticResource BTToggleSwitch}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>

                            <!-- Card 4: Desativar Telemetria NVIDIA -->
                            <Border Background="#111017" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Padding="15" Margin="0,0,0,4">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Grid.Column="0" Margin="0,0,20,0">
                                        <TextBlock x:Name="HdrNvTel" FontSize="14.5" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}"/>
                                        <TextBlock x:Name="DescNvTel" Foreground="{DynamicResource TextDim}" FontSize="12" TextWrapping="Wrap" Margin="0,4,0,6"/>
                                        <TextBlock x:Name="StatusNvTel" FontFamily="Consolas" FontSize="11.5" Foreground="#9CA3AF"/>
                                    </StackPanel>
                                    <CheckBox x:Name="TglGameNvTel" Grid.Column="1" Style="{StaticResource BTToggleSwitch}" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Border>
            </Grid>

            <!-- ====================================================================== -->
            <!-- ABA 3: ADVANCED                                                        -->
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
                                <Button x:Name="BtnRestoreWinUpdate" Style="{StaticResource BTButton}" Background="#7C3AED" BorderBrush="#A78BFA" Padding="18,7"/>
                            </WrapPanel>
                        </StackPanel>
                    </Border>

                    <Border Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="5" Padding="24">
                        <StackPanel>
                            <TextBlock x:Name="HdrNetResetCard" FontSize="17" FontWeight="Bold" Foreground="{DynamicResource PurpleHeader}" Margin="0,0,0,8"/>
                            <TextBlock x:Name="DescNetResetCard" Foreground="{DynamicResource TextDim}" FontSize="12.5" TextWrapping="Wrap" Margin="0,0,0,14"/>
                            <WrapPanel Orientation="Horizontal">
                                <Button x:Name="BtnAdvCleanmgr" Style="{StaticResource BTButton}" Background="#7C3AED" BorderBrush="#A78BFA" Padding="16,7"/>
                                <Button x:Name="BtnAdvCleanCache" Style="{StaticResource BTButton}" Padding="16,7"/>
                                <Button x:Name="BtnAdvFlushNet" Style="{StaticResource BTButton}" Padding="16,7"/>
                            </WrapPanel>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </Grid>

            <!-- 4. RODAPÉ GLOBAL -->
            <Border Grid.Row="2" Background="{DynamicResource BgHeader}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="0,1,0,0" Padding="14,8">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Row="0" x:Name="LblFooterNote" Foreground="{DynamicResource PurpleHeader}" FontSize="11.5" Margin="0,0,0,6"/>

                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                            <Button x:Name="BtnRunTweaks" Style="{StaticResource BTButton}" Background="#7C3AED" BorderBrush="#A78BFA" Padding="18,8" FontWeight="Bold"/>
                            <Button x:Name="BtnUndoTweaks" Style="{StaticResource BTButton}" Padding="16,8" Margin="4,0,0,4"/>
                        </StackPanel>

                        <Border Grid.Column="1" Background="{DynamicResource BgPanel}" BorderBrush="{DynamicResource BorderSubtle}" BorderThickness="1" CornerRadius="4" Margin="12,0,0,0" Padding="8,4">
                            <TextBox x:Name="TxtLog" Background="Transparent" Foreground="#A78BFA" FontFamily="Consolas" FontSize="11.5" BorderThickness="0" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Text="[INIT] BetterTitus Version 0.5 Beta initialized."/>
                        </Border>
                    </Grid>
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
    } catch {}
}

$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
    Set-Variable -Name $_.Name -Value $window.FindName($_.Name) -Scope Script
}

# ==============================================================================
# HELPERS DE LOG, REGISTRO, SERVIÇOS E HARDWARE
# ==============================================================================
function Write-BTLog ([string]$Message, [string]$Level = "INFO") {
    $time = Get-Date -Format "HH:mm:ss"
    $TxtLog.AppendText("`r`n[$time][$Level] $Message")
    $TxtLog.ScrollToEnd()
}

function Set-Reg ([string]$Path, [string]$Name, $Value, [string]$Type = "DWord") {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
}

function Get-Reg ([string]$Path, [string]$Name, $Default = $null) {
    try {
        if (Test-Path $Path) {
            $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $prop -and $null -ne $prop.$Name) { return $prop.$Name }
        }
    } catch {}
    return $Default
}

function Invoke-SafeTweak ([string]$Title, [scriptblock]$Action, [scriptblock]$Verify = $null) {
    try {
        & $Action
        if ($null -ne $Verify) {
            if (& $Verify) { Write-BTLog "$Title -> OK" "OK" }
            else { Write-BTLog "$Title -> Aplicado parcialmente." "PARTIAL" }
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
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
    if (Test-Path $regPath) {
        Set-Reg $regPath "Start" $StartValue "DWord"
        if ($StartValue -eq 4) { Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue }
        return $true
    }
    return $false
}

function Test-ScheduledTaskFast ([string]$TaskName) {
    return (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$TaskName")
}

function Initialize-HardwareCache {
    $procs = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
    $cores = ($procs | Measure-Object -Property NumberOfCores -Sum).Sum
    $threads = ($procs | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    if (-not $cores -or $cores -lt 1) { $cores = [Environment]::ProcessorCount }
    if (-not $threads -or $threads -lt 1) { $threads = [Environment]::ProcessorCount }

    $totalMask = if ($threads -ge 64) { [uint64]::MaxValue } else { ([uint64]1 -shl [int]$threads) - [uint64]1 }
    # Remove EXCLUSIVAMENTE a CPU lógica 0 (bit 0)
    $targetMask = if ($threads -gt 1) { $totalMask -band (-bnot ([uint64]1)) } else { $totalMask }

    $ramBytes = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
    $ramKB = if ($ramBytes -gt 0) { [int64]($ramBytes / 1KB) } else { [int64]16777216 }

    $hasNv = ((Get-ServiceStartModeFast "NVDisplay.ContainerLocalSystem") -ne -1) -or ((Get-ServiceStartModeFast "NvContainerLocalSystem") -ne -1)

    return [PSCustomObject]@{
        Cores      = $cores
        Threads    = $threads
        TargetMask = $targetMask
        HexMask    = ("0x{0:X}" -f $targetMask)
        RamKB      = $ramKB
        HasNvidia  = $hasNv
    }
}

$script:HwInfo = Initialize-HardwareCache
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

# Recuperação de segurança caso a Telemetria NVIDIA tenha sido interrompida por queda de energia/crash
function Restore-NvidiaBackupIfNeeded {
    if (Test-Path $script:NvBackup) {
        try {
            $bkp = Get-Content $script:NvBackup -Raw | ConvertFrom-Json
            foreach ($entry in $bkp) {
                $reg = "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.Name)"
                if (Test-Path $reg) {
                    Set-ItemProperty -Path $reg -Name "Start" -Value ([int]$entry.Start) -Type DWord -Force -ErrorAction SilentlyContinue
                    if ($entry.WasRunning) { Start-Service -Name $entry.Name -ErrorAction SilentlyContinue }
                }
            }
            Remove-Item $script:NvBackup -Force -ErrorAction SilentlyContinue
            Write-BTLog "Estado original dos serviços NVIDIA restaurado a partir do backup de segurança." "OK"
        } catch {}
    }
}

# ==============================================================================
# DICIONÁRIO CENTRALIZADO DE TEXTOS E TOOLTIPS BILÍNGUES (PT-BR & EN)
# ==============================================================================
$script:ControlMeta = @{
    # Coluna Esquerda - Essential
    "ChkActivity"        = @{ PT="Histórico de Atividades - Desativar (?)"; EN="Activity History - Disable (?)";
                              TipPT="O que faz: Desativa a coleta da Linha do Tempo e histórico de arquivos abertos.`nBenefício: Maior privacidade e menos gravações em disco em segundo plano.`nEfeitos: Nenhum impacto negativo no uso diário.";
                              TipEN="What it does: Disables Windows Activity Feed and timeline tracking.`nBenefit: Improved privacy and reduced background disk writes.`nSide effects: None for normal usage." }
    "ChkConsumer"        = @{ PT="Recursos do Consumidor (Apps Sugeridos) - Desativar (?)"; EN="ConsumerFeatures (Silent Bloatware) - Disable (?)";
                              TipPT="O que faz: Impede o Windows de baixar aplicativos patrocinados automaticamente (Candy Crush, TikTok, etc.).`nBenefício: Mantém o sistema limpo e economiza banda e espaço.`nEfeitos: Nenhum.";
                              TipEN="What it does: Stops Windows from silently installing sponsored Store apps.`nBenefit: Prevents bloatware and saves disk/bandwidth.`nSide effects: None." }
    "ChkDelivery"        = @{ PT="Otimização de Entrega (Updates P2P) - Desativar (?)"; EN="Delivery Optimization (P2P Updates) - Disable (?)";
                              TipPT="O que faz: Desativa o envio peer-to-peer (P2P) de atualizações do Windows para outros PCs na internet.`nBenefício: Evita picos de ping e uso oculto do seu upload durante jogos.`nEfeitos: Atualizações vêm apenas dos servidores oficiais da Microsoft.";
                              TipEN="What it does: Disables P2P uploading of Windows Updates to other PCs.`nBenefit: Prevents random ping spikes and hidden upload usage.`nSide effects: Updates download directly from Microsoft servers." }
    "ChkEndTask"         = @{ PT="Finalizar Tarefa na Barra de Tarefas - Ativar (?)"; EN="End Task With Right Click on Taskbar - Enable (?)";
                              TipPT="O que faz: Adiciona a opção 'Finalizar tarefa' ao clicar com botão direito em apps abertos na Barra de Tarefas (Win 11).`nBenefício: Fecha jogos ou apps travados sem precisar abrir o Gerenciador de Tarefas.`nEfeitos: Apenas para Windows 11.";
                              TipEN="What it does: Adds 'End task' directly to the Taskbar right-click menu (Win 11).`nBenefit: Quickly force-close frozen apps or games.`nSide effects: Windows 11 only." }
    "ChkFolderDisc"      = @{ PT="Descoberta Automática de Pastas do Explorer - Desativar (?)"; EN="File Explorer Automatic Folder Discovery - Disable (?)";
                              TipPT="O que faz: Impede o Explorer de tentar adivinhar se cada pasta é de Música, Vídeos ou Imagens.`nBenefício: Pastas com milhares de arquivos abrem instantaneamente.`nEfeitos: Todas as pastas usam o layout padrão 'Itens Gerais'.";
                              TipEN="What it does: Stops Explorer from scanning folders to guess media type.`nBenefit: Much faster folder loading in File Explorer.`nSide effects: Folders default to General Items view." }
    "ChkHibernation"     = @{ PT="Hibernação do Sistema - Desativar (?)"; EN="Hibernation - Disable (?)";
                              TipPT="O que faz: Desativa a hibernação e remove o arquivo oculto hiberfil.sys.`nBenefício: Libera vários GBs no SSD (geralmente 40% da sua RAM) e reduz desgaste de escrita.`nEfeitos: Desativa o recurso Fast Startup (Inicialização Rápida).";
                              TipEN="What it does: Disables hibernation and deletes hiberfil.sys.`nBenefit: Frees several GBs on your SSD and reduces SSD wear.`nSide effects: Also disables Windows Fast Startup." }
    "ChkLocation"        = @{ PT="Rastreamento de Localização - Desativar (?)"; EN="Location Tracking - Disable (?)";
                              TipPT="O que faz: Bloqueia o acesso global de geolocalização do sistema.`nBenefício: Mais privacidade e menos serviços em segundo plano.`nEfeitos: Apps de Clima/Mapas exigirão definir a cidade manualmente.";
                              TipEN="What it does: Denies global system geolocation access.`nBenefit: Better privacy and fewer background polls.`nSide effects: Weather/Maps apps require manual city selection." }
    "ChkStoreSearch"     = @{ PT="Resultados da Microsoft Store na Busca - Desativar (?)"; EN="Microsoft Store Search Results - Disable (?)";
                              TipPT="O que faz: Remove a sugestão 'Procurar um aplicativo na Microsoft Store' ao abrir arquivos desconhecidos.`nBenefício: Interface mais limpa e sem pop-ups da loja.`nEfeitos: Nenhum.";
                              TipEN="What it does: Removes 'Look for an app in the Microsoft Store' prompts.`nBenefit: Cleaner open-with experience.`nSide effects: None." }
    "ChkDeviceCompanion" = @{ PT="Impedir Apps Complementares de Dispositivos - Ativar (?)"; EN="Prevent Device Companion Apps - Enable (?)";
                              TipPT="O que faz: Bloqueia o download automático de metadados e softwares de fabricantes (Razer Synapse, Logitech, Armoury Crate) via Windows Update.`nBenefício: Evita bloatware automático ao conectar mouse/teclado.`nEfeitos: Instale drivers opcionais manualmente se precisar.";
                              TipEN="What it does: Prevents Windows from auto-installing vendor companion apps (Razer/Logitech/ASUS) when plugging peripherals.`nBenefit: Stops unwanted background bloatware.`nSide effects: Install peripheral software manually if needed." }
    "ChkServicesMan"     = @{ PT="Serviços em Segundo Plano - Definir como Manual (?)"; EN="Background Services - Set to Manual (?)";
                              TipPT="O que faz: Altera 10 serviços secundários seguros (Fax, Mapas, Relatório de Erros, Demonstração, Registro Remoto, etc.) para Manual.`nBenefício: Reduz processos ativos no boot e consumo de RAM.`nEfeitos: Nenhum serviço essencial do Windows é afetado.";
                              TipEN="What it does: Sets 10 safe non-essential services (Fax, MapsBroker, WerSvc, RetailDemo, etc.) to Manual.`nBenefit: Fewer background processes at boot.`nSide effects: Core Windows features remain intact." }
    "ChkTelemetry"       = @{ PT="Telemetria e Coleta de Dados - Desativar (?)"; EN="Telemetry & Data Collection - Disable (?)";
                              TipPT="O que faz: Define AllowTelemetry=0 e desativa os serviços DiagTrack e dmwappushservice.`nBenefício: Menos tráfego de rede e CPU em segundo plano.`nEfeitos: Pode desativar o programa Windows Insider.";
                              TipEN="What it does: Sets AllowTelemetry=0 and disables DiagTrack services.`nBenefit: Less background CPU/network overhead and better privacy.`nSide effects: May disable Windows Insider builds." }
    "ChkWidgets"         = @{ PT="Widgets da Barra de Tarefas - Remover (?)"; EN="Widgets (News & Interests) - Remove (?)";
                              TipPT="O que faz: Desativa o painel de Widgets e Notícias da Barra de Tarefas.`nBenefício: Encerra processos WebView2 que consomem RAM continuamente.`nEfeitos: Remove o botão de clima/notícias da barra.";
                              TipEN="What it does: Disables Taskbar Widgets / News and Interests.`nBenefit: Frees RAM used by background WebView2 processes.`nSide effects: Removes weather/news widget from taskbar." }
    "ChkWPBT"            = @{ PT="Tabela Binária da Plataforma (WPBT) - Desativar (?)"; EN="Windows Platform Binary Table (WPBT) - Disable (?)";
                              TipPT="O que faz: Impede que o BIOS/UEFI da placa-mãe injete executáveis de fabricantes no Windows durante o boot.`nBenefício: Mais segurança e boot limpo.`nEfeitos: Nenhum.";
                              TipEN="What it does: Blocks motherboard firmware from injecting vendor software during Windows boot.`nBenefit: Cleaner boot and better security.`nSide effects: None." }
    "ChkSearchIdx"       = @{ PT="Indexação do Windows Search - Desativar (?)"; EN="Windows Search Indexing - Disable (?)";
                              TipPT="O que faz: Desativa o serviço WSearch de indexação contínua de arquivos.`nBenefício: Elimina picos de leitura/escrita no disco durante jogos.`nEfeitos: A busca por conteúdo dentro de arquivos no Explorer fica mais lenta.";
                              TipEN="What it does: Disables the WSearch continuous file indexing service.`nBenefit: Eliminates background disk I/O spikes during gaming.`nSide effects: File content searches in Explorer become slower." }

    # Coluna Esquerda - Advanced
    "ChkBgApps"          = @{ PT="Aplicativos da Loja em Segundo Plano - Desativar (?)"; EN="Background Store Apps - Disable (?)";
                              TipPT="O que faz: Impede apps UWP da Microsoft Store de rodarem ocultos em segundo plano.`nBenefício: Menor consumo de RAM e CPU.`nEfeitos: Notificações de apps da Store (ex.: Mail/Clima) só aparecem ao abri-los.";
                              TipEN="What it does: Prevents Microsoft Store UWP apps from running in the background.`nBenefit: Lower RAM/CPU usage.`nSide effects: Store app notifications only update when opened." }
    "ChkOptTasks"        = @{ PT="Tarefas Agendadas de Telemetria - Desativar (?)"; EN="Optional Telemetry Scheduled Tasks - Disable (?)";
                              TipPT="O que faz: Desativa tarefas agendadas de coleta (Compatibility Appraiser, CEIP, UsbCeip, Feedback).`nBenefício: Evita uso repentino de disco/CPU no meio do jogo.`nEfeitos: Nenhum impacto no sistema.";
                              TipEN="What it does: Disables scheduled telemetry tasks (Compatibility Appraiser, CEIP, UsbCeip, Feedback).`nBenefit: Prevents sudden background CPU/disk spikes.`nSide effects: None." }
    "ChkReservedStorage" = @{ PT="Armazenamento Reservado do Windows - Desativar (?)"; EN="Windows Reserved Storage - Disable (?)";
                              TipPT="O que faz: Desativa a reserva automática de ~7 GB usada pelo Windows Update.`nBenefício: Libera espaço valioso no SSD.`nEfeitos: Mantenha ao menos 10 GB livres ao instalar grandes updates do Windows.";
                              TipEN="What it does: Disables the ~7 GB storage partition reserved for Windows Updates.`nBenefit: Reclaims SSD space.`nSide effects: Keep ~10 GB free before installing major feature updates." }
    "ChkExplorerGallery" = @{ PT="Galeria e Início no Explorer (Win 11) - Ocultar (?)"; EN="File Explorer Home & Gallery (Win 11) - Hide (?)";
                              TipPT="O que faz: Remove os atalhos 'Galeria' e 'Início' do painel esquerdo do Explorer via HKCU (100% reversível).`nBenefício: Explorer mais limpo, rápido e direto em 'Este Computador'.`nEfeitos: Apenas estético; reversível a qualquer momento.";
                              TipEN="What it does: Hides Gallery and Home clutter from the Win 11 Explorer sidebar safely via HKCU.`nBenefit: Cleaner, snappier File Explorer.`nSide effects: Cosmetic only; fully reversible." }
    "ChkGameDVR"         = @{ PT="GameDVR e Captura Xbox - Desativar (?)"; EN="GameDVR & Xbox Background Capture - Disable (?)";
                              TipPT="O que faz: Desativa a gravação automática em segundo plano da Game Bar.`nBenefício: Reduz input lag, melhora 1% Low FPS e economiza recursos da GPU.`nEfeitos: Desativa gravação de clipes pela tecla Win+Alt+G.";
                              TipEN="What it does: Disables Xbox Game Bar background recording.`nBenefit: Lower input lag and smoother frame times.`nSide effects: Disables Win+Alt+G background clip recording." }
    "ChkIPv4Pref"        = @{ PT="Rede IPv6 - Definir IPv4 como Preferencial (?)"; EN="IPv6 - Set IPv4 as Preferred (?)";
                              TipPT="O que faz: Define DisabledComponents=32 para priorizar IPv4 sem quebrar a pilha IPv6.`nBenefício: Evita atrasos de resolução DNS em provedores com IPv6 mal roteado.`nEfeitos: Seguro; mantém compatibilidade com todos os serviços do Windows.";
                              TipEN="What it does: Sets DisabledComponents=32 to prefer IPv4 without breaking IPv6.`nBenefit: Avoids DNS routing delays on unstable IPv6 ISPs.`nSide effects: Safe and Microsoft-recommended method." }
    "ChkTeredo"          = @{ PT="Túnel Teredo IPv6 - Desativar (?)"; EN="Teredo Tunneling - Disable (?)";
                              TipPT="O que faz: Desativa a interface de tunelamento legado Teredo via netsh.`nBenefício: Reduz sobrecarga de rede e superfície de exposição.`nEfeitos: Pode afetar Xbox Party Chat ou multiplayer em jogos antigos da Xbox Live (ex.: Forza Horizon 4).";
                              TipEN="What it does: Disables legacy Teredo IPv6 tunneling via netsh.`nBenefit: Cleaner network stack.`nSide effects: May affect Xbox Party Chat or older Xbox Live P2P games." }
    "ChkMenuDelay"       = @{ PT="Atraso de Menus (Zero Delay 0ms) - Ativar (?)"; EN="MenuShowDelay (Zero Delay 0ms) - Enable (?)";
                              TipPT="O que faz: Muda MenuShowDelay de 400ms para 0ms.`nBenefício: Menus e submenus do Windows abrem instantaneamente.`nEfeitos: Nenhum.";
                              TipEN="What it does: Changes MenuShowDelay from 400ms to 0ms.`nBenefit: Menus open instantaneously.`nSide effects: None." }
    "ChkEdgeDebloat"     = @{ PT="Processos em Segundo Plano do Edge - Desativar (?)"; EN="Microsoft Edge Background Processes - Disable (?)";
                              TipPT="O que faz: Desativa Startup Boost e execução em segundo plano do Edge via Políticas.`nBenefício: Impede o Edge de ficar consumindo RAM após fechar o navegador.`nEfeitos: A primeira abertura do Edge leva uma fração de segundo a mais.";
                              TipEN="What it does: Disables Edge Startup Boost and Background Mode via Policies.`nBenefit: Stops Edge from consuming RAM after closing.`nSide effects: Slightly slower cold launch of Edge." }
    "ChkNetThrottle"     = @{ PT="Limitação de Rede (Network Throttling) - Otimizar (?)"; EN="Network Throttling Index - Optimize (?)";
                              TipPT="O que faz: Define NetworkThrottlingIndex=0xFFFFFFFF e SystemResponsiveness=0.`nBenefício: Remove o limite de 10 pacotes/ms em tarefas multimídia para menor latência em jogos.`nEfeitos: Nenhum negativo em PCs modernos.";
                              TipEN="What it does: Sets NetworkThrottlingIndex=0xFFFFFFFF and SystemResponsiveness=0.`nBenefit: Removes Windows multimedia packet throttling for gaming.`nSide effects: None on modern PCs." }
    "ChkPowerThrottle"   = @{ PT="Estrangulamento de Energia (Power Throttling) - Desativar (?)"; EN="Power Throttling - Disable (?)";
                              TipPT="O que faz: Define PowerThrottlingOff=1 no controle de energia da CPU.`nBenefício: Evita que o Windows reduza o clock de processos ou jogos em segundo plano.`nEfeitos: Pode aumentar levemente o consumo de bateria em notebooks.";
                              TipEN="What it does: Sets PowerThrottlingOff=1.`nBenefit: Prevents Windows from downclocking processes/games.`nSide effects: Slightly higher battery drain on laptops." }
    "ChkClassicContext"  = @{ PT="Menu de Contexto Clássico (Win 11) - Ativar (?)"; EN="Right-Click Menu Classic Layout (Win 11) - Enable (?)";
                              TipPT="O que faz: Restaura o menu de botão direito completo no Windows 11.`nBenefício: Elimina o clique extra em 'Mostrar mais opções'.`nEfeitos: Requer reiniciar o Explorer ou o PC para surtir efeito.";
                              TipEN="What it does: Restores the full classic right-click context menu on Win 11.`nBenefit: No more clicking 'Show more options'.`nSide effects: Requires Explorer restart or reboot." }
    "ChkStorageSense"    = @{ PT="Sensor de Armazenamento Automático - Desativar (?)"; EN="Storage Sense Automatic Cleanup - Disable (?)";
                              TipPT="O que faz: Desativa a varredura periódica automática de disco do Windows.`nBenefício: Evita uso inesperado de SSD em segundo plano.`nEfeitos: Use a Limpeza de Disco (cleanmgr) quando quiser limpar.";
                              TipEN="What it does: Disables automatic periodic Storage Sense scans.`nBenefit: Prevents unexpected background disk usage.`nSide effects: Run Disk Cleanup manually when needed." }
    "ChkSvcHost"         = @{ PT="Divisão de Processos SvcHost - Ajustar para sua RAM (?)"; EN="SvcHost Split Threshold - Match Physical RAM (?)";
                              TipPT="O que faz: Ajusta SvcHostSplitThresholdInKB exatamente para a quantidade de RAM instalada.`nBenefício: Reduz dezenas de processos svchost.exe fragmentados no Gerenciador de Tarefas.`nEfeitos: Requer reinicialização; 100% reversível.";
                              TipEN="What it does: Matches SvcHostSplitThresholdInKB to your installed physical RAM.`nBenefit: Reduces fragmented svchost.exe process count.`nSide effects: Requires reboot; fully reversible." }
    "ChkUsbSuspend"      = @{ PT="Suspensão Seletiva USB - Desativar (?)"; EN="USB Selective Suspend - Disable (?)";
                              TipPT="O que faz: Impede o Windows de desligar portas USB ociosas para economizar energia.`nBenefício: Evita micro-travamentos ou desconexões em mouses 1000Hz/4000Hz/8000Hz e headsets USB.`nEfeitos: Leve aumento de consumo em notebooks na bateria.";
                              TipEN="What it does: Prevents Windows from powering down idle USB ports.`nBenefit: Eliminates micro-stutters/disconnects on high-polling gaming mice and headsets.`nSide effects: Minor battery impact on laptops." }
    "ChkBestPerf"        = @{ PT="Efeitos Visuais - Ajustar para Melhor Desempenho (?)"; EN="Visual Effects - Set to Best Performance (?)";
                              TipPT="O que faz: Desativa animações pesadas de janelas e transparências desnecessárias.`nBenefício: Resposta de interface instantânea e menor carga no DWM.`nEfeitos: Janelas abrem sem animação suave.";
                              TipEN="What it does: Disables heavy window animations and shadows.`nBenefit: Snappier desktop and lower DWM overhead.`nSide effects: Removes fade/slide window animations." }
    "ChkWinAI"           = @{ PT="Windows AI (Copilot e Recall) - Desativar (?)"; EN="Windows AI (Copilot & Recall) - Disable (?)";
                              TipPT="O que faz: Desativa políticas do Windows Copilot e impede capturas de tela do Windows Recall.`nBenefício: Economiza RAM, privacidade total e menos processos IA em segundo plano.`nEfeitos: Remove o botão e atalho do Copilot.";
                              TipEN="What it does: Disables Windows Copilot and blocks Windows Recall snapshots via policy.`nBenefit: Better privacy and lower RAM usage.`nSide effects: Removes Copilot integration." }

    # Coluna Esquerda - Security & CPU Overhead (Requer Confirmação Explícita)
    "ChkBitLocker"       = @{ PT="BitLocker (Criptografia de Disco) - Desativar [CONFIRMAÇÃO] (?)"; EN="BitLocker (Drive Encryption) - Disable [CONFIRM] (?)";
                              TipPT="O que faz: Descriptografa a unidade do sistema (C:) se o BitLocker estiver ativo.`nBenefício: Pode aumentar a velocidade de leitura/escrita aleatória em SSDs NVMe.`nRISCO: Seus arquivos ficam sem criptografia em caso de roubo físico do PC. Processo pode levar vários minutos.";
                              TipEN="What it does: Decrypts the system drive (C:) if BitLocker is enabled.`nBenefit: Can improve random NVMe SSD read/write latency.`nRISK: Drive data is unencrypted if the PC is physically stolen. Decryption takes several minutes." }
    "ChkHVCI"            = @{ PT="HVCI (Integridade de Memória / Core Isolation) - Desativar [REINICIAR] (?)"; EN="HVCI (Memory Integrity / Core Isolation) - Disable [RESTART] (?)";
                              TipPT="O que faz: Desativa a Integridade de Memória baseada em virtualização (HVCI).`nBenefício: Ganhos reais de 5% a 15% de FPS em jogos competitivos e menor latência de CPU.`nRISCO/COMPATIBILIDADE: Reduz proteção contra drivers maliciosos. ATENÇÃO: VALORANT (Vanguard) ou FACEIT podem exigir HVCI ativo em algumas contas/hardware.";
                              TipEN="What it does: Disables Hypervisor-Protected Code Integrity (HVCI).`nBenefit: Measurable 5-15% FPS gain and lower CPU latency.`nRISK/COMPATIBILITY: Lower kernel driver protection. WARNING: VALORANT Vanguard or FACEIT may require HVCI enabled on certain systems." }
    "ChkCpuMitigations"  = @{ PT="Mitigações de CPU (Spectre/Meltdown) - Desativar [REINICIAR] (?)"; EN="CPU Mitigations (Spectre/Meltdown) - Disable [RESTART] (?)";
                              TipPT="O que faz: Define FeatureSettingsOverride=3 e Mask=3 para desativar mitigações de software Spectre v2 e Meltdown.`nBenefício: Reduz overhead de chamadas de sistema (syscalls) e melhora FPS mínimo em CPUs mais antigas ou cargas pesadas.`nRISCO: Reduz proteção contra vulnerabilidades de execução especulativa. Requer reinicialização; 100% reversível.";
                              TipEN="What it does: Sets FeatureSettingsOverride=3 & Mask=3 to disable Spectre v2 / Meltdown software mitigations.`nBenefit: Reduces syscall overhead and improves 1% low FPS.`nRISK: Lowers protection against speculative execution side-channel attacks. Requires reboot; fully reversible." }

    # Coluna Direita - Toggle Switches
    "TglBsod"            = @{ PT="Tela Azul Detalhada (BSoD Verbose)"; EN="BSoD Verbose Mode"; TipPT="Exibe códigos técnicos detalhados em caso de Tela Azul."; TipEN="Shows detailed technical parameters on Blue Screen errors." }
    "TglDarkWin"         = @{ PT="Tema Escuro para o Windows"; EN="Dark Theme for Windows"; TipPT="Alterna o tema escuro nativo do Windows e aplicativos."; TipEN="Toggles Windows native Dark Mode for system and apps." }
    "TglLongPaths"       = @{ PT="Habilitar Caminhos Longos (>260 caracteres)"; EN="Enable Long Paths (>260 chars)"; TipPT="Remove o limite legado de 260 caracteres em nomes de pastas/arquivos."; TipEN="Removes legacy 260-character file path limit." }
    "TglFastStart"       = @{ PT="Inicialização Rápida (Fast Startup)"; EN="Fast Startup (Hiberboot)"; TipPT="Desativar garante um desligamento completo do kernel (recomendado para estabilidade em jogos)."; TipEN="Disabling ensures a full clean kernel reboot (recommended for gaming stability)." }
    "TglFileExt"         = @{ PT="Mostrar Extensões de Arquivos no Explorer"; EN="File Explorer File Extensions"; TipPT="Exibe .exe, .zip, .ps1 no Windows Explorer (útil para segurança)."; TipEN="Shows file extensions like .exe and .zip in Explorer." }
    "TglHiddenFiles"     = @{ PT="Mostrar Arquivos Ocultos no Explorer"; EN="File Explorer Hidden Files"; TipPT="Exibe pastas ocultas como AppData e ProgramData."; TipEN="Reveals hidden system folders like AppData and ProgramData." }
    "TglGameMode"        = @{ PT="Modo de Jogo (Game Mode)"; EN="Game Mode"; TipPT="Prioriza recursos de CPU/GPU para jogos e pausa updates durante partidas."; TipEN="Prioritizes CPU/GPU for games and suppresses updates while playing." }
    "TglAcrylic"         = @{ PT="Desfoque Acrílico na Tela de Login"; EN="Logon Screen Acrylic Blur"; TipPT="Ativa ou remove o efeito de desfoque na tela de bloqueio."; TipEN="Toggles the acrylic blur effect on the Windows sign-in screen." }
    "TglVerboseLogon"    = @{ PT="Mensagens Detalhadas de Inicialização/Logon"; EN="Logon Verbose Mode"; TipPT="Exibe qual serviço exato está iniciando ou encerrando durante o boot."; TipEN="Displays detailed status messages during startup and shutdown." }
    "TglMouseAccel"      = @{ PT="Aceleração do Ponteiro do Mouse"; EN="Mouse Acceleration"; TipPT="Desative para precisão linear 1:1 em jogos competitivos de FPS."; TipEN="Turn OFF for true 1:1 raw linear mouse movement in FPS games." }
    "TglMmProfile"       = @{ PT="Perfil Multimídia de Jogos (MMCSS)"; EN="Multimedia Gaming Profile (MMCSS)"; TipPT="Define GPU Priority=8, Priority=6 e Scheduling Category=High para jogos."; TipEN="Sets GPU Priority=8, Priority=6, and High scheduling category for games." }
    "TglNumLock"         = @{ PT="Ativar Num Lock ao Ligar"; EN="Num Lock on Startup"; TipPT="Mantém o teclado numérico ativado automaticamente no boot."; TipEN="Automatically enables Num Lock when Windows starts." }
    "TglBingSearch"      = @{ PT="Pesquisa Web do Bing no Menu Iniciar"; EN="Start Menu Bing Search"; TipPT="Desative para deixar a busca do Menu Iniciar 100% local e instantânea."; TipEN="Turn OFF to make Start Menu search 100% local and instant." }
    "TglStartRecs"       = @{ PT="Recomendações no Menu Iniciar"; EN="Start Menu Recommendations"; TipPT="Desative para remover arquivos recentes e sugestões do Menu Iniciar."; TipEN="Turn OFF to hide recommended files and tips in Start Menu." }
    "TglStickyKeys"      = @{ PT="Atalho das Teclas de Aderência (5x Shift)"; EN="Sticky Keys Shortcut (5x Shift)"; TipPT="Desative para nunca mais abrir o alerta irritante ao apertar Shift 5 vezes jogando."; TipEN="Turn OFF to prevent the popup when pressing Shift 5 times in-game." }
    "TglCenterTaskbar"   = @{ PT="Ícones Centralizados na Barra de Tarefas"; EN="Taskbar Centered Icons"; TipPT="Alterna os ícones da Barra de Tarefas do Win 11 entre Centro e Esquerda."; TipEN="Switches Win 11 taskbar alignment between Center and Left." }
    "TglSearchIcon"      = @{ PT="Ícone de Pesquisa na Barra de Tarefas"; EN="Taskbar Search Icon"; TipPT="Mostra ou oculta a lupa/caixa de pesquisa na Barra de Tarefas."; TipEN="Shows or hides the search box/icon on the taskbar." }
    "TglTaskView"        = @{ PT="Botão Visão de Tarefas na Barra"; EN="Taskbar Task View Icon"; TipPT="Mostra ou oculta o botão de múltiplas áreas de trabalho."; TipEN="Shows or hides the Task View button on the taskbar." }
    "TglSnap"            = @{ PT="Ajuste Automático de Janelas (Window Snap)"; EN="Window Snapping"; TipPT="Permite encaixar janelas nas bordas da tela ao arrastá-las."; TipEN="Toggles automatic window snapping to screen edges." }
}

# ==============================================================================
# SISTEMA DE IDIOMA INSTANTÂNEO (EN | PT-BR) + ATUALIZAÇÃO DE TODOS OS TOOLTIPS
# ==============================================================================
$script:Lang = if ((Get-UICulture).Name -like "pt*") { "PT" } else { "EN" }

function Refresh-CachedStatusLabels {
    $exe = $script:GameStateCache.Exe
    $valExtraPT = if ($script:GameStateCache.IsValorant) { " + Auto-Encerrar RiotClient" } else { "" }
    $valExtraEN = if ($script:GameStateCache.IsValorant) { " + Auto-Close RiotClient" } else { "" }

    if ($script:Lang -eq "PT") {
        $LblCpuTopology.Text = "CPU: $($script:HwInfo.Cores) Núcleos / $($script:HwInfo.Threads) Threads"
        $LblCpuMaskInfo.Text = "Máscara s/ CPU 0: $($script:HwInfo.HexMask)"

        $StatusDscp.Text = if ($script:GameStateCache.Dscp) { "Status: ATIVADO (Prioridade de rede DSCP 46 ativa)" } else { "Status: Desativado" }
        $StatusAffinity.Text = if ($script:GameStateCache.Affinity) { "Status: ATIVADO (Sem CPU 0 [$($script:HwInfo.HexMask)]$valExtraPT)" } else { "Status: Desativado" }
        $StatusDx11.Text = switch ($script:GameStateCache.Dx11State) {
            "APPLIED"  { "Status: ATIVADO no Registro (Flags 211 aplicado)" }
            "WATCHING" { "Status: MONITORANDO (Aplicação automática na próxima abertura)" }
            default    { "Status: Desativado" }
        }
        $StatusNvTel.Text = if (-not $script:HwInfo.HasNvidia) {
            "Status: Indisponível (Serviços NVIDIA não detectados neste PC)"
        } elseif ($script:GameStateCache.NvTel) {
            "Status: ATIVADO (Pausa serviços NVIDIA ao jogar e restaura ao fechar)"
        } else {
            "Status: Desativado"
        }
        $StatusWinUpdateCard.Text = if ($script:WinUpdateDisabledCache) { "Status: Desativado (Serviços wuauserv/UsoSvc bloqueados)." } else { "Status: Ativo (Padrão do Windows)." }
    } else {
        $LblCpuTopology.Text = "CPU: $($script:HwInfo.Cores) Cores / $($script:HwInfo.Threads) Threads"
        $LblCpuMaskInfo.Text = "No-CPU0 Mask: $($script:HwInfo.HexMask)"

        $StatusDscp.Text = if ($script:GameStateCache.Dscp) { "Status: ENABLED (DSCP 46 network priority active)" } else { "Status: Disabled" }
        $StatusAffinity.Text = if ($script:GameStateCache.Affinity) { "Status: ENABLED (No-CPU0 [$($script:HwInfo.HexMask)]$valExtraEN)" } else { "Status: Disabled" }
        $StatusDx11.Text = switch ($script:GameStateCache.Dx11State) {
            "APPLIED"  { "Status: ENABLED in Registry (Flags 211 applied)" }
            "WATCHING" { "Status: WATCHING (Auto-applies on next game launch)" }
            default    { "Status: Disabled" }
        }
        $StatusNvTel.Text = if (-not $script:HwInfo.HasNvidia) {
            "Status: Unavailable (NVIDIA services not detected on this PC)"
        } elseif ($script:GameStateCache.NvTel) {
            "Status: ENABLED (Pauses NVIDIA services in-game & restores on exit)"
        } else {
            "Status: Disabled"
        }
        $StatusWinUpdateCard.Text = if ($script:WinUpdateDisabledCache) { "Status: Disabled (wuauserv/UsoSvc blocked)." } else { "Status: Active (Windows Default)." }
    }
}

function Set-AppLanguage ([string]$langCode) {
    $script:Lang = $langCode

    # Aplica Textos e ToolTips de todos os controles do dicionário (< 3ms)
    foreach ($key in $script:ControlMeta.Keys) {
        $ctrl = Get-Variable -Name $key -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $ctrl) {
            $meta = $script:ControlMeta[$key]
            $ctrl.Content = if ($langCode -eq "PT") { $meta.PT } else { $meta.EN }
            $ctrl.ToolTip = if ($langCode -eq "PT") { $meta.TipPT } else { $meta.TipEN }
        }
    }

    if ($langCode -eq "PT") {
        $BtnLangPT.Background = "#7C3AED"; $BtnLangPT.BorderBrush = "#A78BFA"
        $BtnLangEN.Background = "Transparent"; $BtnLangEN.BorderBrush = "Transparent"

        $BtnNavTweaks.Content = "Otimizações"; $BtnNavGaming.Content = "Gaming"; $BtnNavAdvanced.Content = "Avançado"
        $LblSearchPlaceholder.Text = "Pesquisar otimização ou preferência..."
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
        $BtnUltDisable.Content = "Perfil Desempenho Máximo - Desativar (Equilibrado)"
        $BtnUltEnable.Content = "Perfil Desempenho Máximo - Ativar (Ultimate)"

        # Aba Gaming (Nomes limpos e orientados aos benefícios)
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
        $DescAffinity.Text = "Aplica prioridade Alta e libera automaticamente a CPU lógica 0 ao iniciar o jogo. No VALORANT, também encerra o RiotClientServices em segundo plano."
        $HdrDx11.Text = "Remover Latência de Tela Cheia"
        $DescDx11.Text = "Ajusta o comportamento de tela cheia exclusiva (DX11) no registro para reduzir input lag apenas para o jogo selecionado."
        $HdrNvTel.Text = "Desativar Telemetria NVIDIA"
        $DescNvTel.Text = "Pausa automaticamente os serviços de container/telemetria NVIDIA enquanto o jogo está aberto e restaura exatamente o estado original ao fechar."

        $HdrAdvTabTitle.Text = "Avançado"
        $HdrWinUpdateCard.Text = "Windows Update"
        $DescWinUpdateCard.Text = "Desativa os serviços de atualização (wuauserv, UsoSvc) e bloqueia reinicializações automáticas. Restaurar devolve o comportamento original do Windows."
        $BtnDisableWinUpdate.Content = "Desativar Windows Update"
        $BtnRestoreWinUpdate.Content = "Restaurar Windows Update"
        $HdrNetResetCard.Text = "Manutenção do Sistema e Pilha de Rede"
        $DescNetResetCard.Text = "Abra a ferramenta nativa de Limpeza de Disco do Windows (cleanmgr.exe), limpe caches temporários ou redefina a pilha de rede Winsock/DNS."
        $BtnAdvCleanmgr.Content = "Abrir Limpeza de Disco (cleanmgr)"
        $BtnAdvCleanCache.Content = "Limpar Temp e Prefetch"
        $BtnAdvFlushNet.Content = "Resetar Rede e Limpar DNS"

        $LblFooterNote.Text = "Nota: Passe o mouse sobre qualquer opção (?) para ver detalhes, benefícios e riscos. Alterações de segurança exigem confirmação."
        $BtnRunTweaks.Content = "Aplicar Otimizações"
        $BtnUndoTweaks.Content = "Reverter Selecionadas"
    } else {
        $BtnLangEN.Background = "#7C3AED"; $BtnLangEN.BorderBrush = "#A78BFA"
        $BtnLangPT.Background = "Transparent"; $BtnLangPT.BorderBrush = "Transparent"

        $BtnNavTweaks.Content = "Tweaks"; $BtnNavGaming.Content = "Gaming"; $BtnNavAdvanced.Content = "Advanced"
        $LblSearchPlaceholder.Text = "Search tweaks or preferences..."
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
        $BtnUltDisable.Content = "Ultimate Performance Profile - Disable"
        $BtnUltEnable.Content = "Ultimate Performance Profile - Enable"

        # Gaming Tab (Clean, benefit-oriented names)
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
        $DescAffinity.Text = "Automatically applies High priority and unchecks Logical CPU 0 when the game starts. For VALORANT, also closes RiotClientServices in the background."
        $HdrDx11.Text = "Remove Fullscreen Latency"
        $DescDx11.Text = "Applies targeted DX11 fullscreen optimization flags exclusively for the selected game to lower display input lag."
        $HdrNvTel.Text = "Disable NVIDIA Telemetry"
        $DescNvTel.Text = "Automatically pauses NVIDIA container/telemetry services while the game runs and restores their exact original state when you exit."

        $HdrAdvTabTitle.Text = "Advanced"
        $HdrWinUpdateCard.Text = "Windows Update"
        $DescWinUpdateCard.Text = "Disables Windows Update services (wuauserv, UsoSvc) and prevents forced automatic restarts. Restore returns services to original settings."
        $BtnDisableWinUpdate.Content = "Disable Windows Update"
        $BtnRestoreWinUpdate.Content = "Restore Windows Update"
        $HdrNetResetCard.Text = "System Maintenance & Network Stack"
        $DescNetResetCard.Text = "Launch the official Windows Disk Cleanup utility (cleanmgr.exe), purge temporary caches, or reset the Winsock/TCP-IP network stack."
        $BtnAdvCleanmgr.Content = "Launch Disk Cleanup (cleanmgr)"
        $BtnAdvCleanCache.Content = "Purge Temp & Prefetch"
        $BtnAdvFlushNet.Content = "Reset Network & Flush DNS"

        $LblFooterNote.Text = "Note: Hover over any option (?) to view details, benefits, and risks. Security changes require explicit confirmation."
        $BtnRunTweaks.Content = "Apply Selected Tweaks"
        $BtnUndoTweaks.Content = "Revert Selected Tweaks"
    }
    Refresh-CachedStatusLabels
}

$BtnLangEN.Add_Click({ Set-AppLanguage "EN" })
$BtnLangPT.Add_Click({ Set-AppLanguage "PT" })

# Navegação e Controles da Janela
function Switch-Tab ([string]$tab) {
    $ViewTweaks.Visibility   = if ($tab -eq "Tweaks")   { "Visible" } else { "Collapsed" }
    $ViewGaming.Visibility   = if ($tab -eq "Gaming")   { "Visible" } else { "Collapsed" }
    $ViewAdvanced.Visibility = if ($tab -eq "Advanced") { "Visible" } else { "Collapsed" }

    $BtnNavTweaks.Background   = if ($tab -eq "Tweaks")   { "#7C3AED" } else { "#221E30" }
    $BtnNavGaming.Background   = if ($tab -eq "Gaming")   { "#7C3AED" } else { "#221E30" }
    $BtnNavAdvanced.Background = if ($tab -eq "Advanced") { "#7C3AED" } else { "#221E30" }
}
$BtnNavTweaks.Add_Click({ Switch-Tab "Tweaks" })
$BtnNavGaming.Add_Click({ Switch-Tab "Gaming" })
$BtnNavAdvanced.Add_Click({ Switch-Tab "Advanced" })

$TitleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
$BtnMin.Add_Click({ $window.WindowState = 'Minimized' })
$BtnMax.Add_Click({
    if ($window.WindowState -eq 'Maximized') { $window.WindowState = 'Normal' }
    else { $window.WindowState = 'Maximized' }
})
$BtnClose.Add_Click({ $window.Close() })

$script:isDark = $true
$BtnTheme.Add_Click({
    $script:isDark = -not $script:isDark
    $bc = New-Object System.Windows.Media.BrushConverter
    if ($script:isDark) {
        $window.Resources["BgMain"] = $bc.ConvertFromString("#111017")
        $window.Resources["BgPanel"] = $bc.ConvertFromString("#171520")
        $window.Resources["BgHeader"] = $bc.ConvertFromString("#0C0B10")
        $window.Resources["TextMain"] = $bc.ConvertFromString("#F3F4F6")
        $BtnTheme.Content = "☀"
    } else {
        $window.Resources["BgMain"] = $bc.ConvertFromString("#F5F3FF")
        $window.Resources["BgPanel"] = $bc.ConvertFromString("#FFFFFF")
        $window.Resources["BgHeader"] = $bc.ConvertFromString("#EDE9FE")
        $window.Resources["TextMain"] = $bc.ConvertFromString("#1E1B4B")
        $BtnTheme.Content = "🌙"
    }
})

$TxtSearch.Add_TextChanged({
    $q = $TxtSearch.Text.ToLower()
    foreach ($ctrl in ($PanelLeft.Children + $PanelRight.Children)) {
        if ($ctrl -is [System.Windows.Controls.CheckBox]) {
            $ctrl.Visibility = if ([string]::IsNullOrWhiteSpace($q) -or $ctrl.Content.ToString().ToLower().Contains($q)) { 'Visible' } else { 'Collapsed' }
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
# LISTA DE JOGOS LIMPA (Caminho guardado internamente, sem poluir a UI)
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

function Get-CleanId ([string]$exeName) { return ($exeName -replace '[^a-zA-Z0-9]', '_') }

$BtnAddGame.Add_Click({
    $gName = $TxtCustomGameName.Text.Trim()
    $gExe  = $TxtCustomGameExe.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($gName) -or [string]::IsNullOrWhiteSpace($gExe)) {
        Write-BTLog "Informe o nome do jogo e selecione o executável (.exe)." "WARN"
        return
    }
    $gExe = [System.IO.Path]::GetFileName($gExe)
    if ($gExe -notmatch '^[a-zA-Z0-9_\-\.\s]+\.exe$') {
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
    if ($idx -ge 0) {
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
        Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\BetterTitus_$id" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($sel.Exe)\PerfOptions" -Recurse -Force -ErrorAction SilentlyContinue

        $script:GameList.RemoveAt($idx)
        Save-CustomGames
        if ($script:GameList.Count -gt 0) { $LstGames.SelectedIndex = 0 }
        Write-BTLog "Jogo removido junto com suas tarefas: $($sel.Name)." "OK"
    }
})

# ==============================================================================
# OTIMIZAÇÕES DE GAMING (DSCP 46, AFINIDADE CPU 0, DX11 211, TELEMETRIA NVIDIA)
# ==============================================================================
$script:loadingGameUI = $false

function Update-SelectedGameUI {
    $idx = $LstGames.SelectedIndex
    if ($idx -lt 0 -or $idx -ge $script:GameList.Count) { return }
    $script:loadingGameUI = $true

    $game = $script:GameList[$idx]
    $exe  = $game.Exe
    $id   = Get-CleanId $exe
    $script:GameStateCache.Exe = $exe
    $script:GameStateCache.IsValorant = ($exe -ieq "VALORANT-Win64-Shipping.exe")

    $LblSelectedGameTitle.Text = $game.Name
    $LblSelectedGameExe.Text   = $exe

    # 1. DSCP 46
    $isDscpActive = ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\BetterTitus_$id" "DSCP Value" "") -eq "46")
    $script:GameStateCache.Dscp = $isDscpActive
    $TglGameDscp.IsChecked = $isDscpActive
    $StatusDscp.Foreground = if ($isDscpActive) { "#4ADE80" } else { "#9CA3AF" }

    # 2. Afinidade + Prioridade
    $isAffActive = (Test-ScheduledTaskFast "BetterTitus_Affinity_$id")
    $script:GameStateCache.Affinity = $isAffActive
    $TglGameAffinity.IsChecked = $isAffActive
    $StatusAffinity.Foreground = if ($isAffActive) { "#4ADE80" } else { "#9CA3AF" }

    # 3. DX11 Flags 211
    $gcsChildren = "HKCU:\System\GameConfigStore\Children"
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
    $hasDxTask = Test-ScheduledTaskFast "BetterTitus_DX11Watch_$id"
    if ($dxFlagsVal -eq 0x211 -or $dxFlagsVal -eq 529 -or $dxFlagsVal -eq 211) {
        $script:GameStateCache.Dx11State = "APPLIED"; $TglGameDx11.IsChecked = $true; $StatusDx11.Foreground = "#4ADE80"
    } elseif ($hasDxTask) {
        $script:GameStateCache.Dx11State = "WATCHING"; $TglGameDx11.IsChecked = $true; $StatusDx11.Foreground = "#A78BFA"
    } else {
        $script:GameStateCache.Dx11State = "NONE"; $TglGameDx11.IsChecked = $false; $StatusDx11.Foreground = "#9CA3AF"
    }

    # 4. Telemetria NVIDIA
    $TglGameNvTel.IsEnabled = $script:HwInfo.HasNvidia
    $isNvActive = $script:HwInfo.HasNvidia -and (Test-ScheduledTaskFast "BetterTitus_NvTel_$id")
    $script:GameStateCache.NvTel = $isNvActive
    $TglGameNvTel.IsChecked = $isNvActive
    $StatusNvTel.Foreground = if (-not $script:HwInfo.HasNvidia) { "#F59E0B" } elseif ($isNvActive) { "#4ADE80" } else { "#9CA3AF" }

    Refresh-CachedStatusLabels
    $script:loadingGameUI = $false
}

$LstGames.Add_SelectionChanged({ Update-SelectedGameUI })

# Card 1: Priorizar Rota de Jogo (DSCP 46)
$TglGameDscp.Add_Checked({
    if ($script:loadingGameUI) { return }
    $game = $script:GameList[$LstGames.SelectedIndex]
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
    $game = $script:GameList[$LstGames.SelectedIndex]; $id = Get-CleanId $game.Exe
    Invoke-SafeTweak "Remover Prioridade de Rota ($($game.Exe))" {
        Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\BetterTitus_$id" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Update-SelectedGameUI
})

# Card 2: Prioridade Alta + Afinidade Otimizada (Exclusivamente sem CPU 0 + RiotClient Kill)
$TglGameAffinity.Add_Checked({
    if ($script:loadingGameUI) { return }
    $game = $script:GameList[$LstGames.SelectedIndex]
    $exe = $game.Exe; $procName = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    $id = Get-CleanId $exe; $taskName = "BetterTitus_Affinity_$id"
    $maskU64 = $script:HwInfo.TargetMask
    $ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions"
    $isVal = if ($exe -ieq "VALORANT-Win64-Shipping.exe") { '$true' } else { '$false' }

    Invoke-SafeTweak "Prioridade Alta + Afinidade ($exe | $($script:HwInfo.HexMask))" {
        Set-Reg $ifeoPath "CpuPriorityClass" 3 "DWord"; Set-Reg $ifeoPath "IoPriority" 3 "DWord"
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

        $scriptPath = "$script:ConfigDir\Affinity_$id.ps1"
        $workerCode = @"
`$exeName = '$exe'; `$procBase = '$procName'; `$maskVal = [uint64]$maskU64; `$isValorant = $isVal
function Optimize-RunningTarget {
    `$foundGame = `$false
    for (`$i = 0; `$i -lt 8; `$i++) {
        `$procs = @(Get-Process -Name `$procBase -ErrorAction SilentlyContinue)
        if (`$procs.Count -gt 0) {
            `$foundGame = `$true
            foreach (`$p in `$procs) {
                try { `$p.ProcessorAffinity = [IntPtr]([int64]`$maskVal); `$p.PriorityClass = 'High' } catch {}
            }
        }
        Start-Sleep -Seconds 2
    }
    if (`$isValorant -and `$foundGame) {
        Get-Process -Name 'RiotClientServices' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}
Optimize-RunningTarget
Unregister-Event -SourceIdentifier 'BT_ProcWatch_$id' -ErrorAction SilentlyContinue
try {
    Register-WmiEvent -Query "SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName = '`$exeName'" -SourceIdentifier 'BT_ProcWatch_$id' -ErrorAction Stop
} catch {
    Register-WmiEvent -Query "SELECT * FROM __InstanceCreationEvent WITHIN 2 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = '`$exeName'" -SourceIdentifier 'BT_ProcWatch_$id' -ErrorAction SilentlyContinue
}
while (`$true) {
    `$evt = Wait-Event -SourceIdentifier 'BT_ProcWatch_$id'
    if (`$evt) { Remove-Event -EventIdentifier `$evt.EventIdentifier -ErrorAction SilentlyContinue; Optimize-RunningTarget }
}
"@
        Set-Content -Path $scriptPath -Value $workerCode -Encoding UTF8 -Force
        $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
        $trigger   = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    } { (Test-ScheduledTaskFast $taskName) }
    Update-SelectedGameUI
})

$TglGameAffinity.Add_Unchecked({
    if ($script:loadingGameUI) { return }
    $game = $script:GameList[$LstGames.SelectedIndex]
    $exe = $game.Exe; $procName = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    $id = Get-CleanId $exe; $taskName = "BetterTitus_Affinity_$id"
    Invoke-SafeTweak "Desativar Afinidade ($exe)" {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item "$script:ConfigDir\Affinity_$id.ps1" -Force -ErrorAction SilentlyContinue
        Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions" -Recurse -Force -ErrorAction SilentlyContinue
        $allMask = if ($script:HwInfo.Threads -ge 64) { [uint64]::MaxValue } else { ([uint64]1 -shl [int]$script:HwInfo.Threads) - [uint64]1 }
        Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.ProcessorAffinity = [IntPtr]([int64]$allMask); $_.PriorityClass = 'Normal' } catch {}
        }
    }
    Update-SelectedGameUI
})

# Card 3: Remover Latência de Tela Cheia (DX11 Flags 211)
$TglGameDx11.Add_Checked({
    if ($script:loadingGameUI) { return }
    $game = $script:GameList[$LstGames.SelectedIndex]
    $exe = $game.Exe; $id = Get-CleanId $exe; $dxTaskName = "BetterTitus_DX11Watch_$id"
    $children = "HKCU:\System\GameConfigStore\Children"

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
`$children = 'HKCU:\System\GameConfigStore\Children'
if (Test-Path `$children) {
    foreach (`$sub in (Get-ChildItem `$children -ErrorAction SilentlyContinue)) {
        `$mExe = (Get-ItemProperty `$sub.PSPath -Name 'MatchedExeFullPath' -ErrorAction SilentlyContinue).MatchedExeFullPath
        if (`$mExe -and (`$mExe -like '*\$exe' -or `$mExe -ieq '$exe')) {
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
            $principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -RunLevel Highest
            $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
            Register-ScheduledTask -TaskName $dxTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        }
    }
    Update-SelectedGameUI
})

$TglGameDx11.Add_Unchecked({
    if ($script:loadingGameUI) { return }
    $game = $script:GameList[$LstGames.SelectedIndex]
    $exe = $game.Exe; $id = Get-CleanId $exe; $dxTaskName = "BetterTitus_DX11Watch_$id"
    Invoke-SafeTweak "Reverter Latência Tela Cheia ($exe)" {
        Stop-ScheduledTask -TaskName $dxTaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $dxTaskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item "$script:ConfigDir\DX11Watch_$id.ps1" -Force -ErrorAction SilentlyContinue
        $children = "HKCU:\System\GameConfigStore\Children"
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

# Card 4: Desativar Telemetria NVIDIA (Dinâmica com Backup/Restore Exato e Crash Recovery)
$TglGameNvTel.Add_Checked({
    if ($script:loadingGameUI) { return }
    $game = $script:GameList[$LstGames.SelectedIndex]
    $exe = $game.Exe; $procName = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    $id = Get-CleanId $exe; $nvTaskName = "BetterTitus_NvTel_$id"

    $msg = if ($script:Lang -eq "PT") {
        "Aviso de Funcionalidade:`n`nEnquanto $($game.Name) estiver aberto, os serviços NVDisplay.ContainerLocalSystem e NvContainerLocalSystem serão pausados.`n`nIsso pausa temporariamente o NVIDIA Overlay (ShadowPlay) e o Painel de Controle NVIDIA durante a partida. Ao fechar o jogo (ou reiniciar em caso de crash), o estado original exato de cada serviço será restaurado.`n`nDeseja ativar para $($game.Name)?"
    } else {
        "Feature Notice:`n`nWhile $($game.Name) is running, NVDisplay.ContainerLocalSystem and NvContainerLocalSystem will be temporarily paused.`n`nThis temporarily pauses NVIDIA Overlay (ShadowPlay) and NVIDIA Control Panel in-game. Upon closing the game (or after any unexpected crash/reboot), each service's exact original configuration is automatically restored.`n`nEnable for $($game.Name)?"
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
`$exeName  = '$exe'
`$procBase = '$procName'
`$bkpFile  = '$script:NvBackup'
`$nvSvcs   = @('NVDisplay.ContainerLocalSystem', 'NvContainerLocalSystem')

function Restore-NvOriginalState {
    if (Test-Path `$bkpFile) {
        try {
            `$saved = Get-Content `$bkpFile -Raw | ConvertFrom-Json
            foreach (`$item in `$saved) {
                `$reg = "HKLM:\SYSTEM\CurrentControlSet\Services\`$(`$item.Name)"
                if (Test-Path `$reg) {
                    Set-ItemProperty -Path `$reg -Name 'Start' -Value ([int]`$item.Start) -Type DWord -Force -ErrorAction SilentlyContinue
                    if (`$item.WasRunning) { Start-Service -Name `$item.Name -ErrorAction SilentlyContinue }
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
                `$startVal = (Get-ItemProperty -Path `$reg -Name 'Start' -ErrorAction SilentlyContinue).Start
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
            Stop-Service -Name `$s -Force -ErrorAction SilentlyContinue
        }
    }
}

# Crash Recovery no boot/início: se o jogo não está aberto mas existe backup pendente, restaura imediatamente
if (-not (Get-Process -Name `$procBase -ErrorAction SilentlyContinue)) {
    Restore-NvOriginalState
}

try {
    Unregister-Event -SourceIdentifier 'BT_NvWatch_$id' -ErrorAction SilentlyContinue
    try {
        Register-WmiEvent -Query "SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName = '`$exeName'" -SourceIdentifier 'BT_NvWatch_$id' -ErrorAction Stop
    } catch {
        Register-WmiEvent -Query "SELECT * FROM __InstanceCreationEvent WITHIN 3 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = '`$exeName'" -SourceIdentifier 'BT_NvWatch_$id' -ErrorAction SilentlyContinue
    }

    while (`$true) {
        if (-not (Get-Process -Name `$procBase -ErrorAction SilentlyContinue)) {
            `$evt = Wait-Event -SourceIdentifier 'BT_NvWatch_$id'
            if (`$evt) { Remove-Event -EventIdentifier `$evt.EventIdentifier -ErrorAction SilentlyContinue }
        }
        Start-Sleep -Seconds 3
        if (Get-Process -Name `$procBase -ErrorAction SilentlyContinue) {
            Pause-NvDuringGame
            while (Get-Process -Name `$procBase -ErrorAction SilentlyContinue) {
                Start-Sleep -Seconds 3
            }
            Restore-NvOriginalState
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
    } { Test-ScheduledTaskFast $nvTaskName }
    Update-SelectedGameUI
})

$TglGameNvTel.Add_Unchecked({
    if ($script:loadingGameUI) { return }
    $game = $script:GameList[$LstGames.SelectedIndex]
    $exe = $game.Exe; $id = Get-CleanId $exe; $nvTaskName = "BetterTitus_NvTel_$id"
    Invoke-SafeTweak "Desativar Gerenciamento NVIDIA ($exe)" {
        Stop-ScheduledTask -TaskName $nvTaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $nvTaskName -Confirm:$false -ErrorAction SilentlyContinue
        Remove-Item "$script:ConfigDir\NvTel_$id.ps1" -Force -ErrorAction SilentlyContinue
        Restore-NvidiaBackupIfNeeded
    }
    Update-SelectedGameUI
})

# ==============================================================================
# DETECÇÃO E PERSISTÊNCIA REAL DO SISTEMA (TWEAKS + SEGURANÇA + PREFERÊNCIAS)
# ==============================================================================
$script:loadingState = $false
$script:AppliedSecurityCache = @{ BitLocker = $false; HVCI = $false; Mitigations = $false }

function Sync-SystemState {
    $script:loadingState = $true

    $ChkActivity.IsChecked        = ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 1) -eq 0)
    $ChkConsumer.IsChecked        = ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 0) -eq 1)
    $ChkDelivery.IsChecked        = (((Get-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 1) -eq 0) -or ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 1) -eq 0))
    $ChkEndTask.IsChecked         = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask" 0) -eq 1)
    $ChkFolderDisc.IsChecked      = ((Get-Reg "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" "FolderType" "") -eq "NotSpecified")
    $ChkHibernation.IsChecked     = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 1) -eq 0)
    $ChkLocation.IsChecked        = ((Get-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Allow") -eq "Deny")
    $ChkStoreSearch.IsChecked     = ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 0) -eq 1)
    $ChkDeviceCompanion.IsChecked = ((Get-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 0) -eq 1)

    $manualCount = 0; $existingCount = 0
    foreach ($svc in $script:SafeManualServices) {
        $st = Get-ServiceStartModeFast $svc
        if ($st -ne -1) { $existingCount++; if ($st -ge 3) { $manualCount++ } }
    }
    $ChkServicesMan.IsChecked     = ($existingCount -gt 0 -and ($manualCount -ge ([math]::Ceiling($existingCount * 0.7))))
    $ChkTelemetry.IsChecked       = (((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1) -eq 0) -or ((Get-ServiceStartModeFast "DiagTrack") -eq 4))
    $ChkWidgets.IsChecked         = (((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 1) -eq 0) -or ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 1) -eq 0))
    $ChkWPBT.IsChecked            = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 0) -eq 1)
    $ChkSearchIdx.IsChecked       = ((Get-ServiceStartModeFast "WSearch") -eq 4)

    $ChkBgApps.IsChecked          = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 0) -eq 1)

    # Tarefas opcionais de telemetria
    $ceipTask = Get-ScheduledTask -TaskPath "\Microsoft\Windows\Application Experience\" -TaskName "Microsoft Compatibility Appraiser" -ErrorAction SilentlyContinue
    $ChkOptTasks.IsChecked        = ($null -ne $ceipTask -and $ceipTask.State -eq 'Disabled')

    $ChkReservedStorage.IsChecked = ((Get-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "ShippedWithReserves" 1) -eq 0)
    $ChkExplorerGallery.IsChecked = ((Get-Reg "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 1) -eq 0)
    $ChkGameDVR.IsChecked         = ((Get-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 1) -eq 0)
    $ChkIPv4Pref.IsChecked        = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" 0) -eq 32)
    $ChkTeredo.IsChecked          = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" 0) -eq 1 -or (Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" "Teredo_State" "") -eq "Disabled")
    $ChkMenuDelay.IsChecked       = ((Get-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400").ToString() -eq "0")
    $ChkEdgeDebloat.IsChecked     = ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled" 1) -eq 0)

    $netThr = Get-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 10
    $ChkNetThrottle.IsChecked     = ($netThr -eq -1 -or $netThr -eq 0xffffffff -or $netThr -eq 4294967295)
    $ChkPowerThrottle.IsChecked   = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 0) -eq 1)
    $ChkClassicContext.IsChecked  = (Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32")
    $ChkStorageSense.IsChecked    = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 1) -eq 0)
    $ChkSvcHost.IsChecked         = ([int64](Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB" 380000) -ge ($script:HwInfo.RamKB - 4096))
    $ChkUsbSuspend.IsChecked      = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\USB" "DisableSelectiveSuspend" 0) -eq 1)
    $ChkBestPerf.IsChecked        = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 0) -eq 2)
    $ChkWinAI.IsChecked           = (((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 0) -eq 1) -or ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 0) -eq 1))

    # Segurança e Overhead de CPU (Estado real)
    $blOff = $false
    if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
        try {
            $blVol = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
            if ($null -ne $blVol -and $blVol.ProtectionStatus -eq 'Off' -and $blVol.VolumeStatus -eq 'FullyDecrypted') { $blOff = $true }
        } catch {}
    } else {
        $blOff = ((Get-ServiceStartModeFast "BDESVC") -eq 4)
    }
    $ChkBitLocker.IsChecked = $blOff
    $script:AppliedSecurityCache.BitLocker = $blOff

    $hvciOff = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1) -eq 0)
    $ChkHVCI.IsChecked = $hvciOff
    $script:AppliedSecurityCache.HVCI = $hvciOff

    $mitOff = (((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 0) -eq 3) -and ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 0) -eq 3))
    $ChkCpuMitigations.IsChecked = $mitOff
    $script:AppliedSecurityCache.Mitigations = $mitOff

    # Coluna Direita
    $TglBsod.IsChecked            = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 0) -eq 1)
    $TglDarkWin.IsChecked         = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 1) -eq 0)
    $TglLongPaths.IsChecked       = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 0) -eq 1)
    $TglFastStart.IsChecked       = ((Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 1) -eq 1)
    $TglFileExt.IsChecked         = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1) -eq 0)
    $TglHiddenFiles.IsChecked     = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2) -eq 1)
    $TglGameMode.IsChecked        = ((Get-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1) -eq 1)
    $TglAcrylic.IsChecked         = ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableAcrylicBackgroundOnLogon" 0) -eq 0)
    $TglVerboseLogon.IsChecked    = ((Get-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "VerboseStatus" 0) -eq 1)
    $TglMouseAccel.IsChecked      = ((Get-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "1").ToString() -ne "0")
    $TglMmProfile.IsChecked       = ((Get-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 2) -eq 8)
    $TglNumLock.IsChecked         = ((Get-Reg "Registry::HKU\.DEFAULT\Control Panel\Keyboard" "InitialKeyboardIndicators" "0").ToString() -in @("2", "2147483650"))
    $TglBingSearch.IsChecked      = (((Get-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 0) -eq 0) -and ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 1) -ne 0))
    $TglStartRecs.IsChecked       = ((Get-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 0) -eq 0)
    $TglStickyKeys.IsChecked      = ((Get-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "510").ToString() -ne "506")
    $TglCenterTaskbar.IsChecked   = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 1) -eq 1)
    $TglSearchIcon.IsChecked      = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1) -ne 0)
    $TglTaskView.IsChecked        = ((Get-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 1) -eq 1)
    $TglSnap.IsChecked            = ((Get-Reg "HKCU:\Control Panel\Desktop" "WindowArrangementActive" "1").ToString() -eq "1")

    $mpoDwm = Get-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 0
    $mpoLeg = Get-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "DisableOverlays" 0
    $CmbMPO.SelectedIndex = if ($mpoDwm -eq 5 -or $mpoLeg -eq 1) { 1 } else { 0 }

    $script:WinUpdateDisabledCache = ((Get-ServiceStartModeFast "wuauserv") -eq 4)
    $StatusWinUpdateCard.Foreground = if ($script:WinUpdateDisabledCache) { "#F87171" } else { "#4ADE80" }
    Refresh-CachedStatusLabels

    $script:loadingState = $false
}

# Eventos dos Interruptores da Direita
$TglBsod.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "BSoD Verbose -> ON"  { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 1 } } })
$TglBsod.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "BSoD Verbose -> OFF" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 0 } } })
$TglDarkWin.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Dark Theme -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0 } } })
$TglDarkWin.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Dark Theme -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 1 } } })
$TglLongPaths.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Long Paths -> ON"  { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1 } } })
$TglLongPaths.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Long Paths -> OFF" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 0 } } })
$TglFastStart.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Fast Startup -> ON"  { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 1 } } })
$TglFastStart.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Fast Startup -> OFF" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0 } } })
$TglFileExt.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "File Extensions -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0 } } })
$TglFileExt.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "File Extensions -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1 } } })
$TglHiddenFiles.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Hidden Files -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1 } } })
$TglHiddenFiles.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Hidden Files -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2 } } })
$TglGameMode.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Game Mode -> ON"  { Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1 } } })
$TglGameMode.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Game Mode -> OFF" { Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 0 } } })
$TglAcrylic.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Logon Acrylic Blur -> ON"  { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableAcrylicBackgroundOnLogon" 0 } } })
$TglAcrylic.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Logon Acrylic Blur -> OFF" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "DisableAcrylicBackgroundOnLogon" 1 } } })
$TglVerboseLogon.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Verbose Logon -> ON"  { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "VerboseStatus" 1 } } })
$TglVerboseLogon.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Verbose Logon -> OFF" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "VerboseStatus" 0 } } })
$TglMouseAccel.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Mouse Acceleration -> ON"  { Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "1" "String"; Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "6" "String"; Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "10" "String" } } })
$TglMouseAccel.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Mouse Acceleration -> OFF (1:1)" { Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"; Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"; Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String" } } })
$TglMmProfile.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Multimedia Gaming Profile -> ON"  { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 6; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "High" "String" } } })
$TglMmProfile.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Multimedia Gaming Profile -> OFF" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 2; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 2 } } })
$TglNumLock.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "NumLock on Startup -> ON"  { Set-Reg "Registry::HKU\.DEFAULT\Control Panel\Keyboard" "InitialKeyboardIndicators" "2" "String" } } })
$TglNumLock.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "NumLock on Startup -> OFF" { Set-Reg "Registry::HKU\.DEFAULT\Control Panel\Keyboard" "InitialKeyboardIndicators" "0" "String" } } })
$TglBingSearch.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Start Menu Bing Search -> ON"  { Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 0; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 1 } } })
$TglBingSearch.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Start Menu Bing Search -> OFF" { Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0 } } })
$TglStartRecs.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Start Recommendations -> ON"  { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 0 } } })
$TglStartRecs.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Start Recommendations -> OFF" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 1 } } })
$TglStickyKeys.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Sticky Keys -> ON"  { Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "510" "String" } } })
$TglStickyKeys.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Sticky Keys -> OFF" { Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" "String" } } })
$TglCenterTaskbar.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Taskbar Centered Icons -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 1 } } })
$TglCenterTaskbar.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Taskbar Centered Icons -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0 } } })
$TglSearchIcon.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Taskbar Search Icon -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1 } } })
$TglSearchIcon.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Taskbar Search Icon -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0 } } })
$TglTaskView.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Task View Icon -> ON"  { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 1 } } })
$TglTaskView.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Task View Icon -> OFF" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0 } } })
$TglSnap.Add_Checked({   if (-not $script:loadingState) { Invoke-SafeTweak "Window Snapping -> ON"  { Set-Reg "HKCU:\Control Panel\Desktop" "WindowArrangementActive" "1" "String" } } })
$TglSnap.Add_Unchecked({ if (-not $script:loadingState) { Invoke-SafeTweak "Window Snapping -> OFF" { Set-Reg "HKCU:\Control Panel\Desktop" "WindowArrangementActive" "0" "String" } } })

$CmbMPO.Add_SelectionChanged({
    if (-not $script:loadingState) {
        if ($CmbMPO.SelectedIndex -eq 1) { Invoke-SafeTweak "Multiplane Overlay (MPO) -> Disabled" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 } }
        else { Invoke-SafeTweak "Multiplane Overlay (MPO) -> Enabled" { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -ErrorAction SilentlyContinue; Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "DisableOverlays" -ErrorAction SilentlyContinue } }
    }
})

$BtnUltEnable.Add_Click({
    Invoke-SafeTweak "Plano Desempenho Máximo (Ultimate)" {
        $existingGuid = (powercfg /list | Select-String "Ultimate Performance|Desempenho M" | ForEach-Object { $_.ToString().Split()[3] } | Select-Object -First 1)
        if (-not $existingGuid) {
            $dup = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
            if ($dup -match '([a-fA-F0-9\-]{36})') { $existingGuid = $matches[1] }
        }
        if ($existingGuid) { powercfg /setactive $existingGuid }
    }
})
$BtnUltDisable.Add_Click({ Invoke-SafeTweak "Plano de Energia Equilibrado" { powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e } })

# Aba Advanced
$BtnDisableWinUpdate.Add_Click({
    Invoke-SafeTweak "Desativar Windows Update" {
        @("wuauserv", "UsoSvc") | ForEach-Object { [void](Set-ServiceStartModeSafe $_ 4) }
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
    }
    $script:WinUpdateDisabledCache = ((Get-ServiceStartModeFast "wuauserv") -eq 4)
    $StatusWinUpdateCard.Foreground = if ($script:WinUpdateDisabledCache) { "#F87171" } else { "#4ADE80" }
    Refresh-CachedStatusLabels
})
$BtnRestoreWinUpdate.Add_Click({
    Invoke-SafeTweak "Restaurar Windows Update" {
        @("wuauserv", "UsoSvc") | ForEach-Object { [void](Set-ServiceStartModeSafe $_ 3); Start-Service -Name $_ -ErrorAction SilentlyContinue }
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
    }
    $script:WinUpdateDisabledCache = ((Get-ServiceStartModeFast "wuauserv") -eq 4)
    $StatusWinUpdateCard.Foreground = if ($script:WinUpdateDisabledCache) { "#F87171" } else { "#4ADE80" }
    Refresh-CachedStatusLabels
})
$BtnAdvFlushNet.Add_Click({ Invoke-SafeTweak "Reset de Rede e Flush DNS" { ipconfig /flushdns | Out-Null; netsh winsock reset | Out-Null; netsh int ip reset | Out-Null } })
$BtnAdvCleanCache.Add_Click({ Invoke-SafeTweak "Limpeza de Pastas Temp e Prefetch" { @("$env:TEMP\*", "$env:windir\Temp\*", "$env:windir\Prefetch\*") | ForEach-Object { Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue } } })

# Presets Seguros (NUNCA marcam automaticamente BitLocker, HVCI ou Mitigações de CPU)
$SafeLeftChecks = @(
    $ChkActivity, $ChkConsumer, $ChkDelivery, $ChkEndTask, $ChkFolderDisc,
    $ChkHibernation, $ChkLocation, $ChkStoreSearch, $ChkDeviceCompanion, $ChkServicesMan,
    $ChkTelemetry, $ChkWidgets, $ChkWPBT, $ChkSearchIdx, $ChkBgApps, $ChkOptTasks,
    $ChkReservedStorage, $ChkExplorerGallery, $ChkGameDVR, $ChkIPv4Pref, $ChkTeredo,
    $ChkMenuDelay, $ChkEdgeDebloat, $ChkNetThrottle, $ChkPowerThrottle, $ChkClassicContext,
    $ChkStorageSense, $ChkSvcHost, $ChkUsbSuspend, $ChkBestPerf, $ChkWinAI
)
$AllLeftChecks = $SafeLeftChecks + @($ChkBitLocker, $ChkHVCI, $ChkCpuMitigations)

$BtnPresetClr.Add_Click({ $AllLeftChecks | ForEach-Object { $_.IsChecked = $false }; Write-BTLog "Seleção limpa." "INFO" })
$BtnPresetMin.Add_Click({
    $AllLeftChecks | ForEach-Object { $_.IsChecked = $false }
    $ChkActivity.IsChecked = $true; $ChkConsumer.IsChecked = $true; $ChkTelemetry.IsChecked = $true; $ChkServicesMan.IsChecked = $true
    Write-BTLog "Preset 'Minimal' selecionado." "INFO"
})
$BtnPresetStd.Add_Click({
    $AllLeftChecks | ForEach-Object { $_.IsChecked = $false }
    $ChkActivity.IsChecked = $true; $ChkConsumer.IsChecked = $true; $ChkDelivery.IsChecked = $true
    $ChkEndTask.IsChecked = $true; $ChkFolderDisc.IsChecked = $true; $ChkHibernation.IsChecked = $true
    $ChkLocation.IsChecked = $true; $ChkStoreSearch.IsChecked = $true; $ChkDeviceCompanion.IsChecked = $true
    $ChkServicesMan.IsChecked = $true; $ChkTelemetry.IsChecked = $true; $ChkWidgets.IsChecked = $true; $ChkWPBT.IsChecked = $true
    Write-BTLog "Preset 'Standard' selecionado." "INFO"
})
$BtnPresetAdv.Add_Click({
    $AllLeftChecks | ForEach-Object { $_.IsChecked = $false }
    $SafeLeftChecks | ForEach-Object { $_.IsChecked = $true }
    Write-BTLog "Preset 'Advanced' selecionado (Proteções de Segurança mantidas fora por segurança)." "INFO"
})
$BtnSelectInstalled.Add_Click({ Sync-SystemState; Write-BTLog "Estado real do Windows verificado e sincronizado." "OK" })

# ==============================================================================
# APLICAR OTIMIZAÇÕES (COM CONFIRMAÇÃO EXPLÍCITA PARA ITENS DE SEGURANÇA)
# ==============================================================================
$BtnRunTweaks.Add_Click({
    # Verifica se o usuário marcou alguma alteração nova de Segurança/Overhead de CPU
    $secSelected = @()
    if ($ChkBitLocker.IsChecked -and -not $script:AppliedSecurityCache.BitLocker) { $secSelected += "- Desativar BitLocker (Descriptografia de Disco)" }
    if ($ChkHVCI.IsChecked -and -not $script:AppliedSecurityCache.HVCI)           { $secSelected += "- Desativar HVCI / Integridade de Memória (Pode afetar Vanguard/FACEIT)" }
    if ($ChkCpuMitigations.IsChecked -and -not $script:AppliedSecurityCache.Mitigations) { $secSelected += "- Desativar Mitigações Spectre/Meltdown (Menor proteção especulativa)" }

    $applySecurity = $true
    if ($secSelected.Count -gt 0) {
        $warnText = if ($script:Lang -eq "PT") {
            "CONFIRMAÇÃO DE SEGURANÇA OBRIGATÓRIA:`n`nVocê selecionou alterações que reduzem camadas de proteção do Windows para ganhar desempenho:`n`n$($secSelected -join "`n")`n`nTodas podem ser revertidas pelo botão 'Reverter Selecionadas'. Deseja prosseguir com essas alterações de segurança?"
        } else {
            "EXPLICIT SECURITY CONFIRMATION REQUIRED:`n`nYou selected optimizations that reduce Windows security layers for performance:`n`n$($secSelected -join "`n")`n`nAll changes are reversible via 'Revert Selected Tweaks'. Proceed with these security changes?"
        }
        $ans = [System.Windows.MessageBox]::Show($warnText, "BetterTitus - Security Confirmation", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($ans -ne [System.Windows.MessageBoxResult]::Yes) {
            $applySecurity = $false
            Write-BTLog "Alterações de Segurança (BitLocker/HVCI/Mitigações) canceladas pelo usuário." "WARN"
        }
    }

    Write-BTLog "=== INICIANDO APLICAÇÃO DE OTIMIZAÇÕES ===" "INFO"

    if ($ChkActivity.IsChecked)        { Invoke-SafeTweak "Histórico de Atividades" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 } }
    if ($ChkConsumer.IsChecked)        { Invoke-SafeTweak "ConsumerFeatures" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0 } }
    if ($ChkDelivery.IsChecked)        { Invoke-SafeTweak "Delivery Optimization" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0 } }
    if ($ChkEndTask.IsChecked)         { Invoke-SafeTweak "End Task na Barra" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask" 1 } }
    if ($ChkFolderDisc.IsChecked)      { Invoke-SafeTweak "Folder Discovery" { Set-Reg "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" "FolderType" "NotSpecified" "String" } }
    if ($ChkHibernation.IsChecked)     { Invoke-SafeTweak "Hibernação" { powercfg.exe /hibernate off; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0 } }
    if ($ChkLocation.IsChecked)        { Invoke-SafeTweak "Localização" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Deny" "String" } }
    if ($ChkStoreSearch.IsChecked)     { Invoke-SafeTweak "Store Search" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 1 } }
    if ($ChkDeviceCompanion.IsChecked) { Invoke-SafeTweak "Bloquear Device Companion Apps" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 1 } }
    if ($ChkServicesMan.IsChecked)     { Invoke-SafeTweak "Serviços -> Manual" { foreach ($svc in $script:SafeManualServices) { $cur = Get-ServiceStartModeFast $svc; if ($cur -ne -1 -and $cur -lt 3) { [void](Set-ServiceStartModeSafe $svc 3) } } } }
    if ($ChkTelemetry.IsChecked)       { Invoke-SafeTweak "Telemetria" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0; [void](Set-ServiceStartModeSafe "DiagTrack" 4); [void](Set-ServiceStartModeSafe "dmwappushservice" 4) } }
    if ($ChkWidgets.IsChecked)         { Invoke-SafeTweak "Widgets" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0 } }
    if ($ChkWPBT.IsChecked)            { Invoke-SafeTweak "WPBT" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 1 } }
    if ($ChkSearchIdx.IsChecked)       { Invoke-SafeTweak "Windows Search" { [void](Set-ServiceStartModeSafe "WSearch" 4) } }
    if ($ChkBgApps.IsChecked)          { Invoke-SafeTweak "Background Apps" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1 } }
    if ($ChkOptTasks.IsChecked)        { Invoke-SafeTweak "Tarefas Agendadas de Telemetria" { foreach ($t in $script:OptionalScheduledTasks) { $p = Split-Path $t -Parent; $n = Split-Path $t -Leaf; Disable-ScheduledTask -TaskPath "$p\" -TaskName $n -ErrorAction SilentlyContinue | Out-Null } } }
    if ($ChkReservedStorage.IsChecked) { Invoke-SafeTweak "Armazenamento Reservado" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "ShippedWithReserves" 0; if (Get-Command Set-WindowsReservedStorageState -ErrorAction SilentlyContinue) { Set-WindowsReservedStorageState -State Disabled -ErrorAction SilentlyContinue } } }
    if ($ChkExplorerGallery.IsChecked) { Invoke-SafeTweak "Ocultar Galeria/Início Explorer" { Set-Reg "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 0; Set-Reg "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" "System.IsPinnedToNameSpaceTree" 0 } }
    if ($ChkGameDVR.IsChecked)         { Invoke-SafeTweak "GameDVR" { Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0 } }
    if ($ChkIPv4Pref.IsChecked)        { Invoke-SafeTweak "IPv4 Preferencial" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" 32 } }
    if ($ChkTeredo.IsChecked)          { Invoke-SafeTweak "Desativar Teredo" { netsh interface teredo set state disabled | Out-Null; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" "Teredo_State" "Disabled" "String" } }
    if ($ChkMenuDelay.IsChecked)       { Invoke-SafeTweak "MenuShowDelay 0ms" { Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String" } }
    if ($ChkEdgeDebloat.IsChecked)     { Invoke-SafeTweak "Edge Background" { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "StartupBoostEnabled" 0 } }
    if ($ChkNetThrottle.IsChecked)     { Invoke-SafeTweak "Network Throttling" { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xffffffff; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0 } }
    if ($ChkPowerThrottle.IsChecked)   { Invoke-SafeTweak "Power Throttling" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1 } }
    if ($ChkClassicContext.IsChecked)  { Invoke-SafeTweak "Menu Clássico Win 11" { New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Value "" -Force | Out-Null } }
    if ($ChkStorageSense.IsChecked)    { Invoke-SafeTweak "Storage Sense" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 0 } }
    if ($ChkSvcHost.IsChecked)         { Invoke-SafeTweak "SvcHost Split ($($script:HwInfo.RamKB) KB)" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB" ([int]$script:HwInfo.RamKB) } }
    if ($ChkUsbSuspend.IsChecked)      { Invoke-SafeTweak "USB Selective Suspend" { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\USB" "DisableSelectiveSuspend" 1 } }
    if ($ChkBestPerf.IsChecked)        { Invoke-SafeTweak "Visual Effects" { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2 } }
    if ($ChkWinAI.IsChecked)           { Invoke-SafeTweak "Windows AI (Copilot & Recall)" { Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffSavingSnapshots" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0 } }

    # Aplicação Condicional das Opções de Segurança (somente se confirmado)
    if ($applySecurity) {
        if ($ChkBitLocker.IsChecked -and -not $script:AppliedSecurityCache.BitLocker) {
            Invoke-SafeTweak "Desativar BitLocker ($env:SystemDrive)" {
                if (Get-Command Disable-BitLocker -ErrorAction SilentlyContinue) { Disable-BitLocker -MountPoint $env:SystemDrive -ErrorAction Stop | Out-Null }
                else { & manage-bde.exe -off $env:SystemDrive | Out-Null }
            }
        }
        if ($ChkHVCI.IsChecked) {
            Invoke-SafeTweak "Desativar HVCI / Memory Integrity (Reinicie o PC)" {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0
            }
        }
        if ($ChkCpuMitigations.IsChecked) {
            Invoke-SafeTweak "Desativar Mitigações Spectre/Meltdown (Reinicie o PC)" {
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 3
                Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 3
            }
        }
    }

    if ($CmbDNS.SelectedIndex -gt 0) {
        $dnsMap = @{ 1 = @("1.1.1.1","1.0.0.1"); 2 = @("8.8.8.8","8.8.4.4"); 3 = @("9.9.9.9","149.112.112.112") }
        $servers = $dnsMap[$CmbDNS.SelectedIndex]
        Invoke-SafeTweak "DNS ($($servers -join ', '))" {
            Get-NetAdapter | Where-Object Status -eq "Up" | ForEach-Object {
                Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses $servers -ErrorAction SilentlyContinue
            }
        }
    }

    Sync-SystemState
    Write-BTLog "=== PROCESSO CONCLUÍDO E SINCRONIZADO ===" "OK"
})

$BtnUndoTweaks.Add_Click({
    Write-BTLog "=== REVERTENDO OTIMIZAÇÕES SELECIONADAS ===" "INFO"
    if ($ChkActivity.IsChecked)        { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 1 }
    if ($ChkConsumer.IsChecked)        { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 0 }
    if ($ChkDelivery.IsChecked)        { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 1; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 1 }
    if ($ChkEndTask.IsChecked)         { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" "TaskbarEndTask" 0 }
    if ($ChkFolderDisc.IsChecked)      { Remove-ItemProperty -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" -Name "FolderType" -ErrorAction SilentlyContinue }
    if ($ChkHibernation.IsChecked)     { powercfg.exe /hibernate on; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 1 }
    if ($ChkLocation.IsChecked)        { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Allow" "String" }
    if ($ChkStoreSearch.IsChecked)     { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 0 }
    if ($ChkDeviceCompanion.IsChecked) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 0 }
    if ($ChkTelemetry.IsChecked)       { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1; [void](Set-ServiceStartModeSafe "DiagTrack" 2) }
    if ($ChkWidgets.IsChecked)         { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 1; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 1 }
    if ($ChkWPBT.IsChecked)            { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 0 }
    if ($ChkSearchIdx.IsChecked)       { [void](Set-ServiceStartModeSafe "WSearch" 2); Start-Service "WSearch" -ErrorAction SilentlyContinue }
    if ($ChkBgApps.IsChecked)          { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 0 }
    if ($ChkOptTasks.IsChecked)        { foreach ($t in $script:OptionalScheduledTasks) { $p = Split-Path $t -Parent; $n = Split-Path $t -Leaf; Enable-ScheduledTask -TaskPath "$p\" -TaskName $n -ErrorAction SilentlyContinue | Out-Null } }
    if ($ChkReservedStorage.IsChecked) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" "ShippedWithReserves" 1 }
    if ($ChkExplorerGallery.IsChecked) { Set-Reg "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 1; Set-Reg "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" "System.IsPinnedToNameSpaceTree" 1 }
    if ($ChkGameDVR.IsChecked)         { Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 1; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 1 }
    if ($ChkIPv4Pref.IsChecked)        { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" 0 }
    if ($ChkTeredo.IsChecked)          { netsh interface teredo set state default | Out-Null; Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TCPIP\v6Transition" -Name "Teredo_State" -ErrorAction SilentlyContinue }
    if ($ChkMenuDelay.IsChecked)       { Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" "String" }
    if ($ChkEdgeDebloat.IsChecked)     { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled" 1 }
    if ($ChkNetThrottle.IsChecked)     { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 10; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 20 }
    if ($ChkPowerThrottle.IsChecked)   { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 0 }
    if ($ChkClassicContext.IsChecked)  { Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue }
    if ($ChkStorageSense.IsChecked)    { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 1 }
    if ($ChkSvcHost.IsChecked)         { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control" "SvcHostSplitThresholdInKB" 380000 }
    if ($ChkUsbSuspend.IsChecked)      { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\USB" "DisableSelectiveSuspend" 0 }
    if ($ChkBestPerf.IsChecked)        { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 0 }
    if ($ChkWinAI.IsChecked)           { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 0 }
    if ($ChkHVCI.IsChecked)            { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1 }
    if ($ChkCpuMitigations.IsChecked)  { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 0; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 0 }

    Sync-SystemState
    Write-BTLog "Otimizações selecionadas revertidas para o padrão do Windows!" "OK"
})

# Inicializar BetterTitus
Sync-SystemState
Update-SelectedGameUI
Set-AppLanguage $script:Lang
$window.ShowDialog() | Out-Null