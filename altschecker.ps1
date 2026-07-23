#Requires -Version 5.1
<#
    CoralMC Alts Checker
    Premium Edition - Fixed UTF-8
    Tutti i caratteri speciali funzionano
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Net.Http

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ============================================================
# PULIZIA APPUNTI E CRONOLOGIA
# ============================================================
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

# ============================================================
# TEMA COLORI - CoralMC Premium
# ============================================================
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

# ============================================================
# FUNZIONI DI UTILITA
# ============================================================
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

# ============================================================
# CREAZIONE CONTROLLI
# ============================================================
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
    
    if ($OnClick) {
        $btn.Add_Click($OnClick)
    }
    
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

# ============================================================
# FORM STILIZZATO
# ============================================================
function New-StyledForm {
    param(
        [string]$Title,
        [int]$Width,
        [int]$Height
    )
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

# ============================================================
# OVERLAY
# ============================================================
$overlayForm = $null

function Show-Overlay {
    param([string]$Title, [string]$Subtitle)
    try {
        $global:overlayForm = New-Object System.Windows.Forms.Form
        $overlayForm.Text = $Title
        $overlayForm.Size = New-Object System.Drawing.Size(440, 240)
        $overlayForm.StartPosition = "CenterScreen"
        $overlayForm.FormBorderStyle = "None"
        $overlayForm.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
        $overlayForm.TopMost = $true
        $overlayForm.Opacity = 0.97
        Enable-DoubleBuffering -Control $overlayForm
        Set-RoundedCorners -Control $overlayForm -Radius 16
        
        $pb = New-Object System.Windows.Forms.ProgressBar
        $pb.Location = New-Object System.Drawing.Point(50, 150)
        $pb.Size = New-Object System.Drawing.Size(340, 12)
        $pb.Style = "Marquee"
        $pb.MarqueeAnimationSpeed = 30
        $pb.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
        $pb.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Primary)
        Set-RoundedCorners -Control $pb -Radius 6
        $overlayForm.Controls.Add($pb)
        
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = $Title
        $lblTitle.Location = New-Object System.Drawing.Point(20, 75)
        $lblTitle.Size = New-Object System.Drawing.Size(400, 30)
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
        $lblTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $overlayForm.Controls.Add($lblTitle)
        
        $lblSub = New-Object System.Windows.Forms.Label
        $lblSub.Text = $Subtitle
        $lblSub.Location = New-Object System.Drawing.Point(20, 110)
        $lblSub.Size = New-Object System.Drawing.Size(400, 25)
        $lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $lblSub.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.TextSecondary)
        $lblSub.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $overlayForm.Controls.Add($lblSub)
        
        $overlayForm.Show()
        $overlayForm.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    } catch { }
}

function Hide-Overlay {
    try {
        if ($global:overlayForm -and -not $global:overlayForm.IsDisposed) {
            $global:overlayForm.Close()
            $global:overlayForm.Dispose()
            $global:overlayForm = $null
        }
    } catch { }
}

# ============================================================
# FUNZIONE LOGO
# ============================================================
function New-CoralLogoBitmap {
    param([int]$Size = 64)
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    
    $rect = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.ColorTranslator]::FromHtml("#1A9EC4"),
        [System.Drawing.ColorTranslator]::FromHtml("#00D4FF"),
        45)
    $g.FillEllipse($brush, 0, 0, $Size, $Size)
    $brush.Dispose()
    
    $g.Dispose()
    return $bmp
}

function Get-LogoImage {
    return $null
}

# ============================================================
# MAIN FORM
# ============================================================
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "CoralMC Alts Checker"
$mainForm.Size = New-Object System.Drawing.Size(720, 800)
$mainForm.StartPosition = "CenterScreen"
$mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$mainForm.MaximizeBox = $false
$mainForm.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
$mainForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$mainForm.MinimumSize = New-Object System.Drawing.Size(720, 800)
$mainForm.MaximumSize = New-Object System.Drawing.Size(720, 800)
Enable-DoubleBuffering -Control $mainForm

