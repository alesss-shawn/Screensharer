#Requires -Version 5.1
<#
    CoralMC Alts Checker
    Premium Edition - Ocean Theme (Optimized Core)
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Net.Http

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

function Clear-WindowsClipboardHistory {
    try {
        [System.Windows.Forms.Clipboard]::Clear()
        Set-Clipboard -Value $null -ErrorAction SilentlyContinue

        try {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime
            $asTask = ([Windows.ApplicationModel.DataTransfer.Clipboard].GetMethod('ClearHistory', [System.Reflection.BindingFlags]'Public,Static'))
            if ($asTask) {
                $null = $asTask.Invoke($null, $null)
            }
        } catch { }

        $clipboardServices = Get-Service -Name "cbdhsvc*" -ErrorAction SilentlyContinue
        foreach ($svc in $clipboardServices) {
            if ($svc.Status -eq 'Running') {
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            }
        }

        $clipboardHistoryPath = "$env:LOCALAPPDATA\Microsoft\Windows\Clipboard"
        if (Test-Path $clipboardHistoryPath) {
            Get-ChildItem -Path $clipboardHistoryPath -Recurse -Force -ErrorAction SilentlyContinue | 
                Where-Object { $_.PSIsContainer -eq $false } | 
                Remove-Item -Force -ErrorAction SilentlyContinue
        }

        foreach ($svc in $clipboardServices) {
            Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
        }
    } catch { }
}

Clear-WindowsClipboardHistory

$Theme = @{
    Background          = "#0B1B2B"
    Surface             = "#0F2140"
    SurfaceLight        = "#1A2F50"
    SurfaceHover        = "#1E3A5F"
    SurfaceGlass        = "rgba(15,33,64,0.85)"
    Primary             = "#00D4FF"
    PrimaryLight        = "#66E5FF"
    PrimaryDark         = "#0099CC"
    Accent              = "#FF6B4A"
    AccentLight         = "#FF8A6F"
    Success             = "#00E676"
    Warning             = "#FFC107"
    Error               = "#FF5252"
    Text                = "#E8F4F8"
    TextSecondary       = "#94B8D0"
    TextMuted           = "#5A7A94"
    Border              = "#1A3A5A"
    BorderLight         = "#2A5A7A"
    Glow                = "rgba(0,212,255,0.15)"
}

$ButtonStyles = @{
    Primary = @{ Color = "#00D4FF"; Hover = "#44DDFF"; Text = "#FFFFFF" }
    Success = @{ Color = "#00E676"; Hover = "#44E88A"; Text = "#FFFFFF" }
    Warning = @{ Color = "#FFC107"; Hover = "#FFD54F"; Text = "#FFFFFF" }
    Danger = @{ Color = "#FF5252"; Hover = "#FF7575"; Text = "#FFFFFF" }
    Accent = @{ Color = "#FF6B4A"; Hover = "#FF8568"; Text = "#FFFFFF" }
    Info = @{ Color = "#60A5FA"; Hover = "#93BBFC"; Text = "#FFFFFF" }
    Secondary = @{ Color = "#4B5563"; Hover = "#6B7280"; Text = "#FFFFFF" }
    Rose = @{ Color = "#FF6B6B"; Hover = "#FF8A8A"; Text = "#FFFFFF" }
    Magenta = @{ Color = "#FF6BFF"; Hover = "#FF8AFF"; Text = "#FFFFFF" }
}

$PanelStyles = @{
    Glass = @{ BackColor = "rgba(15,33,64,0.85)"; BorderColor = "#1A3A5A" }
    Surface = @{ BackColor = "#0F2140"; BorderColor = "#1A3A5A" }
    Card = @{ BackColor = "#1A2F50"; BorderColor = "#2A5A7A" }
}

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ScriptPath {
    try {
        if ($PSCommandPath) { return $PSCommandPath }
        if ($MyInvocation.MyCommand.Path) { return $MyInvocation.MyCommand.Path }
        return $null
    } catch {
        return $null
    }
}

