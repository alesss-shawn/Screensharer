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

# ========================================================================
# FUNZIONE PULIZIA APPUNTI E CRONOLOGIA (WIN+V)
# ========================================================================
function Clear-WindowsClipboardHistory {
    try {
        # 1. Pulisce la clipboard attiva
        [System.Windows.Forms.Clipboard]::Clear()
        Set-Clipboard -Value $null -ErrorAction SilentlyContinue

        # 2. Metodo UWP nativo per Windows 10/11 (Pulisce la cronologia Win+V via API)
        try {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime
            $asTask = ([Windows.ApplicationModel.DataTransfer.Clipboard].GetMethod('ClearHistory', [System.Reflection.BindingFlags]'Public,Static'))
            if ($asTask) {
                $null = $asTask.Invoke($null, $null)
            }
        } catch { }

        # 3. Interrompe e pulisce il servizio di cronologia appunti di Windows (cbdhsvc)
        $clipboardServices = Get-Service -Name "cbdhsvc*" -ErrorAction SilentlyContinue
        foreach ($svc in $clipboardServices) {
            if ($svc.Status -eq 'Running') {
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            }
        }

        # 4. Rimuove i file di cache della cronologia nel profilo utente
        $clipboardHistoryPath = "$env:LOCALAPPDATA\Microsoft\Windows\Clipboard"
        if (Test-Path $clipboardHistoryPath) {
            Get-ChildItem -Path $clipboardHistoryPath -Recurse -Force -ErrorAction SilentlyContinue | 
                Where-Object { $_.PSIsContainer -eq $false } | 
                Remove-Item -Force -ErrorAction SilentlyContinue
        }

        # 5. Riavvia i servizi clipboard di sistema
        foreach ($svc in $clipboardServices) {
            Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
        }
    } catch { }
}

# Esegue la pulizia immediatamente all'avvio dello script
Clear-WindowsClipboardHistory

# ========================================================================
# COLOR THEME - CoralMC Premium
# ========================================================================
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

# ========================================================================
# STILI GRAFICI GLOBALI
# ========================================================================

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

# ========================================================================
# FUNZIONI DI UTILITA
# ========================================================================

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

# ========================================================================
# UNIFIED BUTTON
# ========================================================================

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
    
    $baseColor = [System.Drawing.ColorTranslator]::FromHtml($style.Color)
    $hoverColor = [System.Drawing.ColorTranslator]::FromHtml($style.Hover)
    $textColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
    $disabledColor = [System.Drawing.Color]::FromArgb(100, $baseColor.R, $baseColor.G, $baseColor.B)
    $disabledTextColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.TextMuted)
    
    $btn.Add_EnabledChanged({
        try {
            if ($this.Enabled) {
                $this.BackColor = $baseColor
                $this.ForeColor = $textColor
                $this.FlatAppearance.MouseOverBackColor = $hoverColor
            } else {
                $this.BackColor = $disabledColor
                $this.ForeColor = $disabledTextColor
                $this.FlatAppearance.MouseOverBackColor = $disabledColor
            }
            $this.Refresh()
        } catch { }
    })
    
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

# ========================================================================
# STYLED FORM
# ========================================================================

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
    
    $form.Add_Paint({
        param($s, $e)
        try {
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            
            $formWidth = $s.ClientSize.Width
            $formHeight = $s.ClientSize.Height
            
            $pen1 = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($Theme.Primary), 2)
            $w1 = if ($formWidth - 6 -gt 0) { $formWidth - 6 } else { 0 }
            $h1 = if ($formHeight - 6 -gt 0) { $formHeight - 6 } else { 0 }
            $rect1 = New-Object System.Drawing.Rectangle(2, 2, $w1, $h1)
            $g.DrawRectangle($pen1, $rect1)
            $pen1.Dispose()
            
            $pen2 = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($Theme.PrimaryLight), 1)
            $w2 = if ($formWidth - 10 -gt 0) { $formWidth - 10 } else { 0 }
            $h2 = if ($formHeight - 10 -gt 0) { $formHeight - 10 } else { 0 }
            $rect2 = New-Object System.Drawing.Rectangle(4, 4, $w2, $h2)
            $g.DrawRectangle($pen2, $rect2)
            $pen2.Dispose()
            
            $pen3 = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($Theme.Accent), 2)
            $g.DrawLine($pen3, 15, 2, 35, 2)
            $g.DrawLine($pen3, 2, 15, 2, 35)
            $g.DrawLine($pen3, ($formWidth - 15), 2, ($formWidth - 35), 2)
            $g.DrawLine($pen3, ($formWidth - 2), 15, ($formWidth - 2), 35)
            $g.DrawLine($pen3, 15, ($formHeight - 2), 35, ($formHeight - 2))
            $g.DrawLine($pen3, 2, ($formHeight - 15), 2, ($formHeight - 35))
            $g.DrawLine($pen3, ($formWidth - 15), ($formHeight - 2), ($formWidth - 35), ($formHeight - 2))
            $g.DrawLine($pen3, ($formWidth - 2), ($formHeight - 15), ($formWidth - 2), ($formHeight - 35))
            $pen3.Dispose()
        } catch { }
    })
    
    return $form
}

# ========================================================================
# OVERLAY
# ========================================================================

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
        
        $overlayForm.Add_Paint({
            param($s, $e)
            $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $pen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($Theme.Primary), 2)
            $w = if ($s.Width - 2 -gt 0) { $s.Width - 2 } else { 0 }
            $h = if ($s.Height - 2 -gt 0) { $s.Height - 2 } else { 0 }
            $rect = New-Object System.Drawing.Rectangle(1, 1, $w, $h)
            $e.Graphics.DrawRectangle($pen, $rect)
            $pen.Dispose()
        })
        
        $logoPath = Get-LogoImage
        $pbLogoOverlay = New-Object System.Windows.Forms.PictureBox
        $pbLogoOverlay.Size = New-Object System.Drawing.Size(50, 50)
        $pbLogoOverlay.Location = New-Object System.Drawing.Point(195, 15)
        $pbLogoOverlay.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        if ($logoPath -and (Test-Path $logoPath)) {
            try { $pbLogoOverlay.Image = [System.Drawing.Image]::FromFile($logoPath) } catch { $pbLogoOverlay.Image = New-CoralLogoBitmap -Size 50 }
        } else {
            $pbLogoOverlay.Image = New-CoralLogoBitmap -Size 50
        }
        $overlayForm.Controls.Add($pbLogoOverlay)
        
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
        
        $pb = New-Object System.Windows.Forms.ProgressBar
        $pb.Location = New-Object System.Drawing.Point(50, 150)
        $pb.Size = New-Object System.Drawing.Size(340, 12)
        $pb.Style = "Marquee"
        $pb.MarqueeAnimationSpeed = 30
        $pb.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
        $pb.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Primary)
        Set-RoundedCorners -Control $pb -Radius 6
        $overlayForm.Controls.Add($pb)
        
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

# ========================================================================
# FUNZIONE LOGO
# ========================================================================

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
    
    $wavePen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#FFFFFF"), [Math]::Max(2, $Size / 16))
    $wavePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $wavePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $w = $Size
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier($w*0.10,$w*0.55, $w*0.30,$w*0.35, $w*0.45,$w*0.70, $w*0.62,$w*0.45)
    $path.AddBezier($w*0.62,$w*0.45, $w*0.75,$w*0.28, $w*0.85,$w*0.50, $w*0.92,$w*0.40)
    $g.DrawPath($wavePen, $path)
    $wavePen.Dispose()
    
    $accentBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#FF6B4A"))
    $g.FillEllipse($accentBrush, $w*0.62, $w*0.60, $w*0.14, $w*0.14)
    $accentBrush.Dispose()
    
    $g.Dispose()
    return $bmp
}

function Get-LogoImage {
    $scriptPath = Get-ScriptPath
    if ($scriptPath) {
        $localDir = Split-Path $scriptPath -Parent
        foreach ($name in @("coralmc_logo.png", "logo.png")) {
            $candidate = Join-Path $localDir $name
            if (Test-Path $candidate) { return $candidate }
        }
    }
    $tempPath = Join-Path $env:TEMP "coralmc_logo.png"
    if (Test-Path $tempPath) { return $tempPath }
    $logoUrl = "https://i.imgur.com/EJSZn07.png"
    try {
        $client = New-Object System.Net.Http.HttpClient
        $client.Timeout = [System.TimeSpan]::FromSeconds(6)
        $response = $client.GetAsync($logoUrl).GetAwaiter().GetResult()
        if ($response.IsSuccessStatusCode) {
            $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            [System.IO.File]::WriteAllBytes($tempPath, $bytes)
            return $tempPath
        }
    } catch { }
    return $null
}

# ========================================================================
# CARD FACTORY
# ========================================================================

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
    $card.Add_Paint({
        param($s, $e)
        try {
            $pen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($Theme.Primary), 1)
            $pen.Color = [System.Drawing.Color]::FromArgb(30, 0, 212, 255)
            $w = if ($s.Width - 3 -gt 0) { $s.Width - 3 } else { 0 }
            $h = if ($s.Height - 3 -gt 0) { $s.Height - 3 } else { 0 }
            $rect = New-Object System.Drawing.Rectangle(1, 1, $w, $h)
            $e.Graphics.DrawRectangle($pen, $rect)
            $pen.Dispose()
        } catch { }
    })
    $accentBar = New-Object System.Windows.Forms.Panel
    $accentBar.Size = New-Object System.Drawing.Size(4, 85)
    $accentBar.Location = New-Object System.Drawing.Point(0, 0)
    $accentBar.BackColor = [System.Drawing.ColorTranslator]::FromHtml($IconColor)
    $card.Controls.Add($accentBar)
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

# ========================================================================
# MAIN FORM
# ========================================================================

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

$mainForm.Add_Paint({
    param($s, $e)
    try {
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        
        $formWidth = $s.ClientSize.Width
        $formHeight = $s.ClientSize.Height
        
        $pen1 = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($Theme.Primary), 2)
        $w1 = if ($formWidth - 6 -gt 0) { $formWidth - 6 } else { 0 }
        $h1 = if ($formHeight - 6 -gt 0) { $formHeight - 6 } else { 0 }
        $rect1 = New-Object System.Drawing.Rectangle(2, 2, $w1, $h1)
        $g.DrawRectangle($pen1, $rect1)
        $pen1.Dispose()
        
        $pen2 = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($Theme.PrimaryLight), 1)
        $w2 = if ($formWidth - 10 -gt 0) { $formWidth - 10 } else { 0 }
        $h2 = if ($formHeight - 10 -gt 0) { $formHeight - 10 } else { 0 }
        $rect2 = New-Object System.Drawing.Rectangle(4, 4, $w2, $h2)
        $g.DrawRectangle($pen2, $rect2)
        $pen2.Dispose()
        
        $pen3 = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($Theme.Accent), 2)
        $g.DrawLine($pen3, 15, 2, 35, 2)
        $g.DrawLine($pen3, 2, 15, 2, 35)
        $g.DrawLine($pen3, ($formWidth - 15), 2, ($formWidth - 35), 2)
        $g.DrawLine($pen3, ($formWidth - 2), 15, ($formWidth - 2), 35)
        $g.DrawLine($pen3, 15, ($formHeight - 2), 35, ($formHeight - 2))
        $g.DrawLine($pen3, 2, ($formHeight - 15), 2, ($formHeight - 35))
        $g.DrawLine($pen3, ($formWidth - 15), ($formHeight - 2), ($formWidth - 35), ($formHeight - 2))
        $g.DrawLine($pen3, ($formWidth - 2), ($formHeight - 15), ($formWidth - 2), ($formHeight - 35))
        $pen3.Dispose()
    } catch { }
})

# ========================================================================
# HEADER
# ========================================================================

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(720, 100)
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$mainForm.Controls.Add($headerPanel)

$headerPanel.Add_Paint({
    param($s, $e)
    try {
        $rect = New-Object System.Drawing.Rectangle(0, 0, $s.ClientSize.Width, $s.ClientSize.Height)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect,
            [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface),
            [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Primary -Opacity 15)),
            0)
        $e.Graphics.FillRectangle($brush, $rect)
        $brush.Dispose()
    } catch { }
})

$accentLine = New-Object System.Windows.Forms.Panel
$accentLine.Size = New-Object System.Drawing.Size(720, 2)
$accentLine.Location = New-Object System.Drawing.Point(0, 0)
$accentLine.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Primary)
$headerPanel.Controls.Add($accentLine)

$logoPath = Get-LogoImage
$logoBox = New-Object System.Windows.Forms.Panel
$logoBox.Size = New-Object System.Drawing.Size(60, 60)
$logoBox.Location = New-Object System.Drawing.Point(20, 20)
Set-RoundedCorners -Control $logoBox -Radius 30
$headerPanel.Controls.Add($logoBox)

$pbLogo = New-Object System.Windows.Forms.PictureBox
$pbLogo.Size = New-Object System.Drawing.Size(60, 60)
$pbLogo.Location = New-Object System.Drawing.Point(0, 0)
$pbLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
if ($logoPath -and (Test-Path $logoPath)) {
    try { $pbLogo.Image = [System.Drawing.Image]::FromFile($logoPath) } catch { $pbLogo.Image = New-CoralLogoBitmap -Size 60 }
} else {
    $pbLogo.Image = New-CoralLogoBitmap -Size 60
}
$logoBox.Controls.Add($pbLogo)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "CoralMC Alts Checker"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(95, 30)
$headerPanel.Controls.Add($lblTitle)