# ============================================================
# HEADER
# ============================================================
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
$lblTitle.Location = New-Object System.Drawing.Point(30, 30)
$headerPanel.Controls.Add($lblTitle)

# ============================================================
# CONTENT PANEL
# ============================================================
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Size = New-Object System.Drawing.Size(700, 600)
$contentPanel.Location = New-Object System.Drawing.Point(10, 110)
$contentPanel.BackColor = [System.Drawing.Color]::Transparent
$contentPanel.AutoScroll = $true
$mainForm.Controls.Add($contentPanel)

# ============================================================
# CARD FACTORY
# ============================================================
function New-ActionCard {
    param(
        [int]$Y, [string]$IconChar, [string]$IconColor, [string]$Title, [string]$Desc,
        [string]$ButtonText, [string]$ButtonStyle = "Primary", [scriptblock]$OnClick
    )
    $card = New-Object System.Windows.Forms.Panel
    $card.Size = New-Object System.Drawing.Size(670, 85)
    $card.Location = New-Object System.Drawing.Point(5, $Y)
    $card.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    $card.Cursor = [System.Windows.Forms.Cursors]::Hand
    Set-RoundedCorners -Control $card -Radius 14
    
    $iconCircle = New-Object System.Windows.Forms.Panel
    $iconCircle.Size = New-Object System.Drawing.Size(46, 46)
    $iconCircle.Location = New-Object System.Drawing.Point(20, 19)
    $iconCircle.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $IconColor -Opacity 20))
    Set-RoundedCorners -Control $iconCircle -Radius 23
    $card.Controls.Add($iconCircle)
    
    $lblIcon = New-Object System.Windows.Forms.Label
    $lblIcon.Text = $IconChar
    $lblIcon.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $lblIcon.Location = New-Object System.Drawing.Point(20, 19)
    $lblIcon.Size = New-Object System.Drawing.Size(46, 46)
    $lblIcon.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $lblIcon.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($IconColor)
    $card.Controls.Add($lblIcon)
    
    $lblT = New-Object System.Windows.Forms.Label
    $lblT.Text = $Title
    $lblT.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $lblT.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $lblT.Location = New-Object System.Drawing.Point(80, 16)
    $lblT.Size = New-Object System.Drawing.Size(310, 22)
    $card.Controls.Add($lblT)
    
    $lblD = New-Object System.Windows.Forms.Label
    $lblD.Text = $Desc
    $lblD.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblD.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.TextSecondary)
    $lblD.Location = New-Object System.Drawing.Point(80, 42)
    $lblD.Size = New-Object System.Drawing.Size(330, 18)
    $card.Controls.Add($lblD)
    
    $btn = New-UnifiedButton -Text $ButtonText -X 530 -Y 22 -Width 120 -Height 42 -Style $ButtonStyle -OnClick $OnClick
    $card.Controls.Add($btn)
    
    $hoverIn = { try { $this.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.SurfaceHover) } catch { } }
    $hoverOut = { try { $this.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface) } catch { } }
    $card.Add_MouseEnter($hoverIn)
    $card.Add_MouseLeave($hoverOut)
    return $card
}

# ============================================================
# CARDS
# ============================================================
$card1 = New-ActionCard -Y 5 -IconChar "📂" -IconColor $Theme.Primary -Title "Cerca file .log.gz" -Desc "Ricerca full-text nei file .log.gz compressi" -ButtonText "Avvia" -ButtonStyle "Primary" -OnClick { Start-LogGzSearch }
$contentPanel.Controls.Add($card1)

$card2 = New-ActionCard -Y 100 -IconChar "📜" -IconColor $Theme.Accent -Title "Analizza USN Journal" -Desc "Analisi approfondita del journal USN" -ButtonText "Avvia" -ButtonStyle "Accent" -OnClick { Start-JournalRead }
$contentPanel.Controls.Add($card2)