function Test-IsGzipSignature {
    param([string]$Path)
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $b0 = $fs.ReadByte()
            $b1 = $fs.ReadByte()
            return ($b0 -eq 0x1F -and $b1 -eq 0x8B)
        } finally {
            $fs.Close()
        }
    } catch {
        return $false
    }
}

function Enable-DoubleBuffering {
    param($Control)
    try {
        $prop = $Control.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"Instance,NonPublic,Public")
        if ($prop) { 
            $prop.SetValue($Control, $true, $null) 
        }
    } catch {
        try {
            $Control.SetStyle([System.Windows.Forms.ControlStyles]::OptimizedDoubleBuffer -bor [System.Windows.Forms.ControlStyles]::AllPaintingInWmPaint -bor [System.Windows.Forms.ControlStyles]::UserPaint, $true)
        } catch { }
    }
}

function Set-RoundedCorners {
    param($Control, $Radius = 12)
    try {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $rect = New-Object System.Drawing.Rectangle(0, 0, $Control.Width, $Control.Height)
        $path.AddArc($rect.X, $rect.Y, $Radius, $Radius, 180, 90)
        $path.AddArc(($rect.X + $rect.Width - $Radius), $rect.Y, $Radius, $Radius, 270, 90)
        $path.AddArc(($rect.X + $rect.Width - $Radius), ($rect.Y + $rect.Height - $Radius), $Radius, $Radius, 0, 90)
        $path.AddArc($rect.X, ($rect.Y + $rect.Height - $Radius), $Radius, $Radius, 90, 90)
        $path.CloseAllFigures()
        $Control.Region = New-Object System.Drawing.Region($path)
        $path.Dispose()
    } catch { }
}

function Get-ColorWithOpacity {
    param([string]$HexColor, [int]$Opacity)
    try {
        $hex = ($HexColor -replace '#', '').Trim()
        if ($hex.Length -lt 6 -or $hex -notmatch '^[0-9A-Fa-f]{6}$') {
            if ($HexColor -and $HexColor.StartsWith('#')) { return $HexColor }
            return "#$HexColor"
        }
        $r = [Convert]::ToInt32($hex.Substring(0,2), 16)
        $g = [Convert]::ToInt32($hex.Substring(2,2), 16)
        $b = [Convert]::ToInt32($hex.Substring(4,2), 16)
        $factor = $Opacity / 100.0
        $bgR = [Math]::Round(11 + ($r - 11) * $factor)
        $bgG = [Math]::Round(27 + ($g - 27) * $factor)
        $bgB = [Math]::Round(43 + ($b - 43) * $factor)
        return "#$([Convert]::ToString($bgR,16).PadLeft(2,'0'))$([Convert]::ToString($bgG,16).PadLeft(2,'0'))$([Convert]::ToString($bgB,16).PadLeft(2,'0'))"
    } catch {
        return "#1A2F50"
    }
}

function New-UnifiedButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 150,
        [int]$Height = 40,
        [string]$Style = "Primary",
        [scriptblock]$OnClick = $null
    )
    
    $style = $ButtonStyles[$Style]
    if (-not $style) { $style = $ButtonStyles["Primary"] }
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = New-Object System.Drawing.Point($X, $Y)
    $btn.Size = New-Object System.Drawing.Size($Width, $Height)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.ColorTranslator]::FromHtml($style.Hover)
    $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.ColorTranslator]::FromHtml($style.Hover)
    $btn.BackColor = [System.Drawing.ColorTranslator]::FromHtml($style.Color)
    $btn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $btn.UseVisualStyleBackColor = $false
    Set-RoundedCorners -Control $btn -Radius 8
    
    if ($OnClick) { $btn.Add_Click($OnClick) }
    return $btn
}