# ========================================================================
# CONTENT PANEL
# ========================================================================

$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Size = New-Object System.Drawing.Size(700, 600)
$contentPanel.Location = New-Object System.Drawing.Point(10, 110)
$contentPanel.BackColor = [System.Drawing.Color]::Transparent
$contentPanel.AutoScroll = $true
$mainForm.Controls.Add($contentPanel)

# ========================================================================
# CARDS
# ========================================================================

$card1 = New-ActionCard -Y 5 -IconChar "📂" -IconColor $Theme.Primary -Title "Cerca file .log.gz" -Desc "Ricerca full-text nei file .log.gz compressi" -ButtonText "Avvia" -ButtonStyle "Primary" -OnClick { Start-LogGzSearch }
$contentPanel.Controls.Add($card1)

$card2 = New-ActionCard -Y 100 -IconChar "📜" -IconColor $Theme.Accent -Title "Analizza USN Journal" -Desc "Analisi approfondita del journal USN (richiede Admin)" -ButtonText "Avvia" -ButtonStyle "Accent" -OnClick { Start-JournalRead }
$contentPanel.Controls.Add($card2)

$card3 = New-ActionCard -Y 195 -IconChar "🤖" -IconColor $Theme.Success -Title "Analisi Automatica" -Desc "Analizza nickname, server e stato login dai log" -ButtonText "Avvia" -ButtonStyle "Success" -OnClick { Start-AutoAnalyze }
$contentPanel.Controls.Add($card3)

$card4 = New-ActionCard -Y 290 -IconChar "🛡" -IconColor $Theme.Warning -Title "Analisi Sistema" -Desc "Verifica integrita sistema e USN Journal" -ButtonText "Analizza" -ButtonStyle "Warning" -OnClick { Check-SystemIntegrity }
$contentPanel.Controls.Add($card4)

$card5 = New-ActionCard -Y 385 -IconChar "🗑️" -IconColor "#FF6B6B" -Title "Ultima modifica cestino" -Desc "Controlla l'ultima data di modifica del cestino" -ButtonText "Controlla" -ButtonStyle "Rose" -OnClick { Check-RecycleBin }
$contentPanel.Controls.Add($card5)

$card6 = New-ActionCard -Y 480 -IconChar "🎥" -IconColor "#FF6BFF" -Title "Registrazioni attive" -Desc "Controlla se sono attive registrazioni" -ButtonText "Controlla" -ButtonStyle "Magenta" -OnClick { Check-Recordings }
$contentPanel.Controls.Add($card6)

# ========================================================================
# FOOTER
# ========================================================================

$footerPanel = New-Object System.Windows.Forms.Panel
$footerPanel.Size = New-Object System.Drawing.Size(720, 50)
$footerPanel.Location = New-Object System.Drawing.Point(0, 745)
$footerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
$footerPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$mainForm.Controls.Add($footerPanel)

$footerLine = New-Object System.Windows.Forms.Panel
$footerLine.Size = New-Object System.Drawing.Size(720, 1)
$footerLine.Location = New-Object System.Drawing.Point(0, 0)
$footerLine.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Primary)
$footerPanel.Controls.Add($footerLine)

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
$lblStatus.Size = New-Object System.Drawing.Size(100, 20)
$footerPanel.Controls.Add($lblStatus)

$lblCredits = New-Object System.Windows.Forms.Label
$lblCredits.Text = "Development by "
$lblCredits.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblCredits.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#94A3B8")
$lblCredits.AutoSize = $true
$lblCredits.Location = New-Object System.Drawing.Point(480, 18)
$footerPanel.Controls.Add($lblCredits)

$lblName = New-Object System.Windows.Forms.Label
$lblName.Text = "ShawnFroste"
$lblName.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblName.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00D4FF")
$lblName.AutoSize = $true
$lblName.Location = New-Object System.Drawing.Point(595, 18)
$footerPanel.Controls.Add($lblName)

# ========================================================================
# UPDATE STATUS
# ========================================================================

$script:LastStatusUpdate = [DateTime]::MinValue

function Update-Status {
    param([string]$Text, [string]$Color = "Success", [switch]$Force)
    try {
        $now = [DateTime]::Now
        if (-not $Force -and ($now - $script:LastStatusUpdate).TotalMilliseconds -lt 80) { return }
        $script:LastStatusUpdate = $now
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

# ========================================================================
# FUNZIONE CESTINO
# ========================================================================

function Check-RecycleBin {
    Update-Status -Text "Controllo cestino..." -Color "Warning" -Force
    Show-Overlay -Title "Controllo Cestino" -Subtitle "Ricerca ultima modifica..."
    
    try {
        $latestFile = Get-ChildItem -Path "C:\`$Recycle.Bin" -Force -Recurse -ErrorAction SilentlyContinue | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -First 1
        
        Hide-Overlay
        
        $resultForm = New-StyledForm -Title "Ultima modifica cestino" -Width 650 -Height 350
        $panel = New-UnifiedPanel -X 15 -Y 15 -Width 620 -Height 300 -Style "Surface" -Title "🗑️ Ultima modifica del cestino"
        $resultForm.Controls.Add($panel)
        
        $yPos = 50
        
        if ($latestFile) {
            $latestDate = $latestFile.LastWriteTime
            $timeSpan = (Get-Date) - $latestDate
            $timeStr = ""
            if ($timeSpan.Days -gt 0) { $timeStr += "$($timeSpan.Days) giorni, " }
            if ($timeSpan.Hours -gt 0) { $timeStr += "$($timeSpan.Hours) ore, " }
            $timeStr += "$($timeSpan.Minutes) minuti fa"
            
            $lblDate = New-UnifiedLabel -Text "📅 $($latestDate.ToString('dddd dd MMMM yyyy'))" -X 20 -Y $yPos -FontSize 13 -Weight "Bold" -Color "Primary"
            $panel.Controls.Add($lblDate)
            $yPos += 35
            
            $lblTime = New-UnifiedLabel -Text "⏰ Ora: $($latestDate.ToString('HH:mm:ss'))" -X 20 -Y $yPos -FontSize 12 -Color "Secondary"
            $panel.Controls.Add($lblTime)
            $yPos += 35
            
            $lblFile = New-UnifiedLabel -Text "📁 Ultimo file: $($latestFile.Name)" -X 20 -Y $yPos -FontSize 11 -Color "Text"
            $panel.Controls.Add($lblFile)
            $yPos += 40
            
            $ageMinutes = $timeSpan.TotalMinutes
            $lblAge = New-UnifiedLabel -Text "" -X 20 -Y $yPos -Width 580 -Height 40 -FontSize 13 -Weight "Bold"
            
            if ($ageMinutes -lt 5) {
                $lblAge.Text = "🔴 MODIFICATO $timeStr (MOLTO RECENTE - meno di 5 minuti fa!)"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Error)
            } elseif ($ageMinutes -lt 60) {
                $lblAge.Text = "🔴 MODIFICATO $timeStr (meno di un'ora fa!)"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Error)
            } elseif ($timeSpan.TotalHours -lt 24) {
                $lblAge.Text = "⚠️ Modificato $timeStr (nelle ultime 24 ore)"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Warning)
            } else {
                $lblAge.Text = "✅ Modificato $timeStr"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
            }
            $panel.Controls.Add($lblAge)
            $yPos += 50
            
            Update-Status -Text "Cestino modificato $timeStr" -Color "Success" -Force
            
        } else {
            $lblInfo = New-UnifiedLabel -Text "📭 Nessuna modifica trovata nel cestino.`nIl cestino potrebbe essere vuoto." -X 20 -Y 80 -FontSize 14 -Color "Secondary"
            $lblInfo.Size = New-Object System.Drawing.Size(580, 60)
            $panel.Controls.Add($lblInfo)
            Update-Status -Text "Cestino vuoto" -Color "Default" -Force
            $yPos = 160
        }
        
        $btnRefresh = New-UnifiedButton -Text "🔄 Aggiorna" -X 170 -Y ($yPos + 10) -Width 140 -Height 40 -Style "Primary" -OnClick { 
            $resultForm.Close()
            Check-RecycleBin
        }
        $panel.Controls.Add($btnRefresh)
        
        $btnClose = New-UnifiedButton -Text "✖ Chiudi" -X 330 -Y ($yPos + 10) -Width 140 -Height 40 -Style "Danger" -OnClick { $resultForm.Close() }
        $panel.Controls.Add($btnClose)
        
        $resultForm.ShowDialog($mainForm) | Out-Null
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Errore controllo cestino" -Color "Error" -Force
        [System.Windows.Forms.MessageBox]::Show("Errore: $($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}

# ========================================================================
# TABELLA PROGRAMMI DI REGISTRAZIONE CONOSCIUTI
# ========================================================================

$script:RecordingPrograms = @(
    @{ Name="NVIDIA ShadowPlay";         Processes=@("nvcontainer","nvsphelper64");         Instructions="ALT+Z poi 'Stop Recording', oppure ALT+F9.`nPer chiuderlo: tasto destro sull'icona NVIDIA nella tray -> Esci." }
    @{ Name="OBS Studio";                Processes=@("obs64","obs32");                      Instructions="Clicca 'Stop Recording' o CTRL+SHIFT+E.`nPer chiuderlo: File -> Esci o X in alto a destra." }
    @{ Name="Streamlabs Desktop";        Processes=@("Streamlabs OBS","streamlabs-obs","Streamlabs"); Instructions="Clicca 'Stop Recording' nell'interfaccia.`nPer chiuderlo: File -> Esci o X in alto a destra." }
    @{ Name="AMD ReLive";                Processes=@("amdfendrsr","amdfendrmgr","RadeonSoftware"); Instructions="ALT+R poi 'Stop Recording', oppure CTRL+SHIFT+R.`nPer chiuderlo: tasto destro sull'icona AMD nella tray -> Esci." }
    @{ Name="Windows Game Bar";          Processes=@("GameBar","GameBarFTServer");          Instructions="WIN+G poi 'Stop Recording', oppure WIN+ALT+R.`nPer chiuderlo: WIN+G e chiudi la finestra." }
    @{ Name="Bandicam";                  Processes=@("bdcam","Bandicam");                   Instructions="F12 per fermare la registrazione.`nPer chiuderlo: File -> Esci." }
    @{ Name="Fraps";                     Processes=@("fraps");                              Instructions="F9 per fermare la registrazione.`nPer chiuderlo: tasto destro sulla tray -> Exit." }
    @{ Name="Action! (Mirillis)";        Processes=@("Action");                             Instructions="F9 per fermare la registrazione.`nPer chiuderlo: File -> Esci." }
    @{ Name="XSplit Broadcaster";        Processes=@("XSplit.Core","XSplit.Broadcaster");        Instructions="Clicca 'Stop' nella scheda Broadcast/Record.`nPer chiuderlo: chiudi la finestra principale." }
    @{ Name="Elgato Wirecast";           Processes=@("Wirecast");                           Instructions="Clicca 'Stop Recording'.`nPer chiuderlo: Wirecast -> Quit." }
    @{ Name="Camtasia Recorder";         Processes=@("CamtasiaStudio","TSCHelp","CamRecorder"); Instructions="Clicca lo Stop nel pannello di registrazione.`nPer chiuderlo: chiudi Camtasia Recorder dalla tray." }
    @{ Name="ShareX";                    Processes=@("ShareX");                             Instructions="Tasto destro sull'icona ShareX nella tray -> Stop screen recording.`nPer chiuderlo: tasto destro sulla tray -> Exit." }
    @{ Name="Icecream Screen Recorder"; Processes=@("Icecream Screen Recorder","IcecreamScreenRecorder"); Instructions="Clicca 'Stop' nel pannello flottante.`nPer chiuderlo: chiudi la finestra principale." }
    @{ Name="Loom";                      Processes=@("Loom");                                Instructions="Clicca 'Stop' sul widget flottante di Loom.`nPer chiuderlo: tasto destro sulla tray -> Quit." }
    @{ Name="Discord (chiamata)";        Processes=@("Discord");                            Instructions="Discord không registra file localmente, ma puo' condividere schermo in chiamata.`nVerifica manualmente se e' attiva una condivisione schermo/videocamera in una chiamata."; ManualOnly=$true }
    @{ Name="Zoom";                      Processes=@("Zoom");                                Instructions="Verifica manualmente se e' in corso una registrazione (icona rossa REC nella finestra della riunione)."; ManualOnly=$true }
    @{ Name="Microsoft Teams";           Processes=@("Teams","ms-teams");                   Instructions="Verifica manualmente se e' in corso una registrazione della riunione (icona REC in alto)."; ManualOnly=$true }
)

function Test-RecentRecordingFiles {
    param([int]$MinSizeMB = 1, [int]$WithinSeconds = 30)
    $folders = @("$env:USERPROFILE\Videos", "$env:USERPROFILE\Desktop", "$env:TEMP")
    foreach ($folder in $folders) {
        if (Test-Path $folder) {
            $files = Get-ChildItem -Path $folder -Include "*.mp4","*.avi","*.mkv","*.flv","*.tmp" -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Length -gt ($MinSizeMB * 1MB) -and $_.LastWriteTime -gt (Get-Date).AddSeconds(-$WithinSeconds) }
            if ($files) { return $true }
        }
    }
    return $false
}

# ========================================================================
# FUNZIONE REGISTRAZIONI ATTIVE
# ========================================================================

function Check-Recordings {
    Update-Status -Text "Controllo registrazioni..." -Color "Warning" -Force
    Show-Overlay -Title "Controllo Registrazioni" -Subtitle "Verifica programmi aperti..."

    $rilevati = New-Object System.Collections.Generic.List[psobject]

    try {
        foreach ($prog in $script:RecordingPrograms) {
            try {
                $proc = Get-Process -Name $prog.Processes -ErrorAction SilentlyContinue
                if ($proc) {
                    $isRecording = $false
                    if (-not $prog.ManualOnly) {
                        $isRecording = Test-RecentRecordingFiles
                    }
                    $rilevati.Add([PSCustomObject]@{
                        Name         = $prog.Name
                        IsRecording  = $isRecording
                        ManualOnly   = [bool]$prog.ManualOnly
                        Instructions = $prog.Instructions
                    })
                }
            } catch { }
        }
    } finally {
        Hide-Overlay
    }

    $inRegistrazione = @($rilevati | Where-Object { $_.IsRecording })

    $height = 460 + ([Math]::Max(0, $rilevati.Count - 1) * 26)
    if ($height -gt 750) { $height = 750 }
    $resultForm = New-StyledForm -Title "Controllo Registrazioni" -Width 780 -Height $height

    $headerPanel = New-UnifiedPanel -X 10 -Y 10 -Width 760 -Height 60 -Style "Surface"
    $resultForm.Controls.Add($headerPanel)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(15, 12)
    $lblTitle.Size = New-Object System.Drawing.Size(730, 38)
    $lblTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

    if ($inRegistrazione.Count -gt 0) {
        $lblTitle.Text = "🔴 ATTENZIONE: " + (($inRegistrazione | ForEach-Object { $_.Name }) -join ", ") + " STA/STANNO REGISTRANDO!"
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Error)
        $headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Error -Opacity 20))
    } elseif ($rilevati.Count -gt 0) {
        $lblTitle.Text = "⚠️ Programmi di registrazione APERTI: " + (($rilevati | ForEach-Object { $_.Name }) -join ", ")
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Warning)
        $headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Warning -Opacity 15))
    } else {
        $lblTitle.Text = "✅ Nessun programma di registrazione aperto"
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
        $headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Success -Opacity 10))
    }
    $headerPanel.Controls.Add($lblTitle)

    $lv = New-Object System.Windows.Forms.ListView
    $lv.Location = New-Object System.Drawing.Point(10, 80)
    $lv.Size = New-Object System.Drawing.Size(760, ($height - 250))
    $lv.View = "Details"
    $lv.FullRowSelect = $true
    $lv.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    $lv.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $lv.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $lv.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    Enable-DoubleBuffering -Control $lv
    [void]$lv.Columns.Add("Programma", 260)
    [void]$lv.Columns.Add("Stato", 250)
    [void]$lv.Columns.Add("Azione consigliata", 230)
    $resultForm.Controls.Add($lv)

    if ($rilevati.Count -gt 0) {
        foreach ($r in $rilevati) {
            $item = New-Object System.Windows.Forms.ListViewItem($r.Name)
            if ($r.IsRecording) {
                [void]$item.SubItems.Add("🔴 STA REGISTRANDO!")
                [void]$item.SubItems.Add("FERMA SUBITO!")
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Error -Opacity 30))
                $item.ForeColor = [System.Drawing.Color]::OrangeRed
                $item.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            } elseif ($r.ManualOnly) {
                [void]$item.SubItems.Add("❓ Aperto - verifica manuale")
                [void]$item.SubItems.Add("Controlla la chiamata")
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Accent -Opacity 15))
                $item.ForeColor = [System.Drawing.Color]::Orange
            } else {
                [void]$item.SubItems.Add("📌 Aperto")
                [void]$item.SubItems.Add("Chiudi se non serve")
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Warning -Opacity 15))
                $item.ForeColor = [System.Drawing.Color]::Yellow
            }
            [void]$lv.Items.Add($item)
        }
    } else {
        $item = New-Object System.Windows.Forms.ListViewItem("✅ Nessun programma trovato")
        [void]$item.SubItems.Add("OK")
        [void]$item.SubItems.Add("-")
        $item.ForeColor = [System.Drawing.Color]::LightGreen
        [void]$lv.Items.Add($item)
    }

    $bottomPanel = New-UnifiedPanel -X 10 -Y ($height - 155) -Width 760 -Height 110 -Style "Surface"
    $resultForm.Controls.Add($bottomPanel)

    $rtbIstruzioni = New-Object System.Windows.Forms.RichTextBox
    $rtbIstruzioni.Location = New-Object System.Drawing.Point(15, 15)
    $rtbIstruzioni.Size = New-Object System.Drawing.Size(730, 45)
    $rtbIstruzioni.ReadOnly = $true
    $rtbIstruzioni.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $rtbIstruzioni.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
    $rtbIstruzioni.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $rtbIstruzioni.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $rtbIstruzioni.Text = "COME VERIFICARE MANUALMENTE: apri Gestione Attivita (CTRL+SHIFT+ESC) -> Prestazioni -> GPU. Se vedi 'Encode Video' in uso, un programma sta registrando."
    $bottomPanel.Controls.Add($rtbIstruzioni)

    $btnDetails = New-UnifiedButton -Text "❓ Dettagli chiusura" -X 15 -Y 65 -Width 200 -Height 38 -Style "Accent" -OnClick {
        Show-CloseDetails -Rilevati $rilevati
    }
    $bottomPanel.Controls.Add($btnDetails)

    $btnTaskManager = New-UnifiedButton -Text "🔍 Gestione Attività" -X 225 -Y 65 -Width 200 -Height 38 -Style "Primary" -OnClick {
        Start-Process "taskmgr.exe"
    }
    $bottomPanel.Controls.Add($btnTaskManager)

    $btnRefresh = New-UnifiedButton -Text "🔄 Aggiorna" -X 435 -Y 65 -Width 150 -Height 38 -Style "Success" -OnClick {
        $resultForm.Close()
        Check-Recordings
    }
    $bottomPanel.Controls.Add($btnRefresh)

    $btnClose = New-UnifiedButton -Text "✖ Chiudi" -X 595 -Y 65 -Width 150 -Height 38 -Style "Danger" -OnClick {
        $resultForm.Close()
    }
    $bottomPanel.Controls.Add($btnClose)

    if ($inRegistrazione.Count -gt 0) {
        Update-Status -Text "🔴 In registrazione: $(($inRegistrazione | ForEach-Object { $_.Name }) -join ', ')" -Color "Error" -Force
    } elseif ($rilevati.Count -gt 0) {
        Update-Status -Text "Programmi aperti: $(($rilevati | ForEach-Object { $_.Name }) -join ', ')" -Color "Warning" -Force
    } else {
        Update-Status -Text "Nessun programma di registrazione aperto" -Color "Success" -Force
    }

    $resultForm.ShowDialog($mainForm) | Out-Null
}