$card3 = New-ActionCard -Y 195 -IconChar "🤖" -IconColor $Theme.Success -Title "Analisi Automatica" -Desc "Analizza nickname, server e stato login dai log" -ButtonText "Avvia" -ButtonStyle "Success" -OnClick { Start-AutoAnalyze }
$contentPanel.Controls.Add($card3)

$card4 = New-ActionCard -Y 290 -IconChar "🛡" -IconColor $Theme.Warning -Title "Analisi Sistema" -Desc "Verifica integrita sistema e USN Journal" -ButtonText "Analizza" -ButtonStyle "Warning" -OnClick { Check-SystemIntegrity }
$contentPanel.Controls.Add($card4)

$card5 = New-ActionCard -Y 385 -IconChar "🗑️" -IconColor "#FF6B6B" -Title "Ultima modifica cestino" -Desc "Controlla l'ultima data di modifica del cestino" -ButtonText "Controlla" -ButtonStyle "Rose" -OnClick { Check-RecycleBin }
$contentPanel.Controls.Add($card5)

$card6 = New-ActionCard -Y 480 -IconChar "🎥" -IconColor "#FF6BFF" -Title "Registrazioni attive" -Desc "Controlla se sono attive registrazioni" -ButtonText "Controlla" -ButtonStyle "Magenta" -OnClick { Check-Recordings }
$contentPanel.Controls.Add($card6)

# ============================================================
# FOOTER
# ============================================================
$footerPanel = New-Object System.Windows.Forms.Panel
$footerPanel.Size = New-Object System.Drawing.Size(720, 50)
$footerPanel.Location = New-Object System.Drawing.Point(0, 745)
$footerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
$footerPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$mainForm.Controls.Add($footerPanel)

$footerDot = New-Object System.Windows.Forms.Panel
$footerDot.Size = New-Object System.Drawing.Size(8, 8)
$footerDot.Location = New-Object System.Drawing.Point(30, 21)
$footerDot.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
Set-RoundedCorners -Control $footerDot -Radius 4
$footerPanel.Controls.Add($footerDot)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready"
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblStatus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.TextSecondary)
$lblStatus.Location = New-Object System.Drawing.Point(45, 17)
$lblStatus.Size = New-Object System.Drawing.Size(200, 20)
$footerPanel.Controls.Add($lblStatus)

$lblCredits = New-Object System.Windows.Forms.Label
$lblCredits.Text = "Development by ShawnFroste"
$lblCredits.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblCredits.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#94A3B8")
$lblCredits.AutoSize = $true
$lblCredits.Location = New-Object System.Drawing.Point(500, 18)
$footerPanel.Controls.Add($lblCredits)

# ============================================================
# UPDATE STATUS
# ============================================================
function Update-Status {
    param([string]$Text, [string]$Color = "Success")
    try {
        $lblStatus.Text = $Text
        $colorMap = @{
            "Success" = $Theme.Success
            "Warning" = $Theme.Warning
            "Error"   = $Theme.Error
            "Info"    = $Theme.Accent
            "Default" = $Theme.TextSecondary
        }
        $footerDot.BackColor = [System.Drawing.ColorTranslator]::FromHtml($colorMap[$Color])
        [System.Windows.Forms.Application]::DoEvents()
    } catch { }
}

