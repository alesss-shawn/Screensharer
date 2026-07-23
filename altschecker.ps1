#Requires -Version 5.1
<#
    CoralMC Alts Checker
    Premium Edition - Clean Version
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Net.Http

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ============================================================
# THEME
# ============================================================
$Theme = @{
    Background = "#0B1B2B"
    Surface = "#0F2140"
    SurfaceLight = "#1A2F50"
    SurfaceHover = "#1E3A5F"
    Primary = "#00D4FF"
    PrimaryLight = "#66E5FF"
    Accent = "#FF6B4A"
    Success = "#00E676"
    Warning = "#FFC107"
    Error = "#FF5252"
    Text = "#E8F4F8"
    TextSecondary = "#94B8D0"
    TextMuted = "#5A7A94"
    Border = "#1A3A5A"
}

$ButtonStyles = @{
    Primary = @{ Color = "#00D4FF"; Hover = "#44DDFF" }
    Success = @{ Color = "#00E676"; Hover = "#44E88A" }
    Warning = @{ Color = "#FFC107"; Hover = "#FFD54F" }
    Danger = @{ Color = "#FF5252"; Hover = "#FF7575" }
    Accent = @{ Color = "#FF6B4A"; Hover = "#FF8568" }
}

# ============================================================
# UTILITY FUNCTIONS
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
# CONTROLS
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
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size($Width, $Height)
    $panel.Location = New-Object System.Drawing.Point($X, $Y)
    $panel.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Surface)
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
# UPDATE STATUS
# ============================================================
function Update-Status {
    param([string]$Text, [string]$Color = "Success")
    try {
        Write-Host "[STATUS] $Text" -ForegroundColor $Color
    } catch { }
}

# ============================================================
# FUNCTIONS
# ============================================================
function Check-RecycleBin {
    Update-Status -Text "Checking Recycle Bin..." -Color "Warning"
    Show-Overlay -Title "Recycle Bin" -Subtitle "Checking..."
    
    try {
        $latestFile = Get-ChildItem -Path "C:\`$Recycle.Bin" -Force -Recurse -ErrorAction SilentlyContinue | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -First 1
        
        Hide-Overlay
        
        $resultForm = New-StyledForm -Title "Recycle Bin" -Width 650 -Height 350
        $panel = New-UnifiedPanel -X 15 -Y 15 -Width 620 -Height 300 -Style "Surface" -Title "Latest Recycle Bin Modification"
        $resultForm.Controls.Add($panel)
        
        $yPos = 50
        
        if ($latestFile) {
            $latestDate = $latestFile.LastWriteTime
            $timeSpan = (Get-Date) - $latestDate
            $timeStr = ""
            if ($timeSpan.Days -gt 0) { $timeStr += "$($timeSpan.Days) days, " }
            if ($timeSpan.Hours -gt 0) { $timeStr += "$($timeSpan.Hours) hours, " }
            $timeStr += "$($timeSpan.Minutes) minutes ago"
            
            $lblDate = New-UnifiedLabel -Text "Date: $($latestDate.ToString('dddd dd MMMM yyyy'))" -X 20 -Y $yPos -FontSize 13 -Weight "Bold" -Color "Primary"
            $panel.Controls.Add($lblDate)
            $yPos += 35
            
            $lblTime = New-UnifiedLabel -Text "Time: $($latestDate.ToString('HH:mm:ss'))" -X 20 -Y $yPos -FontSize 12 -Color "Secondary"
            $panel.Controls.Add($lblTime)
            $yPos += 35
            
            $lblFile = New-UnifiedLabel -Text "File: $($latestFile.Name)" -X 20 -Y $yPos -FontSize 11 -Color "Text"
            $panel.Controls.Add($lblFile)
            $yPos += 40
            
            $ageMinutes = $timeSpan.TotalMinutes
            $lblAge = New-UnifiedLabel -Text "" -X 20 -Y $yPos -Width 580 -Height 40 -FontSize 13 -Weight "Bold"
            
            if ($ageMinutes -lt 5) {
                $lblAge.Text = "MODIFIED $timeStr (less than 5 minutes ago!)"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Error)
            } elseif ($ageMinutes -lt 60) {
                $lblAge.Text = "MODIFIED $timeStr (less than 1 hour ago!)"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Error)
            } elseif ($timeSpan.TotalHours -lt 24) {
                $lblAge.Text = "Modified $timeStr (in the last 24 hours)"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Warning)
            } else {
                $lblAge.Text = "Modified $timeStr"
                $lblAge.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
            }
            $panel.Controls.Add($lblAge)
            $yPos += 50
            
            Update-Status -Text "Recycle Bin modified $timeStr" -Color "Success"
            
        } else {
            $lblInfo = New-UnifiedLabel -Text "No modifications found in Recycle Bin." -X 20 -Y 80 -FontSize 14 -Color "Secondary"
            $lblInfo.Size = New-Object System.Drawing.Size(580, 60)
            $panel.Controls.Add($lblInfo)
            Update-Status -Text "Recycle Bin is empty" -Color "Default"
            $yPos = 160
        }
        
        $btnClose = New-UnifiedButton -Text "Close" -X 250 -Y ($yPos + 10) -Width 140 -Height 40 -Style "Danger" -OnClick { $resultForm.Close() }
        $panel.Controls.Add($btnClose)
        
        $resultForm.ShowDialog() | Out-Null
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Error checking Recycle Bin" -Color "Error"
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}