function Show-CloseDetails {
    param($Rilevati)

    $height = 200 + ($Rilevati.Count * 70)
    if ($height -gt 700) { $height = 700 }
    $dettagliForm = New-StyledForm -Title "Come chiudere i programmi di registrazione" -Width 700 -Height $height

    $dPanel = New-UnifiedPanel -X 10 -Y 10 -Width 680 -Height ($height - 90) -Style "Surface" -Title "📖 Come chiudere i programmi rilevati"
    $dettagliForm.Controls.Add($dPanel)

    $rtbDetails = New-Object System.Windows.Forms.RichTextBox
    $rtbDetails.Location = New-Object System.Drawing.Point(15, 50)
    $rtbDetails.Size = New-Object System.Drawing.Size(650, ($height - 150))
    $rtbDetails.ReadOnly = $true
    $rtbDetails.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $rtbDetails.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
    $rtbDetails.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $rtbDetails.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $dPanel.Controls.Add($rtbDetails)

    $detailsText = ""
    if ($Rilevati.Count -eq 0) {
        $detailsText = "Nessun programma di registrazione rilevato al momento."
    } else {
        foreach ($r in $Rilevati) {
            $detailsText += "📌 $($r.Name)`n"
            $detailsText += "$($r.Instructions)`n"
            $detailsText += ("-" * 60) + "`n`n"
        }
    }
    $rtbDetails.Text = $detailsText

    $btnCloseDetails = New-UnifiedButton -Text "✖ Chiudi" -X 260 -Y ($height - 80) -Width 180 -Height 40 -Style "Danger" -OnClick { $dettagliForm.Close() }
    $dettagliForm.Controls.Add($btnCloseDetails)

    $dettagliForm.ShowDialog($mainForm) | Out-Null
}

# ========================================================================
# FUNZIONE GET USN JOURNAL STATUS
# ========================================================================

function Get-USNJournalStatus {
    $result = @{
        Status = "NON DISPONIBILE"; Details = ""; IsDeleted = $false
        JournalID = $null; JournalCreationTime = $null; MaxSize = $null
        AllocationDelta = $null; RecordCount = $null; FullInfo = $null
    }
    try {
        $usnInfo = & fsutil usn queryjournal C: 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($usnInfo)) {
            $result.Status = "DISATTIVO"
            $result.Details = "USN Journal disabilitato o eliminato"
            $result.IsDeleted = $true
            $result.FullInfo = $usnInfo
            return $result
        }
        $result.FullInfo = $usnInfo
        $idLine = $usnInfo | Select-String "ID journal" -ErrorAction SilentlyContinue
        if (-not $idLine) { $idLine = $usnInfo | Select-String "Journal ID" -ErrorAction SilentlyContinue }
        if ($idLine) {
            $id = $idLine.Line -replace '.*:\s+', ''
            $result.JournalID = $id.Trim()
            try {
                $idParts = $result.JournalID.Split('x')
                if ($idParts.Count -gt 1) {
                    $hexId = $idParts[-1]
                    if ($hexId -match '^[0-9A-Fa-f]+$') {
                        $longId = [Convert]::ToInt64($hexId, 16)
                        $creationTime = [datetime]::FromFileTime($longId)
                        $result.JournalCreationTime = $creationTime.ToString("dddd dd MMMM yyyy HH:mm:ss")
                        $result.JournalCreationTimestamp = $creationTime
                    }
                }
            } catch { $result.JournalCreationTime = "ID non convertibile in data" }
            $maxSizeLine = $usnInfo | Select-String "Maximum size" -ErrorAction SilentlyContinue
            if ($maxSizeLine) { $result.MaxSize = ($maxSizeLine.Line -replace '.*:\s*', '').Trim() }
            $allocationDeltaLine = $usnInfo | Select-String "Allocation delta" -ErrorAction SilentlyContinue
            if ($allocationDeltaLine) { $result.AllocationDelta = ($allocationDeltaLine.Line -replace '.*:\s*', '').Trim() }
            $recordCountLine = $usnInfo | Select-String "Record count" -ErrorAction SilentlyContinue
            if ($recordCountLine) { $result.RecordCount = ($recordCountLine.Line -replace '.*:\s*', '').Trim() }
            if ($result.MaxSize -and $result.AllocationDelta -and $result.RecordCount) {
                $result.Status = "ATTIVO"
                if ($result.JournalCreationTimestamp) {
                    $age = (Get-Date) - $result.JournalCreationTimestamp
                    $ageString = ""
                    if ($age.Days -gt 0) { $ageString += "$($age.Days) giorni, " }
                    $ageString += "$($age.Hours) ore, $($age.Minutes) minuti"
                    $result.Details = "Creato: $($result.JournalCreationTime)`n" +
                                     "Eta: $ageString`n" +
                                     "Dimensione: $($result.MaxSize)`n" +
                                     "Record: $($result.RecordCount)"
                } else {
                    $result.Details = "Dimensione: $($result.MaxSize)`n" + "Record: $($result.RecordCount)"
                }
                $result.IsDeleted = $false
            } else {
                $result.Status = "PARZIALE"
                $result.Details = "ID: $($result.JournalID)"
                $result.IsDeleted = $false
            }
        } else {
            $result.Status = "NON TROVATO"
            $result.Details = "USN Journal non trovato"
            $result.IsDeleted = $true
        }
    } catch {
        $result.Status = "ERRORE"
        $result.Details = "Errore: $($_.Exception.Message)"
        $result.IsDeleted = $true
    }
    return $result
}

# ========================================================================
# FUNZIONE 1 - CERCA .LOG.GZ
# ========================================================================