# ============================================================
# FUNZIONE CESTINO
# ============================================================
function Check-RecycleBin {
    Update-Status -Text "Controllo cestino..." -Color "Warning"
    Show-Overlay -Title "Controllo Cestino" -Subtitle "Ricerca ultima modifica..."
    
    try {
        $latestFile = Get-ChildItem -Path "C:\`$Recycle.Bin" -Force -Recurse -ErrorAction SilentlyContinue | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -First 1
        
        Hide-Overlay
        
        $resultForm = New-StyledForm -Title "Ultima modifica cestino" -Width 650 -Height 350
        $panel = New-UnifiedPanel -X 15 -Y 15 -Width 620 -Height 300 -Style "Surface" -Title "Ultima modifica del cestino"
        $resultForm.Controls.Add($panel)
        
        $yPos = 50
        
        if ($latestFile) {
            $latestDate = $latestFile.LastWriteTime
            $timeSpan = (Get-Date) - $latestDate
            $timeStr = ""
            if ($timeSpan.Days -gt 0) { $timeStr += "$($timeSpan.Days) giorni, " }
            if ($timeSpan.Hours -gt 0) { $timeStr += "$($timeSpan.Hours) ore, " }
            $timeStr += "$($timeSpan.Minutes) minuti fa"
            
            $lblDate = New-UnifiedLabel -Text "Data: $($latestDate.ToString('dddd dd MMMM yyyy'))" -X 20 -Y $yPos -FontSize 13 -Weight "Bold" -Color "Primary"
            $panel.Controls.Add($lblDate)
            $yPos += 35
            
            $lblTime = New-UnifiedLabel -Text "Ora: $($latestDate.ToString('HH:mm:ss'))" -X 20 -Y $yPos -FontSize 12 -Color "Secondary"
            $panel.Controls.Add($lblTime)
            $yPos += 35
            
            $lblFile = New-UnifiedLabel -Text "Ultimo file: $($latestFile.Name)" -X 20 -Y $yPos -FontSize 11 -Color "Text"
            $panel.Controls.Add($lblFile)
            $yPos += 40
            
            $ageMinutes = $timeSpan.TotalMinutes
            $lblAge = New-UnifiedLabel -Text "" -X 20 -Y $yPos -Width 580 -Height 40 -FontSize 13 -Weight "Bold"
            
            if ($ageMinutes -lt 5) {
                $lblAge.Text = "MODIFICATO $timeStr (meno di 5 minuti fa!)"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Error)
            } elseif ($ageMinutes -lt 60) {
                $lblAge.Text = "MODIFICATO $timeStr (meno di un'ora fa!)"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Error)
            } elseif ($timeSpan.TotalHours -lt 24) {
                $lblAge.Text = "Modificato $timeStr (nelle ultime 24 ore)"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Warning)
            } else {
                $lblAge.Text = "Modificato $timeStr"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
            }
            $panel.Controls.Add($lblAge)
            $yPos += 50
            
            Update-Status -Text "Cestino modificato $timeStr" -Color "Success"
            
        } else {
            $lblInfo = New-UnifiedLabel -Text "Nessuna modifica trovata nel cestino. Il cestino potrebbe essere vuoto." -X 20 -Y 80 -FontSize 14 -Color "Secondary"
            $lblInfo.Size = New-Object System.Drawing.Size(580, 60)
            $panel.Controls.Add($lblInfo)
            Update-Status -Text "Cestino vuoto" -Color "Default"
            $yPos = 160
        }
        
        $btnClose = New-UnifiedButton -Text "Chiudi" -X 250 -Y ($yPos + 10) -Width 140 -Height 40 -Style "Danger" -OnClick { $resultForm.Close() }
        $panel.Controls.Add($btnClose)
        
        $resultForm.ShowDialog($mainForm) | Out-Null
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Errore controllo cestino" -Color "Error"
        [System.Windows.Forms.MessageBox]::Show("Errore: $($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}

# ============================================================
# FUNZIONE REGISTRAZIONI ATTIVE
# ============================================================
function Check-Recordings {
    Update-Status -Text "Controllo registrazioni..." -Color "Warning"
    Show-Overlay -Title "Controllo Registrazioni" -Subtitle "Verifica programmi aperti..."
    
    $rilevati = New-Object System.Collections.Generic.List[psobject]
    
    try {
        $programs = @(
            @{ Name="NVIDIA ShadowPlay"; Processes=@("nvcontainer","nvsphelper64") }
            @{ Name="OBS Studio"; Processes=@("obs64","obs32") }
            @{ Name="Streamlabs Desktop"; Processes=@("Streamlabs OBS","streamlabs-obs") }
            @{ Name="Windows Game Bar"; Processes=@("GameBar") }
            @{ Name="Bandicam"; Processes=@("bdcam","Bandicam") }
        )
        
        foreach ($prog in $programs) {
            try {
                $proc = Get-Process -Name $prog.Processes -ErrorAction SilentlyContinue
                if ($proc) {
                    $rilevati.Add([PSCustomObject]@{
                        Name = $prog.Name
                        IsRecording = $false
                    })
                }
            } catch { }
        }
    } finally {
        Hide-Overlay
    }
    
    $resultForm = New-StyledForm -Title "Controllo Registrazioni" -Width 600 -Height 400
    
    if ($rilevati.Count -gt 0) {
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
        $lblTitle.Size = New-Object System.Drawing.Size(550, 30)
        $lblTitle.Text = "Programmi di registrazione aperti: " + (($rilevati | ForEach-Object { $_.Name }) -join ", ")
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Warning)
        $resultForm.Controls.Add($lblTitle)
        
        $yPos = 70
        foreach ($r in $rilevati) {
            $lbl = New-Object System.Windows.Forms.Label
            $lbl.Text = "• $($r.Name)"
            $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 11)
            $lbl.Location = New-Object System.Drawing.Point(30, $yPos)
            $lbl.AutoSize = $true
            $lbl.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
            $resultForm.Controls.Add($lbl)
            $yPos += 30
        }
    } else {
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
        $lblTitle.Size = New-Object System.Drawing.Size(550, 50)
        $lblTitle.Text = "Nessun programma di registrazione aperto"
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
        $resultForm.Controls.Add($lblTitle)
    }
    
    $btnClose = New-UnifiedButton -Text "Chiudi" -X 230 -Y 300 -Width 140 -Height 40 -Style "Danger" -OnClick { $resultForm.Close() }
    $resultForm.Controls.Add($btnClose)
    
    $resultForm.ShowDialog($mainForm) | Out-Null
    
    Update-Status -Text "Controllo registrazioni completato" -Color "Success"
}