function Check-Recordings {
    Update-Status -Text "Checking recordings..." -Color "Warning"
    Show-Overlay -Title "Recordings" -Subtitle "Checking..."
    
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
    
    $resultForm = New-StyledForm -Title "Recordings Check" -Width 600 -Height 400
    
    if ($rilevati.Count -gt 0) {
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
        $lblTitle.Size = New-Object System.Drawing.Size(550, 30)
        $lblTitle.Text = "Recording programs open: " + (($rilevati | ForEach-Object { $_.Name }) -join ", ")
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Warning)
        $resultForm.Controls.Add($lblTitle)
        
        $yPos = 70
        foreach ($r in $rilevati) {
            $lbl = New-Object System.Windows.Forms.Label
            $lbl.Text = " * $($r.Name)"
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
        $lblTitle.Text = "No recording programs open"
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Theme.Success)
        $resultForm.Controls.Add($lblTitle)
    }
    
    $btnClose = New-UnifiedButton -Text "Close" -X 230 -Y 300 -Width 140 -Height 40 -Style "Danger" -OnClick { $resultForm.Close() }
    $resultForm.Controls.Add($btnClose)
    
    $resultForm.ShowDialog() | Out-Null
    
    Update-Status -Text "Recordings check completed" -Color "Success"
}

function Get-USNJournalStatus {
    $result = @{
        Status = "NOT AVAILABLE"
        Details = ""
        IsDeleted = $false
    }
    try {
        $usnInfo = & fsutil usn queryjournal C: 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($usnInfo)) {
            $result.Status = "DISABLED"
            $result.Details = "USN Journal is disabled or deleted"
            $result.IsDeleted = $true
            return $result
        }
        
        $result.Status = "ACTIVE"
        $result.Details = "USN Journal is active and working"
        $result.IsDeleted = $false
        
    } catch {
        $result.Status = "ERROR"
        $result.Details = "Error: $($_.Exception.Message)"
        $result.IsDeleted = $true
    }
    return $result
}

