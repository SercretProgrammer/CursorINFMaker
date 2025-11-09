# Ask user for input
$cursorFolder = Read-Host "Cursor Folder"
$schemeName = Read-Host "Cursor Folder result Name"

# Validate input folder
if (-not (Test-Path $cursorFolder)) {
    Write-Host "Error: Folder does not exist." -ForegroundColor Red
    exit
}

# Get all .cur and .ani files in the folder
$cursorFiles = Get-ChildItem -Path (Join-Path $cursorFolder "*") -Include *.cur, *.ani -File -ErrorAction SilentlyContinue
if (-not $cursorFiles) {
    Write-Host "Error: No cursor files found in the folder." -ForegroundColor Red
    exit
}

# Map cursor roles to expected Windows names
$cursorMap = @{
    "Arrow"      = "Arrow"
    "Help"       = "Help"
    "AppStarting"= "AppStarting"
    "Wait"       = "Wait"
    "Cross"      = "Cross"
    "IBeam"      = "IBeam"
    "NWPen"      = "NWPen"
    "No"         = "No"
    "SizeNS"     = "SizeNS"
    "SizeWE"     = "SizeWE"
    "SizeNWSE"   = "SizeNWSE"
    "SizeNESW"   = "SizeNESW"
    "SizeAll"    = "SizeAll"
    "UpArrow"    = "UpArrow"
    "Hand"       = "Hand"
}

# Find Arrow file for fallback
$arrowFile = ($cursorFiles | Where-Object { $_.BaseName -match "Arrow" }) | Select-Object -First 1

# Build [Scheme.Reg] section
$schemeRegLines = @()
$schemeRegLines += "HKCU,""Control Panel\Cursors"","""","""",""$schemeName"""

foreach ($key in $cursorMap.Keys) {
    $match = $cursorFiles | Where-Object { $_.BaseName -match $key } | Select-Object -First 1
    if (-not $match -and $arrowFile) { $match = $arrowFile }
    if ($match) {
        $schemeRegLines += "HKCU,""Control Panel\Cursors"",""$key"",,""%$($match.BaseName)%"""
    }
}

# Build [Strings] section
$stringsLines = @("SchemeName=""$schemeName""")
foreach ($file in $cursorFiles) {
    $stringsLines += "$($file.BaseName)=""$($file.Name)"""
}

# Build [SourceDisksNames] section (all in current folder)
$sourceDiskLines = @("1 = %DiskName%,,")  # DiskName is arbitrary
$sourceStrings = @("DiskName=""Cursor Source""")

# Build [SourceDisksFiles] section (files to copy)
$sourceFilesLines = $cursorFiles | ForEach-Object { "$($_.Name)=1" }

# Build [DestinationDirs] section
$destinationDirsLines = @("CopyCursors=10,`"$env:SystemRoot\Cursors\$schemeName`"")

# Build [CopyCursors] section
$copyCursorsLines = $cursorFiles | ForEach-Object { "$($_.Name)" }

# Combine all sections
$infContent = @(
"[Version]",
'Signature="$CHICAGO$"',
"",
"[DefaultInstall]",
"CopyFiles=CopyCursors",
"AddReg=Scheme.Reg",
"",
"[Scheme.Reg]"
) + $schemeRegLines + @(
"",
"[Strings]"
) + $stringsLines + @(
"",
"[SourceDisksNames]"
) + $sourceDiskLines + @(
"",
"[SourceDisksFiles]"
) + $sourceFilesLines + @(
"",
"[DestinationDirs]"
) + $destinationDirsLines + @(
"",
"[CopyCursors]"
) + $copyCursorsLines + @(
"",
"[Strings]"
) + $sourceStrings

# Save the install.inf to current folder
$outPath = Join-Path (Get-Location) "install.inf"
$infContent | Out-File -FilePath $outPath -Encoding ASCII

Write-Host ""
Write-Host "[OK] install.inf created successfully!" -ForegroundColor Green
Write-Host "[FOLDER] Location: $outPath"
Write-Host "[INFO] Place this INF and all cursor files into the target folder, then right-click > Install."
Write-Host "The INF will copy all cursors into `C:\Windows\Cursors\$schemeName` and set the scheme."
[system]