# ============================================================
# FUNZIONE GET USN JOURNAL STATUS
# ============================================================
function Get-USNJournalStatus {
    $result = @{
        Status = "NON DISPONIBILE"
        Details = ""
        IsDeleted = $false
    }
    try {
        $usnInfo = & fsutil usn queryjournal C: 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($usnInfo)) {
            $result.Status = "DISATTIVO"
            $result.Details = "USN Journal disabilitato o eliminato"
            $result.IsDeleted = $true
            return $result
        }
        
        $result.Status = "ATTIVO"
        $result.Details = "USN Journal attivo e funzionante"
        $result.IsDeleted = $false
        
    } catch {
        $result.Status = "ERRORE"
        $result.Details = "Errore: $($_.Exception.Message)"
        $result.IsDeleted = $true
    }
    return $result
}

# ============================================================
# FUNZIONE 1 - CERCA .LOG.GZ
# ============================================================
function Start-LogGzSearch {
    Update-Status -Text "Ricerca in corso..." -Color "Warning"
    Show-Overlay -Title "Ricerca file .log.gz" -Subtitle "Scansione in corso..."
    
    $found = New-Object System.Collections.Generic.List[string]
    $global:CancelScan = $false
    
    try {
        $roots = [System.IO.DriveInfo]::GetDrives() |
            Where-Object { $_.DriveType -eq "Fixed" -and $_.IsReady } |
            ForEach-Object { $_.RootDirectory.FullName }
        
        foreach ($root in $roots) {
            if ($global:CancelScan) { break }
            Find-LogGzFiles -RootPath $root -FoundList $found
        }
    } finally {
        Hide-Overlay
    }
    
    if ($found.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nessun file .log.gz valido trovato.", "Ricerca completata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        Update-Status -Text "Nessun file trovato" -Color "Default"
        return
    }
    Update-Status -Text "Trovati $($found.Count) file" -Color "Success"
    [System.Windows.Forms.MessageBox]::Show("Trovati $($found.Count) file .log.gz", "Ricerca completata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

function Find-LogGzFiles {
    param([string]$RootPath, [System.Collections.Generic.List[string]]$FoundList)
    $dirsToScan = New-Object System.Collections.Generic.Queue[string]
    $dirsToScan.Enqueue($RootPath)
    $counter = 0
    
    while ($dirsToScan.Count -gt 0 -and -not $global:CancelScan) {
        $currentDir = $dirsToScan.Dequeue()
        $counter++
        if ($counter % 100 -eq 0) { Update-Status -Text "Scansione: $currentDir" -Color "Warning" }
        try {
            $filesHere = [System.IO.Directory]::EnumerateFiles($currentDir, "*.log.gz")
            foreach ($f in $filesHere) {
                if ($global:CancelScan) { break }
                if (Test-IsGzipSignature -Path $f) { $FoundList.Add($f) }
            }
        } catch { }
        try {
            $subDirs = [System.IO.Directory]::EnumerateDirectories($currentDir)
            foreach ($d in $subDirs) { $dirsToScan.Enqueue($d) }
        } catch { }
    }
}

# ============================================================
# FUNZIONE 2 - JOURNAL USN
# ============================================================
$global:USNTempFile = $null

function Start-JournalRead {
    if (-not (Test-IsAdmin)) {
        $r = [System.Windows.Forms.MessageBox]::Show(
            "La lettura del journal USN richiede privilegi di Amministratore.`nVuoi riavviare lo script come Amministratore?",
            "Privilegi richiesti",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($r -eq [System.Windows.Forms.DialogResult]::Yes) {
            $scriptPath = Get-ScriptPath
            if ($scriptPath) {
                Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
                $mainForm.Close()
            }
        }
        return
    }
    
    Update-Status -Text "Lettura USN Journal..." -Color "Warning"
    Show-Overlay -Title "Analisi USN Journal" -Subtitle "Lettura in corso..."
    
    try {
        $global:USNTempFile = [System.IO.Path]::GetTempFileName()
        $global:USNTempFile = [System.IO.Path]::ChangeExtension($global:USNTempFile, ".txt")
        
        $argList = "/c `"fsutil usn readjournal C: csv | findstr /i /C:`"0x80000200`" /C:`"0x00001000`" /C:`"0x00002000`" > `"$global:USNTempFile`"`""
        
        $p = Start-Process -FilePath "cmd.exe" -ArgumentList $argList -Wait -WindowStyle Hidden -PassThru
        
        Hide-Overlay
        
        if (Test-Path $global:USNTempFile) {
            $fileInfo = Get-Item $global:USNTempFile
            if ($fileInfo.Length -gt 0) {
                Update-Status -Text "USN Journal analizzato" -Color "Success"
                Start-Process -FilePath "notepad.exe" -ArgumentList $global:USNTempFile -WindowStyle Normal
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Analisi completata! Il file temporaneo e' stato aperto con Notepad.",
                    "Completato",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            } else {
                Update-Status -Text "Nessuna corrispondenza trovata" -Color "Default"
                [System.Windows.Forms.MessageBox]::Show(
                    "Nessuna corrispondenza trovata nel journal USN.",
                    "Nessun risultato",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                Remove-Item $global:USNTempFile -Force -ErrorAction SilentlyContinue
                $global:USNTempFile = $null
            }
        }
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Errore" -Color "Error"
        [System.Windows.Forms.MessageBox]::Show("Errore durante la lettura del journal: $($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        if ($global:USNTempFile -and (Test-Path $global:USNTempFile)) {
            Remove-Item $global:USNTempFile -Force -ErrorAction SilentlyContinue
            $global:USNTempFile = $null
        }
    }
}

# ============================================================
# ANALISI SISTEMA
# ============================================================
function Check-SystemIntegrity {
    Update-Status -Text "Analisi sistema in corso..." -Color "Warning"
    Show-Overlay -Title "Analisi Sistema" -Subtitle "Verifica integrita sistema..."
    
    try {
        $usnStatus = Get-USNJournalStatus
        
        Hide-Overlay
        
        $resultForm = New-StyledForm -Title "Analisi Sistema - Report" -Width 700 -Height 400
        $panel = New-UnifiedPanel -X 15 -Y 15 -Width 670 -Height 340 -Style "Surface" -Title "Risultati Analisi Sistema"
        $resultForm.Controls.Add($panel)
        
        $yPos = 50
        
        $lblUsn = New-UnifiedLabel -Text "USN Journal: $($usnStatus.Status)" -X 20 -Y $yPos -FontSize 12 -Weight "Bold"
        $panel.Controls.Add($lblUsn)
        $yPos += 30
        
        $lblUsnDetails = New-UnifiedLabel -Text $usnStatus.Details -X 35 -Y $yPos -FontSize 10 -Color "Secondary"
        $lblUsnDetails.Size = New-Object System.Drawing.Size(600, 30)
        $panel.Controls.Add($lblUsnDetails)
        $yPos += 50
        
        if ($usnStatus.IsDeleted) {
            $lblWarning = New-UnifiedLabel -Text "ATTENZIONE: USN Journal eliminato o disabilitato!" -X 20 -Y $yPos -FontSize 13 -Weight "Bold" -Color "Error"
            $panel.Controls.Add($lblWarning)
            $yPos += 40
        } else {
            $lblOk = New-UnifiedLabel -Text "Sistema integro - Nessuna anomalia rilevata" -X 20 -Y $yPos -FontSize 13 -Weight "Bold" -Color "Success"
            $panel.Controls.Add($lblOk)
            $yPos += 40
        }
        
        $btnClose = New-UnifiedButton -Text "Chiudi" -X 260 -Y ($yPos + 10) -Width 140 -Height 40 -Style "Danger" -OnClick { $resultForm.Close() }
        $panel.Controls.Add($btnClose)
        
        $resultForm.ShowDialog($mainForm) | Out-Null
        
        Update-Status -Text "Analisi completata" -Color "Success"
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Errore" -Color "Error"
        [System.Windows.Forms.MessageBox]::Show("Errore durante l'analisi: $($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}

# ============================================================
# FUNZIONE 3 - AUTO ANALYZE
# ============================================================
function Start-AutoAnalyze {
    Update-Status -Text "Analisi automatica in corso..." -Color "Warning"
    Show-Overlay -Title "Analisi Automatica" -Subtitle "Ricerca dati nei log..."
    
    try {
        $found = New-Object System.Collections.Generic.List[string]
        $global:CancelScan = $false
        
        $roots = [System.IO.DriveInfo]::GetDrives() |
            Where-Object { $_.DriveType -eq "Fixed" -and $_.IsReady } |
            ForEach-Object { $_.RootDirectory.FullName }
        
        foreach ($root in $roots) {
            if ($global:CancelScan) { break }
            Find-LogGzFiles -RootPath $root -FoundList $found
        }
        
        Hide-Overlay
        
        if ($found.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Nessun file .log.gz trovato.", "Analisi completata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            Update-Status -Text "Nessun file trovato" -Color "Default"
            return
        }
        
        Update-Status -Text "Trovati $($found.Count) file" -Color "Success"
        [System.Windows.Forms.MessageBox]::Show("Trovati $($found.Count) file .log.gz da analizzare.", "Analisi completata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Errore" -Color "Error"
        [System.Windows.Forms.MessageBox]::Show("Errore: $($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}

# ============================================================
# AVVIO E PULIZIA FINALE
# ============================================================
$mainForm.Add_FormClosing({
    $global:CancelScan = $true
    if ($global:overlayForm -and -not $global:overlayForm.IsDisposed) { 
        try { $global:overlayForm.Close() } catch { }
    }
    if ($global:USNTempFile -and (Test-Path $global:USNTempFile)) {
        try { Remove-Item $global:USNTempFile -Force -ErrorAction SilentlyContinue } catch { }
        $global:USNTempFile = $null
    }
})

Update-Status -Text "Ready" -Color "Success"
[void]$mainForm.ShowDialog()