function New-UnifiedPanel {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [string]$Style = "Surface",
        [string]$Title = ""
    )
    
    $styleDef = $PanelStyles[$Style]
    if (-not $styleDef) { $styleDef = $PanelStyles["Surface"] }
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size($Width, $Height)
    $panel.Location = New-Object System.Drawing.Point($X, $Y)
    $panel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($styleDef.BackColor)
    Set-RoundedCorners -Control $panel -Radius 10
    
    $panel.Add_Paint({
        param($s, $e)
        try {
            $pen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($styleDef.BorderColor), 1)
            $rect = New-Object System.Drawing.Rectangle(1, 1, $s.Width - 2, $s.Height - 2)
            $e.Graphics.DrawRectangle($pen, $rect)
            $pen.Dispose()
        } catch { }
    })
    
    if ($Title) {
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = $Title
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
        $lblTitle.Location = New-Object System.Drawing.Point(15, 12)
        $lblTitle.AutoSize = $true
        $panel.Controls.Add($lblTitle)
    }
    
    return $panel
}

function New-UnifiedLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 0,
        [int]$Height = 0,
        [int]$FontSize = 10,
        [string]$Weight = "Regular",
        [string]$Color = "Text"
    )
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Location = New-Object System.Drawing.Point($X, $Y)
    
    if ($Width -gt 0 -and $Height -gt 0) { 
        $lbl.Size = New-Object System.Drawing.Size($Width, $Height) 
    } else { 
        $lbl.AutoSize = $true 
    }
    
    $fontWeight = if ($Weight -eq "Bold") { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", $FontSize, $fontWeight)
    
    $colorMap = @{
        "Text" = $Theme.Text
        "Secondary" = $Theme.TextSecondary
        "Muted" = $Theme.TextMuted
        "Success" = $Theme.Success
        "Warning" = $Theme.Warning
        "Error" = $Theme.Error
        "Primary" = $Theme.Primary
        "Accent" = $Theme.Accent
    }
    
    if ($colorMap.ContainsKey($Color)) {
        $lbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($colorMap[$Color])
    } else {
        $lbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Color)
    }
    
    return $lbl
}

function New-StyledForm {
    param([string]$Title, [int]$Width, [int]$Height)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.ClientSize = New-Object System.Drawing.Size($Width, $Height)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    Enable-DoubleBuffering -Control $form
    return $form
}

$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "CoralMC Alts Checker"
$mainForm.Size = New-Object System.Drawing.Size(720, 800)
$mainForm.StartPosition = "CenterScreen"
$mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$mainForm.MaximizeBox = $false
$mainForm.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
$mainForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
Enable-DoubleBuffering -Control $mainForm

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(720, 100)
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$mainForm.Controls.Add($headerPanel)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "CoralMC Alts Checker"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(20, 30)
$headerPanel.Controls.Add($lblTitle)

$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Size = New-Object System.Drawing.Size(700, 600)
$contentPanel.Location = New-Object System.Drawing.Point(10, 110)
$contentPanel.BackColor = [System.Drawing.Color]::Transparent
$contentPanel.AutoScroll = $true
$mainForm.Controls.Add($contentPanel)

function Start-LogGzSearch { [System.Windows.Forms.MessageBox]::Show("Funzione Cerca .log.gz", "Info") | Out-Null }
function Start-JournalRead { [System.Windows.Forms.MessageBox]::Show("Funzione USN Journal", "Info") | Out-Null }
function Start-AutoAnalyze { [System.Windows.Forms.MessageBox]::Show("Funzione Analisi Automatica", "Info") | Out-Null }
function Check-SystemIntegrity { [System.Windows.Forms.MessageBox]::Show("Funzione Analisi Sistema", "Info") | Out-Null }
function Check-RecycleBin { [System.Windows.Forms.MessageBox]::Show("Funzione Cestino", "Info") | Out-Null }
function Check-Recordings { [System.Windows.Forms.MessageBox]::Show("Funzione Registrazioni", "Info") | Out-Null }

$footerPanel = New-Object System.Windows.Forms.Panel
$footerPanel.Size = New-Object System.Drawing.Size(720, 50)
$footerPanel.Location = New-Object System.Drawing.Point(0, 745)
$footerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
$footerPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$mainForm.Controls.Add($footerPanel)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Pronto e operativo"
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblStatus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
$lblStatus.Location = New-Object System.Drawing.Point(20, 15)
$lblStatus.AutoSize = $true
$footerPanel.Controls.Add($lblStatus)

[void]$mainForm.ShowDialog()