function Start-LogGzSearch {
    $scope = Select-ScanScope
    if ($null -eq $scope) { return }
    Update-Status -Text "Ricerca in corso..." -Color "Warning" -Force
    $found = New-Object System.Collections.Generic.List[string]
    $global:CancelScan = $false
    Show-Overlay -Title "Ricerca file .log.gz" -Subtitle "Scansione in corso..."
    try {
        if ($scope.Mode -eq "All") {
            $roots = [System.IO.DriveInfo]::GetDrives() |
                Where-Object { $_.DriveType -eq "Fixed" -and $_.IsReady } |
                ForEach-Object { $_.RootDirectory.FullName }
        } else {
            $roots = @($scope.Path)
        }
        foreach ($root in $roots) {
            if ($global:CancelScan) { break }
            Find-LogGzFiles -RootPath $root -FoundList $found
        }
    } finally {
        Hide-Overlay
    }
    if ($found.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nessun file .log.gz valido trovato.", "Ricerca completata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        Update-Status -Text "Nessun file trovato" -Color "Default" -Force
        return
    }
    Update-Status -Text "Trovati $($found.Count) file" -Color "Success" -Force
    Show-SearchWindow -Files $found
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

# ========================================================================
# FUNZIONE 2 - JOURNAL USN
# ========================================================================

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
            } else {
                [System.Windows.Forms.MessageBox]::Show("Impossibile determinare il percorso dello script.", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            }
        }
        return
    }
    
    Update-Status -Text "Lettura USN Journal..." -Color "Warning" -Force
    Show-Overlay -Title "Analisi USN Journal" -Subtitle "Lettura in corso..."
    
    try {
        $global:USNTempFile = [System.IO.Path]::GetTempFileName()
        $global:USNTempFile = [System.IO.Path]::ChangeExtension($global:USNTempFile, ".txt")
        
        $argList = "/c `"fsutil usn readjournal C: csv | findstr /i /C:`"0x80000200`" /C:`"0x00001000`" /C:`"0x00002000`" | findstr /i /C:`"latest.log`" /C:`".log.gz`" /C:`"launcher_profiles.json`" /C:`"usernamecache.json`" /C:`"usercache.json`" /C:`"shig.inima`" /C:`"launcher_accounts.json`" > `"$global:USNTempFile`"`""
        
        $p = Start-Process -FilePath "cmd.exe" -ArgumentList $argList -Wait -WindowStyle Hidden -PassThru
        
        Hide-Overlay
        
        if (Test-Path $global:USNTempFile) {
            $fileInfo = Get-Item $global:USNTempFile
            if ($fileInfo.Length -gt 0) {
                Update-Status -Text "USN Journal analizzato - File temporaneo creato" -Color "Success" -Force
                Start-Process -FilePath "notepad.exe" -ArgumentList $global:USNTempFile -WindowStyle Normal
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Analisi completata!`n`nIl file temporaneo e' stato creato e aperto con Notepad.`n`nI dati sono stati filtrati per:`n- Eventi di creazione/modifica file`n- Pattern relativi a Minecraft logs`n`nIl file verra eliminato automaticamente alla chiusura di questo programma.",
                    "Completato",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            } else {
                Update-Status -Text "Nessuna corrispondenza trovata" -Color "Default" -Force
                [System.Windows.Forms.MessageBox]::Show(
                    "Nessuna corrispondenza trovata nel journal USN.`n`nVerifica che il journal sia attivo o prova con un'altra unita' disco.",
                    "Nessun risultato",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                Remove-Item $global:USNTempFile -Force -ErrorAction SilentlyContinue
                $global:USNTempFile = $null
            }
        }
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Errore" -Color "Error" -Force
        [System.Windows.Forms.MessageBox]::Show("Errore durante la lettura del journal:`n$($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        if ($global:USNTempFile -and (Test-Path $global:USNTempFile)) {
            Remove-Item $global:USNTempFile -Force -ErrorAction SilentlyContinue
            $global:USNTempFile = $null
        }
    }
}

# ========================================================================
# ANALISI SISTEMA
# ========================================================================

function Check-SystemIntegrity {
    Update-Status -Text "Analisi sistema in corso..." -Color "Warning" -Force
    Show-Overlay -Title "Analisi Sistema" -Subtitle "Verifica integrita sistema..."
    
    $results = New-Object System.Collections.Generic.List[hashtable]
    $hasIssues = $false
    $criticalIssues = $false
    
    try {
        $usnStatus = Get-USNJournalStatus
        $results.Add(@{
            Category = "USN Journal"
            Status = $usnStatus.Status
            Dettagli = $usnStatus.Details
            IsIssue = $usnStatus.IsDeleted
            IsCritical = $usnStatus.IsDeleted
            RawData = $usnStatus
        })
        if ($usnStatus.IsDeleted) { 
            $hasIssues = $true
            $criticalIssues = $true 
        }
        
        $timeChangeIssues = $false
        $suspiciousChanges = New-Object System.Collections.Generic.List[string]
        $legitimateCount = 0
        $suspiciousCount = 0
        
        try {
            $bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
            $bootTimeStr = $bootTime.ToString("yyyy-MM-dd HH:mm:ss")
            
            $timeEvents = Get-WinEvent -LogName "System" -FilterXPath "*[System[EventID=1]]" -MaxEvents 200 -ErrorAction SilentlyContinue
            
            if ($timeEvents) {
                foreach ($evt in $timeEvents) {
                    $eventTime = $evt.TimeCreated
                    $eventTimeStr = $eventTime.ToString("yyyy-MM-dd HH:mm:ss")
                    $msg = $evt.Message
                    $eventId = $evt.Id
                    
                    if ($msg -notmatch "ora di sistema|system time|orario|time zone|fuso orario|time change|cambio orario") { continue }
                    if ($msg -match "filtro|filter|driver|scaricamento|loading") { continue }
                    if ([string]::IsNullOrWhiteSpace($msg)) { continue }
                    
                    $isLegitimate = $false
                    $reason = ""
                    
                    $timeDiff = ($eventTime - $bootTime).TotalMinutes
                    if ($timeDiff -ge 0 -and $timeDiff -le 5) {
                        $isLegitimate = $true
                        $reason = "Sincronizzazione orario all'avvio del sistema"
                    }
                    
                    if ($msg -match "time zone" -or $msg -match "fuso orario") {
                        $isLegitimate = $true
                        $reason = "Cambio fuso orario (legittimo)"
                    }
                    
                    if ($msg -match "Delta ora: (\d+) ms" -or $msg -match "Delta ora: (\d+) milliseconds") {
                        $ms = [int]$Matches[1]
                        if ($ms -le 1000) {
                            $isLegitimate = $true
                            $reason = "Sincronizzazione NTP minore ($ms ms)"
                        }
                    }
                    
                    if ($msg -match "NTP" -or $msg -match "time synchronization" -or $msg -match "sincronizzazione") {
                        $isLegitimate = $true
                        $reason = "Sincronizzazione NTP"
                    }
                    
                    if ($msg -match "svchost.exe" -or $msg -match "services.exe" -or $msg -match "lsass.exe") {
                        if (-not $isLegitimate) {
                            $isLegitimate = $true
                            $reason = "Modifica orario da servizio di sistema"
                        }
                    }
                    
                    if ($msg -match "Delta ora: (\d+) ms" -or $msg -match "Delta ora: (\d+) milliseconds") {
                        $ms = [int]$Matches[1]
                        if ($ms -le 30000) {
                            $isLegitimate = $true
                            $reason = "Modifica NTP minore ($ms ms)"
                        }
                    }
                    
                    if (-not $isLegitimate) {
                        if ($msg -match "Delta ora: (\d+) ms") {
                            $ms = [int]$Matches[1]
                            if ($ms -gt 30000) {
                                $isLegitimate = $false
                                $reason = "Modifica manuale di $([math]::Round($ms/1000)) secondi"
                            } else {
                                $isLegitimate = $true
                                $reason = "Modifica NTP minore ($ms ms)"
                            }
                        } elseif ($msg -match "(\d+) minuti" -or $msg -match "(\d+) minutes") {
                            $minutes = [int]$Matches[1]
                            if ($minutes -gt 5) {
                                $isLegitimate = $false
                                $reason = "Modifica manuale di $minutes minuti"
                            } else {
                                $isLegitimate = $true
                                $reason = "Modifica minore ($minutes minuti) - probabilmente NTP"
                            }
                        } else {
                            $isLegitimate = $true
                            $reason = "Modifica orario non specificata - considerata legittima"
                        }
                    }
                    
                    if (-not $isLegitimate) {
                        $eventInfo = "Evento ID $eventId del $eventTimeStr - $msg"
                        $suspiciousChanges.Add("$eventInfo`n    (SOSPETTO: $reason)")
                        $suspiciousCount++
                        $timeChangeIssues = $true
                        $hasIssues = $true
                    } else {
                        $legitimateCount++
                    }
                }
            }
            
            $timeSummary = New-Object System.Collections.Generic.List[string]
            if ($suspiciousCount -gt 0) {
                $timeSummary.Add("🔴 MODIFICHE ORARIO SOSPETTE RILEVATE ($suspiciousCount):")
                foreach ($sc in $suspiciousChanges) { $timeSummary.Add($sc) }
                $timeSummary.Add("")
            } else {
                $timeSummary.Add("✅ NESSUNA MODIFICA ORARIO SOSPETTA RILEVATA")
                $timeSummary.Add("")
            }
            
            $timeSummary.Add("ℹ️ MODIFICHE ORARIO LEGITTIME IGNORATE: $legitimateCount (sincronizzazioni NTP, avvii/spegnimenti sistema)")
            
            $timeStatus = if ($timeChangeIssues) { "MODIFICHE SOSPETTE RILEVATE" } else { "NESSUN ANOMALIA" }
            $timeSummaryText = ($timeSummary.ToArray()) -join "`n"
            
            $currentTime = Get-Date
            $uptimeSpan = $currentTime - $bootTime
            $timeSummaryText += "`n`n📊 UPTIME SISTEMA: $($uptimeSpan.Days) giorni, $($uptimeSpan.Hours) ore, $($uptimeSpan.Minutes) minuti"
            $timeSummaryText += "`n🕐 Ultimo avvio: $bootTimeStr"
            
        } catch {
            $timeSummaryText = "Impossibile verificare le modifiche di orario: $($_.Exception.Message)"
            $timeChangeIssues = $false
        }
        
        $results.Add(@{
            Category = "Time Changes"
            Status = $timeStatus
            Dettagli = $timeSummaryText
            IsIssue = $timeChangeIssues
            IsCritical = $false
        })
        
        try {
            $bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
            $bootTimeStr = $bootTime.ToString("dddd dd MMMM yyyy HH:mm:ss")
            $uptime = (Get-Date) - $bootTime
            $daysSinceBoot = $uptime.Days
            $hoursSinceBoot = $uptime.Hours
            $minutesSinceBoot = $uptime.Minutes
            
            if ($daysSinceBoot -lt 1) {
                $bootStatus = "RIAVVIO RECENTE (< 24h)"
                $isBootIssue = $true
                $hasIssues = $true
            } else {
                $bootStatus = "AVVIATO DA $daysSinceBoot giorni"
                $isBootIssue = $false
            }
            $results.Add(@{
                Category = "System Boot"
                Status = $bootStatus
                Dettagli = "Ultimo avvio: $bootTimeStr`nTempo: $daysSinceBoot giorni, $hoursSinceBoot ore, $minutesSinceBoot minuti"
                IsIssue = $isBootIssue
                IsCritical = $false
            })
        } catch {
            $results.Add(@{
                Category = "System Boot"
                Status = "NON DISPONIBILE"
                Dettagli = "Impossibile determinare l'ultimo avvio"
                IsIssue = $false
                IsCritical = $false
            })
        }        
        
        if ($usnStatus.JournalID) {
            $results.Add(@{
                Category = "Dettagli USN"
                Status = "ID: $($usnStatus.JournalID)"
                Dettagli = "Creato: $($usnStatus.JournalCreationTime)`n" +
                         "Record: $($usnStatus.RecordCount)`n" +
                         "Dimensione: $($usnStatus.MaxSize)"
                IsIssue = $false
                IsCritical = $false
            })
        }
        
        if ($usnStatus.IsDeleted) {
            $results.Add(@{
                Category = "ATTENZIONE: USN ELIMINATO"
                Status = "ELIMINATO"
                Dettagli = "USN Journal eliminato o disabilitato.`n" +
                         "Data: $(Get-Date -Format 'dddd dd MMMM yyyy HH:mm:ss')`n" +
                         "Verificare se il sistema e' stato riavviato o se sono stati eseguiti tool di pulizia."
                IsIssue = $true
                IsCritical = $true
            })
            $criticalIssues = $true
            $hasIssues = $true
        }
        
        if ($usnStatus.MaxSize) {
            $sizeBytes = [long]$usnStatus.MaxSize
            $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
            if ($sizeMB -lt 100) {
                $results.Add(@{
                    Category = "Dimensione USN"
                    Status = "RIDOTTA"
                    Dettagli = "Dimensione: $sizeMB MB - Puo' limitare la tracciabilita'"
                    IsIssue = $true
                    IsCritical = $false
                })
                $hasIssues = $true
            } else {
                $results.Add(@{
                    Category = "Dimensione USN"
                    Status = "ADEGUATA"
                    Dettagli = "Dimensione: $sizeMB MB - Spazio sufficiente"
                    IsIssue = $false
                    IsCritical = $false
                })
            }
        }
        
    } catch {
        $hasIssues = $true
        $criticalIssues = $true
        $results.Add(@{
            Category = "ERRORE"
            Status = "ERRORE"
            Dettagli = $_.Exception.Message
            IsIssue = $true
            IsCritical = $true
        })
    } finally {
        Hide-Overlay
        Update-Status -Text "Analisi completata" -Color "Success" -Force
    }
    
    Show-SystemAnalysisResults -Results $results -HasIssues $hasIssues -CriticalIssues $criticalIssues
}