function Start-LogGzSearch {
    Update-Status -Text "Searching for .log.gz files..." -Color "Warning"
    Show-Overlay -Title "Search" -Subtitle "Scanning..."
    
    $found = New-Object System.Collections.Generic.List[string]
    $global:CancelScan = $false
    
    try {
        $roots = [System.IO.DriveInfo]::GetDrives() |
            Where-Object { $_.DriveType -eq "Fixed" -and $_.IsReady } |
            ForEach-Object { $_.RootDirectory.FullName }
        
        foreach ($root in $roots) {
            if ($global:CancelScan) { break }
            
            $dirsToScan = New-Object System.Collections.Generic.Queue[string]
            $dirsToScan.Enqueue($root)
            $counter = 0
            
            while ($dirsToScan.Count -gt 0 -and -not $global:CancelScan) {
                $currentDir = $dirsToScan.Dequeue()
                $counter++
                if ($counter % 100 -eq 0) { Update-Status -Text "Scanning: $currentDir" -Color "Warning" }
                try {
                    $filesHere = [System.IO.Directory]::EnumerateFiles($currentDir, "*.log.gz")
                    foreach ($f in $filesHere) {
                        if ($global:CancelScan) { break }
                        if (Test-IsGzipSignature -Path $f) { $found.Add($f) }
                    }
                } catch { }
                try {
                    $subDirs = [System.IO.Directory]::EnumerateDirectories($currentDir)
                    foreach ($d in $subDirs) { $dirsToScan.Enqueue($d) }
                } catch { }
            }
        }
    } finally {
        Hide-Overlay
    }
    
    if ($found.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No valid .log.gz files found.", "Search Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        Update-Status -Text "No files found" -Color "Default"
        return
    }
    Update-Status -Text "Found $($found.Count) files" -Color "Success"
    [System.Windows.Forms.MessageBox]::Show("Found $($found.Count) .log.gz files", "Search Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

function Start-JournalRead {
    if (-not (Test-IsAdmin)) {
        $r = [System.Windows.Forms.MessageBox]::Show(
            "USN Journal reading requires Administrator privileges.`nDo you want to restart as Administrator?",
            "Privileges Required",
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
    
    Update-Status -Text "Reading USN Journal..." -Color "Warning"
    Show-Overlay -Title "USN Journal" -Subtitle "Reading..."
    
    $global:USNTempFile = $null
    
    try {
        $global:USNTempFile = [System.IO.Path]::GetTempFileName()
        $global:USNTempFile = [System.IO.Path]::ChangeExtension($global:USNTempFile, ".txt")
        
        $argList = "/c `"fsutil usn readjournal C: csv > `"$global:USNTempFile`"`""
        
        $p = Start-Process -FilePath "cmd.exe" -ArgumentList $argList -Wait -WindowStyle Hidden -PassThru
        
        Hide-Overlay
        
        if (Test-Path $global:USNTempFile) {
            $fileInfo = Get-Item $global:USNTempFile
            if ($fileInfo.Length -gt 0) {
                Update-Status -Text "USN Journal analyzed" -Color "Success"
                Start-Process -FilePath "notepad.exe" -ArgumentList $global:USNTempFile -WindowStyle Normal
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Analysis complete! The temporary file has been opened with Notepad.",
                    "Complete",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            } else {
                Update-Status -Text "No matches found" -Color "Default"
                [System.Windows.Forms.MessageBox]::Show(
                    "No matches found in USN Journal.",
                    "No Results",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                Remove-Item $global:USNTempFile -Force -ErrorAction SilentlyContinue
                $global:USNTempFile = $null
            }
        }
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Error" -Color "Error"
        [System.Windows.Forms.MessageBox]::Show("Error reading journal: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        if ($global:USNTempFile -and (Test-Path $global:USNTempFile)) {
            Remove-Item $global:USNTempFile -Force -ErrorAction SilentlyContinue
            $global:USNTempFile = $null
        }
    }
}

function Check-SystemIntegrity {
    Update-Status -Text "Analyzing system..." -Color "Warning"
    Show-Overlay -Title "System Analysis" -Subtitle "Checking..."
    
    try {
        $usnStatus = Get-USNJournalStatus
        
        Hide-Overlay
        
        $resultForm = New-StyledForm -Title "System Analysis Report" -Width 700 -Height 400
        $panel = New-UnifiedPanel -X 15 -Y 15 -Width 670 -Height 340 -Style "Surface" -Title "System Analysis Results"
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
            $lblWarning = New-UnifiedLabel -Text "WARNING: USN Journal is deleted or disabled!" -X 20 -Y $yPos -FontSize 13 -Weight "Bold" -Color "Error"
            $panel.Controls.Add($lblWarning)
            $yPos += 40
        } else {
            $lblOk = New-UnifiedLabel -Text "System is clean - No anomalies detected" -X 20 -Y $yPos -FontSize 13 -Weight "Bold" -Color "Success"
            $panel.Controls.Add($lblOk)
            $yPos += 40
        }
        
        $btnClose = New-UnifiedButton -Text "Close" -X 260 -Y ($yPos + 10) -Width 140 -Height 40 -Style "Danger" -OnClick { $resultForm.Close() }
        $panel.Controls.Add($btnClose)
        
        $resultForm.ShowDialog() | Out-Null
        
        Update-Status -Text "Analysis complete" -Color "Success"
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Error" -Color "Error"
        [System.Windows.Forms.MessageBox]::Show("Error during analysis: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}

function Start-AutoAnalyze {
    Update-Status -Text "Auto analysis in progress..." -Color "Warning"
    Show-Overlay -Title "Auto Analysis" -Subtitle "Searching for log data..."
    
    try {
        $found = New-Object System.Collections.Generic.List[string]
        $global:CancelScan = $false
        
        $roots = [System.IO.DriveInfo]::GetDrives() |
            Where-Object { $_.DriveType -eq "Fixed" -and $_.IsReady } |
            ForEach-Object { $_.RootDirectory.FullName }
        
        foreach ($root in $roots) {
            if ($global:CancelScan) { break }
            
            $dirsToScan = New-Object System.Collections.Generic.Queue[string]
            $dirsToScan.Enqueue($root)
            $counter = 0
            
            while ($dirsToScan.Count -gt 0 -and -not $global:CancelScan) {
                $currentDir = $dirsToScan.Dequeue()
                $counter++
                if ($counter % 100 -eq 0) { Update-Status -Text "Scanning: $currentDir" -Color "Warning" }
                try {
                    $filesHere = [System.IO.Directory]::EnumerateFiles($currentDir, "*.log.gz")
                    foreach ($f in $filesHere) {
                        if ($global:CancelScan) { break }
                        if (Test-IsGzipSignature -Path $f) { $found.Add($f) }
                    }
                } catch { }
                try {
                    $subDirs = [System.IO.Directory]::EnumerateDirectories($currentDir)
                    foreach ($d in $subDirs) { $dirsToScan.Enqueue($d) }
                } catch { }
            }
        }
        
        Hide-Overlay
        
        if ($found.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No .log.gz files found.", "Analysis Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            Update-Status -Text "No files found" -Color "Default"
            return
        }
        
        Update-Status -Text "Found $($found.Count) files" -Color "Success"
        [System.Windows.Forms.MessageBox]::Show("Found $($found.Count) .log.gz files to analyze.", "Analysis Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        
    } catch {
        Hide-Overlay
        Update-Status -Text "Error" -Color "Error"
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
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

# Header
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

# Content Panel
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Size = New-Object System.Drawing.Size(700, 600)
$contentPanel.Location = New-Object System.Drawing.Point(10, 110)
$contentPanel.BackColor = [System.Drawing.Color]::Transparent
$contentPanel.AutoScroll = $true
$mainForm.Controls.Add($contentPanel)

# Card Factory
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
    
    return $card
}

# Cards
$card1 = New-ActionCard -Y 5 -IconChar "F" -IconColor $Theme.Primary -Title "Search .log.gz files" -Desc "Full-text search in compressed .log.gz files" -ButtonText "Start" -ButtonStyle "Primary" -OnClick { Start-LogGzSearch }
$contentPanel.Controls.Add($card1)

$card2 = New-ActionCard -Y 100 -IconChar "J" -IconColor $Theme.Accent -Title "Analyze USN Journal" -Desc "Deep analysis of USN Journal (requires Admin)" -ButtonText "Start" -ButtonStyle "Accent" -OnClick { Start-JournalRead }
$contentPanel.Controls.Add($card2)

$card3 = New-ActionCard -Y 195 -IconChar "A" -IconColor $Theme.Success -Title "Auto Analysis" -Desc "Analyze nicknames, servers and login status from logs" -ButtonText "Start" -ButtonStyle "Success" -OnClick { Start-AutoAnalyze }
$contentPanel.Controls.Add($card3)

$card4 = New-ActionCard -Y 290 -IconChar "S" -IconColor $Theme.Warning -Title "System Analysis" -Desc "Check system integrity and USN Journal" -ButtonText "Analyze" -ButtonStyle "Warning" -OnClick { Check-SystemIntegrity }
$contentPanel.Controls.Add($card4)

$card5 = New-ActionCard -Y 385 -IconChar "R" -IconColor "#FF6B6B" -Title "Recycle Bin Check" -Desc "Check latest modification date of Recycle Bin" -ButtonText "Check" -ButtonStyle "Danger" -OnClick { Check-RecycleBin }
$contentPanel.Controls.Add($card5)

$card6 = New-ActionCard -Y 480 -IconChar "V" -IconColor "#FF6BFF" -Title "Active Recordings" -Desc "Check if any recordings are active" -ButtonText "Check" -ButtonStyle "Primary" -OnClick { Check-Recordings }
$contentPanel.Controls.Add($card6)

# Footer
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
# CLEANUP
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

# ============================================================
# START
# ============================================================
Update-Status -Text "Ready" -Color "Success"
[void]$mainForm.ShowDialog()