# ========================================================================
# SHOW SYSTEM ANALYSIS RESULTS
# ========================================================================

function Show-SystemAnalysisResults {
    param($Results, [bool]$HasIssues, [bool]$CriticalIssues)
    
    $resultForm = New-StyledForm -Title "Analisi Sistema - Report Dettagliato" -Width 1000 -Height 440
    
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Size = New-Object System.Drawing.Size(980, 60)
    $headerPanel.Location = New-Object System.Drawing.Point(10, 10)
    $headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    Set-RoundedCorners -Control $headerPanel -Radius 10
    $resultForm.Controls.Add($headerPanel)
    
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(15, 10)
    $lblTitle.Size = New-Object System.Drawing.Size(950, 40)
    $lblTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    if ($CriticalIssues) {
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Error)
        $lblTitle.Text = "🔴🔴🔴 ATTENZIONE CRITICA: Anomalie gravi rilevate!"
        $headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Error -Opacity 20))
    } elseif ($HasIssues) {
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Warning)
        $lblTitle.Text = "⚠️ ATTENZIONE: Anomalie rilevate - Si consiglia approfondimento"
        $headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Warning -Opacity 15))
    } else {
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
        $lblTitle.Text = "✅ Sistema integro - Nessuna anomalia rilevata"
        $headerPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Success -Opacity 10))
    }
    $headerPanel.Controls.Add($lblTitle)
    
    $lv = New-Object System.Windows.Forms.ListView
    $lv.Location = New-Object System.Drawing.Point(10, 80)
    $lv.Size = New-Object System.Drawing.Size(980, 220)
    $lv.View = "Details"
    $lv.FullRowSelect = $true
    $lv.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    $lv.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $lv.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $lv.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    Enable-DoubleBuffering -Control $lv
    [void]$lv.Columns.Add("Controllo", 250)
    [void]$lv.Columns.Add("Stato", 160)
    [void]$lv.Columns.Add("Dettagli / Spiegazione (Fai doppio clic per leggere tutto)", 540)
    $resultForm.Controls.Add($lv)
    
    $lv.BeginUpdate()
    foreach ($r in $Results) {
        try {
            $category = if ($r.Category) { $r.Category } elseif ($r.Categoria) { $r.Categoria } else { "Controllo Sistema" }
            $status = if ($r.Status) { $r.Status } elseif ($r.Stato) { $r.Stato } else { "N/D" }
            $details = if ($r.Dettagli) { $r.Dettagli } elseif ($r.Details) { $r.Details } else { "" }
            
            $clearName = Get-ClearName -Category $category
            $clearDetails = Get-ClearDetails -Category $category -Details $details
            
            $item = New-Object System.Windows.Forms.ListViewItem($clearName)
            [void]$item.SubItems.Add($status)
            
            $displayText = $clearDetails -replace "[\r\n]+", " | "
            if ($displayText.Length -gt 150) {
                $displayText = $displayText.Substring(0, 150) + "..."
            }
            [void]$item.SubItems.Add($displayText)
            
            $item.Tag = $clearDetails
            
            if ($r.IsCritical) {
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Error -Opacity 30))
                $item.ForeColor = [System.Drawing.Color]::White
                $item.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            } elseif ($r.IsIssue) {
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Warning -Opacity 20))
                $item.ForeColor = [System.Drawing.Color]::Yellow
                $item.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            } elseif ($status -match "NESSUN ANOMALIA|ATTIVO|ADEGUATA") {
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml((Get-ColorWithOpacity -HexColor $Theme.Success -Opacity 10))
                $item.ForeColor = [System.Drawing.Color]::LightGreen
            }
            [void]$lv.Items.Add($item)
        } catch { 
            try {
                $item = New-Object System.Windows.Forms.ListViewItem([string]$r.Categoria)
                [void]$item.SubItems.Add([string]$r.Stato)
                [void]$item.SubItems.Add([string]$r.Dettagli)
                $item.Tag = [string]$r.Dettagli
                [void]$lv.Items.Add($item)
            } catch { }
        }
    }
    $lv.EndUpdate()
    
    $lv.Add_DoubleClick({
        if ($lv.SelectedItems.Count -gt 0) {
            $selectedItem = $lv.SelectedItems[0]
            $fullText = $selectedItem.Tag
            $titleName = $selectedItem.Text
            [System.Windows.Forms.MessageBox]::Show($fullText, "Dettagli completi: $titleName", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
    })
    
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Size = New-Object System.Drawing.Size(980, 110)
    $bottomPanel.Location = New-Object System.Drawing.Point(10, 310)
    $bottomPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    Set-RoundedCorners -Control $bottomPanel -Radius 10
    $resultForm.Controls.Add($bottomPanel)
    
    $lblSummary = New-Object System.Windows.Forms.Label
    $lblSummary.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $lblSummary.Location = New-Object System.Drawing.Point(15, 10)
    $lblSummary.Size = New-Object System.Drawing.Size(350, 90)
    $lblSummary.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    if ($CriticalIssues) {
        $lblSummary.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Error)
        $lblSummary.Text = "🔴🔴🔴 ANOMALIE CRITICHE RILEVATE!`n• Problemi gravi di sicurezza rilevati`n• Verifica immediata necessaria"
    } elseif ($HasIssues) {
        $lblSummary.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Warning)
        $lblSummary.Text = "⚠️ ANOMALIE RILEVATE`n• Sono state rilevate alcune anomalie`n• Si consiglia di approfondire l'analisi"
    } else {
        $lblSummary.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
        $lblSummary.Text = "✅ SISTEMA INTEGRO`n• Nessuna anomalia rilevata`n• Il sistema risulta sicuro"
    }
    $bottomPanel.Controls.Add($lblSummary)
    
    $btnShowReport = New-UnifiedButton -Text "📋 Report" -X 380 -Y 15 -Width 130 -Height 35 -Style "Accent" -OnClick {
        $sbReport = New-Object System.Text.StringBuilder
        [void]$sbReport.AppendLine("REPORT ANALISI SISTEMA")
        [void]$sbReport.AppendLine(("=" * 50))
        [void]$sbReport.AppendLine()
        
        foreach ($r in $Results) {
            $cat = if ($r.Category) { $r.Category } elseif ($r.Categoria) { $r.Categoria } else { "N/D" }
            $st = if ($r.Status) { $r.Status } elseif ($r.Stato) { $r.Stato } else { "N/D" }
            $det = if ($r.Dettagli) { $r.Dettagli } elseif ($r.Details) { $r.Details } else { "" }
            
            [void]$sbReport.AppendLine("📌 $cat")
            [void]$sbReport.AppendLine("   Stato: $st")
            [void]$sbReport.AppendLine("   Dettagli: $det")
            [void]$sbReport.AppendLine()
        }
        [System.Windows.Forms.MessageBox]::Show($sbReport.ToString(), "Report Analisi Sistema", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    }
    $bottomPanel.Controls.Add($btnShowReport)
    
    $btnExport = New-UnifiedButton -Text "💾 Esporta" -X 525 -Y 15 -Width 130 -Height 35 -Style "Primary" -OnClick {
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "File di testo|*.txt"
        $saveDialog.Title = "Esporta report"
        $saveDialog.FileName = "system_analysis_report.txt"
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                $sbReport = New-Object System.Text.StringBuilder
                [void]$sbReport.AppendLine("REPORT ANALISI SISTEMA")
                [void]$sbReport.AppendLine(("=" * 50))
                [void]$sbReport.AppendLine()
                
                foreach ($r in $Results) {
                    $cat = if ($r.Category) { $r.Category } elseif ($r.Categoria) { $r.Categoria } else { "N/D" }
                    $st = if ($r.Status) { $r.Status } elseif ($r.Stato) { $r.Stato } else { "N/D" }
                    $det = if ($r.Dettagli) { $r.Dettagli } elseif ($r.Details) { $r.Details } else { "" }
                    
                    [void]$sbReport.AppendLine("📌 $cat")
                    [void]$sbReport.AppendLine("   Stato: $st")
                    [void]$sbReport.AppendLine("   Dettagli: $det")
                    [void]$sbReport.AppendLine()
                }
                [System.IO.File]::WriteAllText($saveDialog.FileName, $sbReport.ToString(), [System.Text.Encoding]::UTF8)
                [System.Windows.Forms.MessageBox]::Show("Report esportato con successo!", "Completato", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Errore: $($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            }
        }
    }
    $bottomPanel.Controls.Add($btnExport)
    
    $btnClose = New-UnifiedButton -Text "✖ Chiudi" -X 670 -Y 15 -Width 130 -Height 35 -Style "Danger" -OnClick { $resultForm.Close() }
    $bottomPanel.Controls.Add($btnClose)
    
    $lblLegend = New-Object System.Windows.Forms.Label
    $lblLegend.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $lblLegend.Location = New-Object System.Drawing.Point(380, 60)
    $lblLegend.Size = New-Object System.Drawing.Size(580, 40)
    $lblLegend.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $lblLegend.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.TextSecondary)
    $lblLegend.Text = "📌 LEGENDA: 🔴 CRITICO | ⚠️ ANOMALIA | ✅ OK | (Fai doppio clic su una riga per espandere il testo)"
    $bottomPanel.Controls.Add($lblLegend)
    
    $resultForm.ShowDialog($mainForm) | Out-Null
}

# ========================================================================
# FUNZIONI AUSILIARIE PER ANALISI SISTEMA
# ========================================================================

function Get-ClearName {
    param($Category)
    $clearNames = @{
        "USN Journal" = "📜 Journal USN - Tracciamento modifiche file"
        "Time Changes" = "⏰ Modifiche Orario Sistema"
        "System Boot" = "🔄 Avvio/Riavvio Sistema"
        "Dettagli USN" = "📋 Configurazione Journal USN"
        "ATTENZIONE: USN ELIMINATO" = "🔴🔴🔴 JOURNAL USN ELIMINATO - ALLARME!"
        "Dimensione USN" = "📏 Dimensione Journal USN"
        "ERRORE" = "❌ ERRORE"
    }
    if ($clearNames.ContainsKey($Category)) { return $clearNames[$Category] }
    return $Category
}

function Get-ClearDetails {
    param($Category, $Details)
    
    if ($Category -eq "Dettagli USN" -or ($Details -match "Creato:" -and $Details -match "Record:")) {
        return "📋 CONFIGURAZIONE DEL JOURNAL USN`n`n" +
               "Questi sono i dettagli tecnici del journal USN (Update Sequence Number):`n`n" +
               "📌 COSA SONO QUESTI DATI:`n" +
               "  • CREATO: Data e ora in cui il journal è stato attivato sul sistema`n" +
               "  • RECORD: Numero di modifiche ai file registrate finora`n" +
               "  • DIMENSIONE: Spazio allocato per memorizzare il journal`n`n" +
               "🔍 PERCHE' SONO IMPORTANTI:`n" +
               "  • Più record ci sono, più storico di modifiche è disponibile`n" +
               "  • La dimensione determina quanto storico può essere conservato`n" +
               "  • Una dimensione troppo piccola può causare perdita di dati`n`n" +
               "📊 DATI ATUALI:`n$Details"
    }
    
    if ($Category -eq "System Boot" -or ($Details -match "Ultimo avvio" -and $Details -match "Tempo:")) {
        return "🔄 STATO AVVIO DEL SISTEMA`n`n" +
               "Questi dati mostrano quando il sistema è stato avviato l'ultima volta:`n`n" +
               "📌 COSA SIGNIFICANO:`n" +
               "  • ULTIMO AVVIO: Data e ora dell'ultimo riavvio del sistema`n" +
               "  • TEMPO: Quanto tempo è passato dall'ultimo avvio (uptime)`n`n" +
               "🔍 PERCHE' E' IMPORTANTE:`n" +
               "  • Un riavvio recente (< 24 ore) potrebbe essere normale o sospetto`n" +
               "  • L'uptime indica la stabilità del sistema`n" +
               "  • Riavvii frequenti potrebbero indicare problemi`n`n" +
               "📊 DATI ATUALI:`n$Details"
    }
    
    if ($Category -eq "Time Changes" -or $Details -match "orario") {
        return "⏰ CONTROLLO MODIFICHE ORARIO`n`n" +
               "Questo controllo verifica se l'orario di sistema è stato modificato in modo sospetto:`n`n" +
               "📌 COSA CONTROLLA:`n" +
               "  • Eventi di cambio orario manuale`n" +
               "  • Modifiche orario sospette (oltre 30 secondi)`n" +
               "  • Manipolazioni temporali per eludere i log`n`n" +
               "✅ LE MODIFICHE LEGITTIME VENGONO IGNORATE:`n" +
               "  • Sincronizzazione NTP (meno di 1 secondo)`n" +
               "  • Cambio fuso orario`n" +
               "  • Sincronizzazione all'avvio del sistema`n`n" +
               "📊 RISULTATO:`n$Details"
    }
    
    if ($Category -eq "USN Journal") {
        return "📜 STATO DEL JOURNAL USN`n`n" +
               "Il journal USN (Update Sequence Number) è un sistema di logging di Windows:`n`n" +
               "📌 COSA FA:`n" +
               "  • Traccia TUTTE le modifiche ai file sul disco`n" +
               "  • Registra creazione, modifica e cancellazione di file`n" +
               "  • È fondamentale per l'analisi forense`n`n" +
               "✅ SE E' ATTIVO: Il sistema è sicuro e tracciabile`n" +
               "🔴 SE E' DISATTIVO: Nessuna modifica viene tracciata - ALLARME!`n`n" +
               "📊 STATO ATTUALE:`n$Details"
    }
    
    if ($Category -eq "Dimensione USN") {
        return "📏 DIMENSIONE DEL JOURNAL USN`n`n" +
               "Questo controllo verifica se il journal USN ha spazio sufficiente:`n`n" +
               "📌 COSA CONTROLLA:`n" +
               "  • Spazio allocato per il journal (dovrebbe essere > 100 MB)`n" +
               "  • Se la dimensione è ridotta, lo storico delle modifiche è limitato`n`n" +
               "⚠️ DIMENSIONE RIDOTTA: Può causare perdita di dati storici`n" +
               "✅ DIMENSIONE ADEGUATA: Il journal può conservare abbastanza storico`n`n" +
               "📊 DATI ATUALI:`n$Details"
    }
    
    if ($Category -eq "ATTENZIONE: USN ELIMINATO") {
        return "🔴🔴🔴 ALLARME CRITICO - JOURNAL USN ELIMINATO! 🔴🔴🔴`n`n" +
               "🚨 IL JOURNAL USN E' STATO ELIMINATO O DISABILITATO!`n`n" +
               "🔍 COSA PUO' SIGNIFICARE:`n" +
               "  • Qualcuno ha cancellato INTENZIONALMENTE il journal per NASCONDERE attività`n" +
               "  • Il sistema è stato COMPROMESSO e ripulito`n" +
               "  • E' stato eseguito un tool di PULIZIA che ha rimosso il journal`n" +
               "  • Il journal è stato disabilitato per RIDURRE il carico del sistema`n`n" +
               "🔧 COSA FARE IMMEDIATAMENTE:`n" +
               "  1️⃣ VERIFICARE chi ha accesso amministrativo al sistema`n" +
               "  2️⃣ CONTROLLARE i log di sicurezza per accessi sospetti`n" +
               "  3️⃣ ESEGUIRE una scansione ANTIVIRUS completa`n" +
               "  4️⃣ RIATTIVARE il journal con il comando (come Amministratore):`n" +
               "     fsutil usn createjournal C: 1048576 8192`n`n" +
               "⚠️⚠️⚠️ QUESTA E' UNA SITUAZIONE DI GRAVE ALLARME! ⚠️⚠️⚠️"
    }
    
    return "📋 DETTAGLI:`n$Details"
}

# ========================================================================
# FUNZIONE 3 - AUTO ANALYZE
# ========================================================================

function Start-AutoAnalyze {
    $scope = Select-ScanScope
    if ($null -eq $scope) { return }
    Update-Status -Text "Ricerca file .log.gz..." -Color "Warning" -Force
    
    $found = New-Object System.Collections.Generic.List[string]
    $global:CancelScan = $false
    Show-Overlay -Title "Ricerca file .log.gz" -Subtitle "Scansione in corso..."
    try {
        if ($scope.Mode -eq "All") {
            $roots = [System.IO.DriveInfo]::GetDrives() |
                Where-Object { $_.DriveType -eq "Fixed" -and $_.IsReady } |
                ForEach-Object { $_.RootDirectory.FullName }
        } else {
            $roots = @($scope.Path)
        }
        foreach ($root in $roots) {
            if ($global:CancelScan) { break }
            Find-LogGzFiles -RootPath $root -FoundList $found
        }
    } finally {
        Hide-Overlay
    }
    if ($found.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nessun file .log.gz valido trovato.", "Ricerca completata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        Update-Status -Text "Nessun file trovato" -Color "Default" -Force
        return
    }
    Update-Status -Text "Analisi $($found.Count) file..." -Color "Warning" -Force
    Show-Overlay -Title "Analisi Automatica" -Subtitle "Estrazione dati in corso..."
    
    $results = New-Object System.Collections.Generic.List[hashtable]
    $global:CancelScan = $false
    
    $rxUser = [regex]::new("Setting user: (.+)", [System.Text.RegularExpressions.RegexOptions]::Compiled)
    $rxLogin = [regex]::new("Received login request: LoginData\{name='([^']+)'", [System.Text.RegularExpressions.RegexOptions]::Compiled)
    $rxServerPort = [regex]::new("Connecting to ([^,]+),\s*(\d+)", [System.Text.RegularExpressions.RegexOptions]::Compiled)
    $rxServerDomain = [regex]::new("Connecting to ([^\s,]+)", [System.Text.RegularExpressions.RegexOptions]::Compiled)
    $rxServerIP = [regex]::new("Connecting to ([\d\.]+)", [System.Text.RegularExpressions.RegexOptions]::Compiled)
    
    try {
        foreach ($filePath in $found) {
            if ($global:CancelScan) { break }
            try {
                $fs = [System.IO.File]::OpenRead($filePath)
                $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress)
                $sr = New-Object System.IO.StreamReader($gz)
                
                $nickname = $null
                $server = $null
                $port = $null
                $loginStatus = "Sconosciuto"
                $foundNicknames = @{}
                $foundServers = @{}
                $foundLoginStatus = @{}
                $nicknameChanges = New-Object System.Collections.Generic.List[string]
                $allNicknamesInOrder = New-Object System.Collections.Generic.List[string]
                $hasUnknownServer = $false
                $hasUnknownLogin = $false
                
                while (-not $sr.EndOfStream) {
                    $line = $sr.ReadLine()
                    
                    if ($line.Contains("Connecting to Authenticator") -or 
                        $line.Contains("simplevoice") -or $line.Contains("Simple Voice") -or $line.Contains("voice chat") -or 
                        $line.Contains("authenticator") -or $line.Contains("Authenticator") -or 
                        $line.Contains("Failed to establish connection")) { continue }
                    
                    $mUser = $rxUser.Match($line)
                    if ($mUser.Success) {
                        $nick = $mUser.Groups[1].Value.Trim()
                        if (-not $foundNicknames.ContainsKey($nick)) {
                            $foundNicknames[$nick] = $true
                            $allNicknamesInOrder.Add($nick)
                            if ($null -eq $nickname) { $nickname = $nick }
                        }
                        continue
                    }
                    
                    $mLogin = $rxLogin.Match($line)
                    if ($mLogin.Success) {
                        $nick = $mLogin.Groups[1].Value.Trim()
                        if (-not $foundNicknames.ContainsKey($nick)) {
                            $foundNicknames[$nick] = $true
                            $allNicknamesInOrder.Add($nick)
                            $nicknameChanges.Add($nick)
                            if ($null -eq $nickname) { $nickname = $nick }
                        }
                        continue
                    }
                    
                    $mServerPort = $rxServerPort.Match($line)
                    if ($mServerPort.Success) {
                        $serv = $mServerPort.Groups[1].Value.Trim()
                        $prt = $mServerPort.Groups[2].Value.Trim()
                        if (-not $foundServers.ContainsKey($serv)) {
                            $foundServers[$serv] = $true
                            if ($null -eq $server) { $server = $serv; $port = $prt }
                        }
                        continue
                    }
                    
                    $mServerDomain = $rxServerDomain.Match($line)
                    if ($mServerDomain.Success) {
                        $serv = $mServerDomain.Groups[1].Value.Trim()
                        if (-not $foundServers.ContainsKey($serv)) {
                            $foundServers[$serv] = $true
                            if ($null -eq $server) { $server = $serv }
                        }
                        continue
                    }
                    
                    $mServerIP = $rxServerIP.Match($line)
                    if ($mServerIP.Success) {
                        $serv = $mServerIP.Groups[1].Value.Trim()
                        if (-not $foundServers.ContainsKey($serv)) {
                            $foundServers[$serv] = $true
                            if ($null -eq $server) { $server = $serv }
                        }
                        continue
                    }
                    
                    if ($line.Contains("Login eseguito") -or $line.Contains("Logged in")) {
                        $foundLoginStatus["Loggato"] = $true
                        $loginStatus = "Loggato"
                        continue
                    }
                    if ($line.Contains("Password errata") -or $line.Contains("Wrong password") -or $line.Contains("Invalid password") -or $line.Contains("Login failed")) {
                        $foundLoginStatus["Non Loggato"] = $true
                        $loginStatus = "Non Loggato"
                        continue
                    }
                }
                $sr.Close(); $gz.Close(); $fs.Close()
                
                if ($server) {
                    if ($server.Contains("localhost") -or $server.Contains("127.0.0.1") -or $server.Contains("0.0.0.0")) {
                        $hasUnknownServer = $true
                    }
                } else {
                    $hasUnknownServer = $true
                }
                
                if ($foundServers.Count -gt 1) {
                    $hasUnknownServer = $true
                }
                if ($loginStatus -eq "Sconosciuto") { $hasUnknownLogin = $true }
                
                $hasNicknameChange = ($nicknameChanges.Count -gt 0) -or ($foundNicknames.Count -gt 1)
                $nicknameChangeMessage = ""
                
                if ($hasNicknameChange) {
                    if ($foundNicknames.Count -gt 1) {
                        $nicknameChangeMessage = "ATTENZIONE: Rilevati PIU' NICKNAME ($($foundNicknames.Count)) nello stesso log!`n"
                    } else {
                        $nicknameChangeMessage = "ATTENZIONE: Rilevati cambi di nickname!`n"
                    }
                    $nicknameChangeMessage += "Nickname in ordine cronologico:`n"
                    foreach ($n in $allNicknamesInOrder) { $nicknameChangeMessage += "  - $n`n" }
                    $nicknameChangeMessage += "`nVerifica manualmente il log."
                }
                
                $unknownServerMessage = ""
                if ($hasUnknownServer) {
                    if ($foundServers.Count -gt 1) {
                        $unknownServerMessage = "ATTENZIONE: Rilevati PIU' SERVER ($($foundServers.Count)) nello stesso log!`n"
                        foreach ($s in $foundServers.Keys) { $unknownServerMessage += "  - $s`n" }
                    } elseif ($server) {
                        $unknownServerMessage = "ATTENZIONE: Server non riconoscibile ($server)`n"
                    } else {
                        $unknownServerMessage = "ATTENZIONE: Nessun server identificato`n"
                    }
                    $unknownServerMessage += "Verifica manualmente il log.`n`n"
                }
                
                $unknownLoginMessage = ""
                if ($hasUnknownLogin) {
                    $unknownLoginMessage = "ATTENZIONE: Stato login non determinato`n"
                    $unknownLoginMessage += "Verifica manualmente il log.`n`n"
                }
                
                if ($nickname -or $server -or $loginStatus -ne "Sconosciuto") {
                    $results.Add(@{
                        File = $filePath; Nickname = $nickname; Server = $server; Port = $port
                        LoginStatus = $loginStatus; AllNicknames = $foundNicknames.Keys; AllServers = $foundServers.Keys
                        AllLoginStatus = $foundLoginStatus.Keys; HasNicknameChange = $hasNicknameChange
                        NicknameChangeMessage = $nicknameChangeMessage; AllNicknamesInOrder = $allNicknamesInOrder
                        HasUnknownServer = $hasUnknownServer; UnknownServerMessage = $unknownServerMessage
                        HasUnknownLogin = $hasUnknownLogin; UnknownLoginMessage = $unknownLoginMessage
                    })
                }
            } catch { }
        }
    } finally {
        Hide-Overlay
    }
    
    if ($results.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nessun nickname, server o login trovato.", "Analisi completata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        Update-Status -Text "Nessun dato trovato" -Color "Default" -Force
        return
    }
    Update-Status -Text "Analizzati $($results.Count) file" -Color "Success" -Force
    Show-AnalysisResults -Results $results
}

# ========================================================================
# INSTALLAZIONE WINRAR
# ========================================================================

function Install-WinRAR {
    try {
        Update-Status -Text "Download WinRAR..." -Color "Warning" -Force
        Show-Overlay -Title "Installazione WinRAR" -Subtitle "Download in corso..."
        $installerUrl = "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-701it.exe"
        $tempPath = Join-Path $env:TEMP "winrar_installer.exe"
        $client = New-Object System.Net.Http.HttpClient
        $client.Timeout = [System.TimeSpan]::FromSeconds(60)
        $response = $client.GetAsync($installerUrl).GetAwaiter().GetResult()
        if ($response.IsSuccessStatusCode) {
            $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            [System.IO.File]::WriteAllBytes($tempPath, $bytes)
            Hide-Overlay
            Update-Status -Text "Installazione in corso..." -Color "Info" -Force
            Start-Process -FilePath $tempPath -Wait
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force -ErrorAction SilentlyContinue }
            Update-Status -Text "WinRAR installato" -Color "Success" -Force
            [System.Windows.Forms.MessageBox]::Show("WinRAR installato con successo!", "Completato", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        } else {
            Hide-Overlay
            Update-Status -Text "Download fallito" -Color "Error" -Force
            [System.Windows.Forms.MessageBox]::Show("Impossibile scaricare WinRAR.", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    } catch {
        Hide-Overlay
        Update-Status -Text "Errore" -Color "Error" -Force
        [System.Windows.Forms.MessageBox]::Show("Errore: $($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}

# ========================================================================
# SHOW ANALYSIS RESULTS
# ========================================================================

function Show-AnalysisResults {
    param([System.Collections.Generic.List[hashtable]]$Results)
    
    $resultForm = New-StyledForm -Title "Analisi Automatica - Risultati" -Width 1180 -Height 670
    
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Size = New-Object System.Drawing.Size(1160, 55)
    $topPanel.Location = New-Object System.Drawing.Point(10, 10)
    $topPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    Set-RoundedCorners -Control $topPanel -Radius 10
    $resultForm.Controls.Add($topPanel)
    
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Cerca:"
    $lblSearch.Location = New-Object System.Drawing.Point(15, 15)
    $lblSearch.Size = New-Object System.Drawing.Size(60, 25)
    $lblSearch.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $topPanel.Controls.Add($lblSearch)
    
    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(75, 12)
    $txtSearch.Size = New-Object System.Drawing.Size(250, 28)
    $txtSearch.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
    $txtSearch.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $txtSearch.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $topPanel.Controls.Add($txtSearch)
    
    $btnSystemCheck = New-UnifiedButton -Text "🛡 Analisi Sistema" -X 340 -Y 8 -Width 150 -Height 38 -Style "Warning" -OnClick { Check-SystemIntegrity }
    $topPanel.Controls.Add($btnSystemCheck)
    
    $lblCount = New-Object System.Windows.Forms.Label
    $lblCount.Text = "Risultati: $($Results.Count)"
    $lblCount.Location = New-Object System.Drawing.Point(510, 15)
    $lblCount.Size = New-Object System.Drawing.Size(150, 25)
    $lblCount.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.TextSecondary)
    $lblCount.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $topPanel.Controls.Add($lblCount)
    
    $lv = New-Object System.Windows.Forms.ListView
    $lv.Location = New-Object System.Drawing.Point(10, 75)
    $lv.Size = New-Object System.Drawing.Size(1160, 500)
    $lv.View = "Details"
    $lv.FullRowSelect = $true
    $lv.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    $lv.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $lv.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $lv.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    Enable-DoubleBuffering -Control $lv
    [void]$lv.Columns.Add("File", 160)
    [void]$lv.Columns.Add("Nickname", 130)
    [void]$lv.Columns.Add("Server", 240)
    [void]$lv.Columns.Add("Porta", 50)
    [void]$lv.Columns.Add("Login", 100)
    [void]$lv.Columns.Add("Cambio", 70)
    [void]$lv.Columns.Add("Controllare", 80)
    $resultForm.Controls.Add($lv)
    
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Size = New-Object System.Drawing.Size(1160, 75)
    $bottomPanel.Location = New-Object System.Drawing.Point(10, 585)
    $bottomPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    Set-RoundedCorners -Control $bottomPanel -Radius 10
    $resultForm.Controls.Add($bottomPanel)
    
    $btnOpen = New-UnifiedButton -Text "📂 Apri File" -X 15 -Y 12 -Width 130 -Height 40 -Style "Primary" -OnClick {
        if ($lv.SelectedItems.Count -gt 0) {
            $filePath = $lv.SelectedItems[0].Tag.File
            Start-Process explorer.exe -ArgumentList "/select,`"$filePath`""
        } else {
            [System.Windows.Forms.MessageBox]::Show("Seleziona prima un risultato.", "Attenzione", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
    }
    $bottomPanel.Controls.Add($btnOpen)
    
    $btnDetails = New-UnifiedButton -Text "📋 Dettagli" -X 155 -Y 12 -Width 120 -Height 40 -Style "Accent" -OnClick {
            if ($lv.SelectedItems.Count -gt 0) {
                $data = $lv.SelectedItems[0].Tag
                $details = "File: $($data.File)`r`n`r`n"
                if ($data.HasNicknameChange) {
                    $details += "!!! ATTENZIONE: CAMBIO NICKNAME !!!`r`n"
                    $details += "================================`r`n"
                    $details += $data.NicknameChangeMessage
                    $details += "`r`n================================`r`n`r`n"
                }
                if ($data.HasUnknownServer) {
                    $details += "!!! ATTENZIONE: SERVER NON RICONOSCIUTO !!!`r`n"
                    $details += "================================`r`n"
                    $details += $data.UnknownServerMessage
                    $details += "================================`r`n`r`n"
                }
                if ($data.HasUnknownLogin) {
                    $details += "!!! ATTENZIONE: LOGIN SCONOSCIUTO !!!`r`n"
                    $details += "================================`r`n"
                    $details += $data.UnknownLoginMessage
                    $details += "================================`r`n`r`n"
                }
                $details += "NICKNAME IN ORDINE CRONOLOGICO:`r`n"
                if ($data.AllNicknamesInOrder.Count -gt 0) {
                    foreach ($n in $data.AllNicknamesInOrder) { $details += "  - $n`r`n" }
                } else { $details += "  - Nessuno`r`n" }
                $details += "`r`nTUTTI I NICKNAME:`r`n"
                if ($data.AllNicknames.Count -gt 0) {
                    foreach ($n in $data.AllNicknames) { $details += "  - $n`r`n" }
                } else { $details += "  - Nessuno`r`n" }
                $details += "`r`nSERVER:`r`n"
                if ($data.AllServers.Count -gt 0) {
                    foreach ($s in $data.AllServers) { $details += "  - $s`r`n" }
                } else { $details += "  - Nessuno`r`n" }
                $details += "`r`nSTATO LOGIN:`r`n"
                if ($data.AllLoginStatus.Count -gt 0) {
                    foreach ($l in $data.AllLoginStatus) { $details += "  - $l`r`n" }
                } else { $details += "  - Sconosciuto`r`n" }
                [System.Windows.Forms.MessageBox]::Show($details, "Dettagli Analisi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show("Seleziona prima un risultato.", "Attenzione", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
    }
    $bottomPanel.Controls.Add($btnDetails)
    
    $btnExport = New-UnifiedButton -Text "💾 Esporta CSV" -X 285 -Y 12 -Width 140 -Height 40 -Style "Success" -OnClick {
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "CSV File|*.csv"
        $saveDialog.Title = "Salva risultati"
        $saveDialog.FileName = "log_analysis_results.csv"
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                $sbCsv = New-Object System.Text.StringBuilder
                [void]$sbCsv.AppendLine("File,Nickname,Server,Porta,Login,Cambio,Controllare,ServerSconosciuto,LoginSconosciuto,AllNicknames,AllServers")
                
                foreach ($r in $Results) {
                    $fileName = Split-Path $r.File -Leaf
                    $allNicks = ""
                    if ($r.AllNicknames) { $allNicks = ($r.AllNicknames -join "; ") }
                    $allServs = ""
                    if ($r.AllServers) { $allServs = ($r.AllServers -join "; ") }
                    $loginStatus = $r.LoginStatus
                    $portDisplay = $r.Port
                    if ([string]::IsNullOrEmpty($portDisplay)) { $portDisplay = "-" }
                    $nickname = $r.Nickname
                    if ([string]::IsNullOrEmpty($nickname)) { $nickname = "-" }
                    $server = $r.Server
                    if ([string]::IsNullOrEmpty($server)) { $server = "-" }
                    $hasChange = if ($r.HasNicknameChange) { "SI" } else { "NO" }
                    $unknownServer = if ($r.HasUnknownServer) { "SI" } else { "NO" }
                    $unknownLogin = if ($r.HasUnknownLogin) { "SI" } else { "NO" }
                    $needsCheck = if ($r.HasNicknameChange -or $r.HasUnknownServer -or $r.HasUnknownLogin) { "SI" } else { "NO" }
                    
                    [void]$sbCsv.AppendLine("$fileName,$nickname,$server,$portDisplay,$loginStatus,$hasChange,$needsCheck,$unknownServer,$unknownLogin,""$allNicks"",""$allServs""")
                }
                [System.IO.File]::WriteAllText($saveDialog.FileName, $sbCsv.ToString(), [System.Text.Encoding]::UTF8)
                [System.Windows.Forms.MessageBox]::Show("File esportato!", "Completato", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Errore: $($_.Exception.Message)", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            }
        }
    }
    $bottomPanel.Controls.Add($btnExport)
    
    $btnInstallRAR = New-UnifiedButton -Text "📦 WinRAR" -X 435 -Y 12 -Width 120 -Height 40 -Style "Warning" -OnClick { Install-WinRAR }
    $bottomPanel.Controls.Add($btnInstallRAR)
    
    $btnClose = New-UnifiedButton -Text "✖ Chiudi" -X 1030 -Y 12 -Width 100 -Height 40 -Style "Danger" -OnClick { $resultForm.Close() }
    $bottomPanel.Controls.Add($btnClose)
    
    $allItems = New-Object System.Collections.Generic.List[hashtable]
    foreach ($r in $Results) { $allItems.Add($r) }
    
    function Add-ResultItem {
        param($Result, $ListView)
        try {
            $fileName = Split-Path $Result.File -Leaf
            $nickDisplay = $Result.Nickname
            if ($Result.AllNicknames.Count -gt 1) { $nickDisplay = $nickDisplay + " (+$($Result.AllNicknames.Count - 1))" }
            $serverDisplay = $Result.Server
            if ($Result.AllServers.Count -gt 1) { $serverDisplay = $serverDisplay + " (+$($Result.AllServers.Count - 1))" }
            $portDisplay = $Result.Port
            if ([string]::IsNullOrEmpty($portDisplay)) { $portDisplay = "-" }
            $loginDisplay = $Result.LoginStatus
            $changeDisplay = if ($Result.HasNicknameChange) { "SI" } else { "NO" }
            $needsCheck = $Result.HasNicknameChange -or $Result.HasUnknownServer -or $Result.HasUnknownLogin
            $checkDisplay = if ($needsCheck) { "SI" } else { "NO" }
            
            $item = New-Object System.Windows.Forms.ListViewItem($fileName)
            $item.Tag = $Result
            if ($item -and $item.SubItems) {
                [void]$item.SubItems.Add($nickDisplay)
                [void]$item.SubItems.Add($serverDisplay)
                [void]$item.SubItems.Add($portDisplay)
                [void]$item.SubItems.Add($loginDisplay)
                [void]$item.SubItems.Add($changeDisplay)
                [void]$item.SubItems.Add($checkDisplay)
            }
            
            if ($Result.HasNicknameChange) {
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#3D2A0D")
                $item.ForeColor = [System.Drawing.Color]::Yellow
            } elseif ($Result.HasUnknownServer -or $Result.HasUnknownLogin) {
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#3D1A1A")
                $item.ForeColor = [System.Drawing.Color]::LightSalmon
            } elseif ($Result.LoginStatus -eq "Loggato") {
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#123324")
            } elseif ($Result.LoginStatus -eq "Non Loggato") {
                $item.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#3D1A1A")
            }
            [void]$ListView.Items.Add($item)
        } catch { }
    }
    
    $txtSearch.Add_TextChanged({
        $searchText = $txtSearch.Text.Trim().ToLower()
        $lv.BeginUpdate()
        $lv.Items.Clear()
        if ([string]::IsNullOrWhiteSpace($searchText)) {
            foreach ($r in $allItems) { Add-ResultItem -Result $r -ListView $lv }
            $lblCount.Text = "Risultati: $($lv.Items.Count)"
            $lv.EndUpdate()
            return
        }
        $foundCount = 0
        foreach ($r in $allItems) {
            $fileName = (Split-Path $r.File -Leaf).ToLower()
            
            $allNicks = if ($r.AllNicknames) { ($r.AllNicknames -join " ").ToLower() } else { "" }
            $allServers = if ($r.AllServers) { ($r.AllServers -join " ").ToLower() } else { "" }
            
            if ($fileName.Contains($searchText) -or $allNicks.Contains($searchText) -or $allServers.Contains($searchText)) {
                Add-ResultItem -Result $r -ListView $lv
                $foundCount++
            }
        }
        $lblCount.Text = "Risultati: $foundCount / $($allItems.Count)"
        $lv.EndUpdate()
    })
    
    $lv.BeginUpdate()
    foreach ($r in $Results) { Add-ResultItem -Result $r -ListView $lv }
    $lv.EndUpdate()
    
    $resultForm.ShowDialog($mainForm) | Out-Null
}

# ========================================================================
# SCOPE SELECTION
# ========================================================================

function Select-ScanScope {
    $scopeForm = New-StyledForm -Title "Ambito della ricerca" -Width 480 -Height 320
    
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Seleziona l'ambito di ricerca"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblTitle.AutoSize = $true
    $scopeForm.Controls.Add($lblTitle)
    
    $rbAll = New-Object System.Windows.Forms.RadioButton
    $rbAll.Text = "Tutto il PC (tutte le unita fisse)"
    $rbAll.Location = New-Object System.Drawing.Point(30, 60)
    $rbAll.AutoSize = $true
    $rbAll.Checked = $true
    $rbAll.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $rbAll.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $scopeForm.Controls.Add($rbAll)
    
    $rbUser = New-Object System.Windows.Forms.RadioButton
    $rbUser.Text = "Solo il profilo utente"
    $rbUser.Location = New-Object System.Drawing.Point(30, 95)
    $rbUser.AutoSize = $true
    $rbUser.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $rbUser.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $scopeForm.Controls.Add($rbUser)
    
    $rbCustom = New-Object System.Windows.Forms.RadioButton
    $rbCustom.Text = "Scegli una cartella specifica..."
    $rbCustom.Location = New-Object System.Drawing.Point(30, 130)
    $rbCustom.AutoSize = $true
    $rbCustom.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $rbCustom.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $scopeForm.Controls.Add($rbCustom)
    
    $txtCustom = New-Object System.Windows.Forms.TextBox
    $txtCustom.Location = New-Object System.Drawing.Point(50, 165)
    $txtCustom.Size = New-Object System.Drawing.Size(300, 25)
    $txtCustom.Enabled = $false
    $txtCustom.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
    $txtCustom.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $txtCustom.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $scopeForm.Controls.Add($txtCustom)
    
    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = "Sfoglia..."
    $btnBrowse.Location = New-Object System.Drawing.Point(360, 164)
    $btnBrowse.Size = New-Object System.Drawing.Size(85, 28)
    $btnBrowse.Enabled = $false
    $btnBrowse.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.SurfaceLight)
    $btnBrowse.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $btnBrowse.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowse.FlatAppearance.BorderSize = 1
    $btnBrowse.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.BorderLight)
    $btnBrowse.FlatAppearance.MouseOverBackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.SurfaceHover)
    $btnBrowse.FlatAppearance.MouseDownBackColor = [System.Drawing.ColorPaint]::Dark([System.Drawing.ColorTranslator]::FromHtml($Theme.SurfaceLight), 0.15)
    $btnBrowse.UseVisualStyleBackColor = $false
    $btnBrowse.Cursor = [System.Windows.Forms.Cursors]::Hand
    Set-RoundedCorners -Control $btnBrowse -Radius 6
    $btnBrowse.Add_EnabledChanged({
        try {
            if ($this.Enabled) {
                $this.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.SurfaceLight)
                $this.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
            } else {
                $this.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
                $this.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.TextMuted)
            }
        } catch { }
    })
    $scopeForm.Controls.Add($btnBrowse)
    
    $rbCustom.Add_CheckedChanged({
        $txtCustom.Enabled = $rbCustom.Checked
        $btnBrowse.Enabled = $rbCustom.Checked
    })
    
    $btnBrowse.Add_Click({
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fbd.Description = "Seleziona la cartella da analizzare"
        if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $txtCustom.Text = $fbd.SelectedPath }
    })
    
    $btnOk = New-UnifiedButton -Text "▶ Avvia" -X 140 -Y 220 -Width 200 -Height 40 -Style "Primary" -OnClick { $scopeForm.DialogResult = [System.Windows.Forms.DialogResult]::OK }
    $scopeForm.Controls.Add($btnOk)
    $scopeForm.AcceptButton = $btnOk
    
    $result = $scopeForm.ShowDialog($mainForm)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    
    if ($rbAll.Checked) { return @{ Mode = "All" } }
    elseif ($rbUser.Checked) { return @{ Mode = "Path"; Path = $env:USERPROFILE } }
    else {
        if ([string]::IsNullOrWhiteSpace($txtCustom.Text) -or -not (Test-Path $txtCustom.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Cartella non valida.", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return $null
        }
        return @{ Mode = "Path"; Path = $txtCustom.Text }
    }
}

# ========================================================================
# SEARCH WINDOW
# ========================================================================

function Show-SearchWindow {
    param([System.Collections.Generic.List[string]]$Files)
    
    $searchForm = New-StyledForm -Title "Ricerca full-text - $($Files.Count) file" -Width 1000 -Height 700
    
    $searchPanel = New-Object System.Windows.Forms.Panel
    $searchPanel.Size = New-Object System.Drawing.Size(984, 50)
    $searchPanel.Location = New-Object System.Drawing.Point(8, 8)
    $searchPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    Set-RoundedCorners -Control $searchPanel -Radius 8
    $searchForm.Controls.Add($searchPanel)
    
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = "Cerca:"
    $lblSearch.Location = New-Object System.Drawing.Point(15, 15)
    $lblSearch.AutoSize = $true
    $lblSearch.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $searchPanel.Controls.Add($lblSearch)
    
    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Size(85, 12)
    $txtSearch.Size = New-Object System.Drawing.Size(400, 25)
    $txtSearch.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
    $txtSearch.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $txtSearch.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $searchPanel.Controls.Add($txtSearch)
    
    $chkCase = New-Object System.Windows.Forms.CheckBox
    $chkCase.Text = "Maiuscole/minuscole"
    $chkCase.Location = New-Object System.Drawing.Point(500, 15)
    $chkCase.AutoSize = $true
    $chkCase.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $searchPanel.Controls.Add($chkCase)
    
    $btnSearch = New-UnifiedButton -Text "🔍 Cerca" -X 660 -Y 8 -Width 100 -Height 34 -Style "Primary"
    $searchPanel.Controls.Add($btnSearch)
    
    $btnStop = New-UnifiedButton -Text "⏹ Stop" -X 770 -Y 8 -Width 80 -Height 34 -Style "Danger"
    $btnStop.Enabled = $false
    $searchPanel.Controls.Add($btnStop)
    
    $lv = New-Object System.Windows.Forms.ListView
    $lv.Location = New-Object System.Drawing.Point(8, 65)
    $lv.Size = New-Object System.Drawing.Size(984, 300)
    $lv.View = "Details"
    $lv.FullRowSelect = $true
    $lv.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    $lv.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $lv.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    Enable-DoubleBuffering -Control $lv
    [void]$lv.Columns.Add("File", 320)
    [void]$lv.Columns.Add("Riga", 55)
    [void]$lv.Columns.Add("Anteprima", 580)
    $searchForm.Controls.Add($lv)
    
    $previewPanel = New-Object System.Windows.Forms.Panel
    $previewPanel.Size = New-Object System.Drawing.Size(984, 250)
    $previewPanel.Location = New-Object System.Drawing.Point(8, 375)
    $previewPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    Set-RoundedCorners -Control $previewPanel -Radius 8
    $searchForm.Controls.Add($previewPanel)
    
    $lblPreviewTitle = New-Object System.Windows.Forms.Label
    $lblPreviewTitle.Text = "📄 Anteprima"
    $lblPreviewTitle.Location = New-Object System.Drawing.Point(10, 5)
    $lblPreviewTitle.AutoSize = $true
    $lblPreviewTitle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblPreviewTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.TextSecondary)
    $previewPanel.Controls.Add($lblPreviewTitle)
    
    $rtb = New-Object System.Windows.Forms.RichTextBox
    $rtb.Location = New-Object System.Drawing.Point(10, 25)
    $rtb.Size = New-Object System.Drawing.Size(964, 210)
    $rtb.ReadOnly = $true
    $rtb.Font = New-Object System.Drawing.Font("Consolas", 9)
    $rtb.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Background)
    $rtb.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Text)
    $rtb.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $previewPanel.Controls.Add($rtb)
    
    $statusBar = New-Object System.Windows.Forms.Panel
    $statusBar.Size = New-Object System.Drawing.Size(984, 30)
    $statusBar.Location = New-Object System.Drawing.Point(8, 630)
    $statusBar.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
    Set-RoundedCorners -Control $statusBar -Radius 8
    $searchForm.Controls.Add($statusBar)
    
    $lblResultStatus = New-Object System.Windows.Forms.Label
    $lblResultStatus.Text = "Pronto - $($Files.Count) file disponibili"
    $lblResultStatus.Location = New-Object System.Drawing.Point(15, 5)
    $lblResultStatus.AutoSize = $true
    $lblResultStatus.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.TextSecondary)
    $statusBar.Controls.Add($lblResultStatus)
    
    $resultData = New-Object System.Collections.Generic.List[hashtable]
    $global:CancelSearch = $false
    
    $doSearch = {
        $phrase = $txtSearch.Text
        if ([string]::IsNullOrWhiteSpace($phrase)) {
            [System.Windows.Forms.MessageBox]::Show("Inserisci una frase da cercare.", "Attenzione", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        $lv.BeginUpdate()
        $lv.Items.Clear()
        $lv.EndUpdate()
        $rtb.Clear()
        $resultData.Clear()
        $global:CancelSearch = $false
        $btnSearch.Enabled = $false
        $btnStop.Enabled = $true
        $txtSearch.Enabled = $false
        $comparison = if ($chkCase.Checked) { [System.StringComparison]::Ordinal } else { [System.StringComparison]::OrdinalIgnoreCase }
        $filesScanned = 0
        $matchesFound = 0
        $maxMatches = 2000
        $lv.BeginUpdate()
        foreach ($filePath in $Files) {
            if ($global:CancelSearch) { break }
            $filesScanned++
            if ($filesScanned % 10 -eq 0) {
                $lv.EndUpdate()
                $lblResultStatus.Text = "Analizzati $filesScanned / $($Files.Count) - Trovati: $matchesFound"
                [System.Windows.Forms.Application]::DoEvents()
                $lv.BeginUpdate()
            }
            try {
                $fs = [System.IO.File]::OpenRead($filePath)
                $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress)
                $sr = New-Object System.IO.StreamReader($gz)
                $lineNum = 0
                while (-not $sr.EndOfStream) {
                    if ($global:CancelSearch -or $matchesFound -ge $maxMatches) { break }
                    $line = $sr.ReadLine()
                    $lineNum++
                    if ($line.IndexOf($phrase, $comparison) -ge 0) {
                        $matchesFound++
                        $preview = $line.Trim()
                        if ($preview.Length -gt 200) { $preview = $preview.Substring(0, 200) + "..." }
                        $item = New-Object System.Windows.Forms.ListViewItem($filePath)
                        if ($item -and $item.SubItems) {
                            [void]$item.SubItems.Add([string]$lineNum)
                            [void]$item.SubItems.Add($preview)
                        }
                        [void]$lv.Items.Add($item)
                        [void]$resultData.Add(@{ File = $filePath; Line = $lineNum; Text = $line })
                    }
                }
                $sr.Close(); $gz.Close(); $fs.Close()
            } catch { }
        }
        $lv.EndUpdate()
        $lblResultStatus.Text = "Completato - File: $filesScanned / $($Files.Count) - Trovati: $matchesFound"
        $btnSearch.Enabled = $true
        $btnStop.Enabled = $false
        $txtSearch.Enabled = $true
    }
    
    $btnSearch.Add_Click($doSearch)
    $txtSearch.Add_KeyDown({
        if ($_.KeyCode -eq "Enter") { $_.SuppressKeyPress = $true; & $doSearch }
    })
    $btnStop.Add_Click({ $global:CancelSearch = $true })
    
    $lv.Add_SelectedIndexChanged({
        if ($lv.SelectedIndices.Count -gt 0) {
            $idx = $lv.SelectedIndices[0]
            $data = $resultData[$idx]
            $rtb.Clear()
            $header = "📄 File: $($data.File)`r`n📌 Riga: $($data.Line)`r`n" + ("-" * 60) + "`r`n`r`n"
            $rtb.AppendText($header)
            $phrase = $txtSearch.Text
            $comparison = if ($chkCase.Checked) { [System.StringComparison]::Ordinal } else { [System.StringComparison]::OrdinalIgnoreCase }
            $text = $data.Text
            $startPos = $rtb.TextLength
            $rtb.AppendText($text)
            if (-not [string]::IsNullOrWhiteSpace($phrase)) {
                $searchStart = 0
                while ($true) {
                    $foundIdx = $text.IndexOf($phrase, $searchStart, $comparison)
                    if ($foundIdx -lt 0) { break }
                    $rtb.Select($startPos + $foundIdx, $phrase.Length)
                    $rtb.SelectionBackColor = [System.Drawing.Color]::Yellow
                    $rtb.SelectionColor = [System.Drawing.Color]::Black
                    $searchStart = $foundIdx + $phrase.Length
                    if ($searchStart -ge $text.Length) { break }
                }
                $rtb.SelectionLength = 0
                $rtb.Select(0, 0)
            }
        }
    })
    
    $lv.Add_DoubleClick({
        if ($lv.SelectedIndices.Count -gt 0) {
            $idx = $lv.SelectedIndices[0]
            $filePath = $resultData[$idx].File
            Start-Process explorer.exe -ArgumentList "/select,`"$filePath`""
        }
    })
    
    $searchForm.ShowDialog($mainForm) | Out-Null
}

# ========================================================================
# AVVIO E PULIZIA FINALE
# ========================================================================

$mainForm.Add_FormClosing({
    $global:CancelScan = $true
    $global:CancelSearch = $true
    if ($global:overlayForm -and -not $global:overlayForm.IsDisposed) { 
        try { $global:overlayForm.Close() } catch { }
    }
    if ($global:USNTempFile -and (Test-Path $global:USNTempFile)) {
        try { Remove-Item $global:USNTempFile -Force -ErrorAction SilentlyContinue } catch { }
        $global:USNTempFile = $null
    }
})

Update-Status -Text "Ready" -Color "Success" -Force
[void]$mainForm.ShowDialog()