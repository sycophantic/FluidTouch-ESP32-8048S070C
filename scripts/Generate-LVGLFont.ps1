<#
.SYNOPSIS
    Generates LVGL font files from FontAwesome icons
.DESCRIPTION
    Uses lv_font_conv to create C source files with custom FontAwesome icons.
    Can read from fonts.json config file or use command-line parameters.
.PARAMETER ConfigFile
    Path to JSON configuration file (default: fonts.json)
.PARAMETER FontName
    Name of specific font to generate from config, or font name for manual generation
.PARAMETER FontSize
    Size of the font in pixels (for manual generation)
.PARAMETER Icons
    Hashtable of icon names and codepoints (for manual generation)
.PARAMETER FontFile
    Path to custom font file (optional)
.PARAMETER All
    Generate all fonts from config file
.EXAMPLE
    .\Generate-LVGLFont.ps1 -All
.EXAMPLE
    .\Generate-LVGLFont.ps1 -FontName "fontawesome_icons_20"
.EXAMPLE
    .\Generate-LVGLFont.ps1 -FontName "custom" -FontSize 24 -Icons @{home="0xf015"}
#>

param(
    [string]$ConfigFile = "",
    [string]$FontName = "",
    [int]$FontSize = 0,
    [hashtable]$Icons = @{},
    [string]$FontFile = "",
    [switch]$All
)

$ErrorActionPreference = "Stop"

# Function to process a single font generation
function ProcessFont {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [int]$Size,
        [Parameter(Mandatory=$true)]
        [hashtable]$IconMap,
        [string]$Font = "",
        [string]$Description = ""
    )
    
    if ($Description) {
        Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "  $Description" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    }
    
    # Check Node.js
    try {
        $null = node --version
        Write-Host "✓ Node.js is available" -ForegroundColor Green
    } catch {
        Write-Host "✗ Node.js not found. Install from https://nodejs.org/" -ForegroundColor Red
        exit 1
    }
    
    # Check lv_font_conv
    try {
        $null = npx lv_font_conv --help 2>&1
        Write-Host "✓ lv_font_conv is available" -ForegroundColor Green
    } catch {
        Write-Host "Installing lv_font_conv..." -ForegroundColor Yellow
        npm install -g lv_font_conv
    }
    
    # Download FontAwesome if needed
    if ([string]::IsNullOrEmpty($Font)) {
        $fontAwesomeDir = Join-Path $PSScriptRoot "fontawesome-cache"
        $fontAwesomeFile = Join-Path $fontAwesomeDir "fa-solid-900.ttf"
        
        if (-not (Test-Path $fontAwesomeFile)) {
            Write-Host "Downloading FontAwesome..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Force -Path $fontAwesomeDir | Out-Null
            
            $url = "https://github.com/FortAwesome/Font-Awesome/raw/6.x/webfonts/fa-solid-900.ttf"
            try {
                Invoke-WebRequest -Uri $url -OutFile $fontAwesomeFile -UseBasicParsing
                Write-Host "✓ Downloaded FontAwesome" -ForegroundColor Green
            } catch {
                Write-Host "✗ Download failed. Get manually from https://fontawesome.com/download" -ForegroundColor Red
                exit 1
            }
        }
        
        $Font = $fontAwesomeFile
    }
    
    if (-not (Test-Path $Font)) {
        Write-Host "✗ Font file not found: $Font" -ForegroundColor Red
        exit 1
    }
    
    # Prepare icon list
    $iconList = @($IconMap.Values)
    Write-Host "Icons: $($iconList -join ', ')" -ForegroundColor Cyan
    
    # Output paths
    $outputCDir = Join-Path $PSScriptRoot "..\src\ui\fonts"
    $outputHDir = Join-Path $PSScriptRoot "..\include\ui\fonts"
    $outputCFile = Join-Path $outputCDir "$Name.c"
    $outputHFile = Join-Path $outputHDir "$Name.h"
    
    New-Item -ItemType Directory -Force -Path $outputCDir | Out-Null
    New-Item -ItemType Directory -Force -Path $outputHDir | Out-Null
    
    Write-Host "`nGenerating font..." -ForegroundColor Yellow
    Write-Host "  Source: $Font" -ForegroundColor Gray
    Write-Host "  Size: $Size px" -ForegroundColor Gray
    Write-Host "  Output: $outputCFile" -ForegroundColor Gray
    
    # Build command
    $cmdArgs = @(
        "lv_font_conv",
        "--no-compress",
        "--no-prefilter",
        "--bpp", "4",
        "--size", "$Size",
        "--font", "`"$Font`""
    )
    
    foreach ($codepoint in $iconList) {
        $cmdArgs += "--range"
        $cmdArgs += $codepoint
    }
    
    $cmdArgs += @(
        "--format", "lvgl",
        "--force-fast-kern-format",
        "-o", "`"$outputCFile`""
    )
    
    $cmd = "npx " + ($cmdArgs -join " ")
    
    try {
        Invoke-Expression $cmd
        
        if (-not (Test-Path $outputCFile)) {
            Write-Host "✗ Generation failed" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "✓ Generated: $outputCFile" -ForegroundColor Green
        
        # Generate header
        $headerGuard = ($Name.ToUpper() -replace '[^A-Z0-9_]', '_') + "_H"
        $headerContent = @"
#ifndef $headerGuard
#define $headerGuard

#ifdef __cplusplus
extern "C" {
#endif

#include <lvgl.h>

// Font declaration
LV_FONT_DECLARE($Name);

// Icon definitions
"@

        foreach ($icon in $IconMap.GetEnumerator()) {
            $iconName = $icon.Key.ToUpper()
            $codepoint = $icon.Value
            
            $codepointValue = [Convert]::ToInt32($codepoint.Replace("0x", ""), 16)
            $bytes = [System.Text.Encoding]::UTF8.GetBytes([char]$codepointValue)
            $utf8String = ($bytes | ForEach-Object { "\x{0:X2}" -f $_ }) -join ""
            
            $headerContent += "`n#define FA_ICON_$iconName `"$utf8String`""
        }

        $headerContent += @"


#ifdef __cplusplus
}
#endif

#endif // $headerGuard
"@

        Set-Content -Path $outputHFile -Value $headerContent -Encoding UTF8
        Write-Host "✓ Generated: $outputHFile" -ForegroundColor Green
        
        # Fix the .c file include to match project pattern (just "lvgl.h")
        Write-Host "Fixing .c file include..." -ForegroundColor Yellow
        $cContent = Get-Content $outputCFile -Raw
        # Replace the lv_font_conv generated conditional include with simple "lvgl.h"
        $cContent = $cContent -replace '#ifdef LV_LVGL_H_INCLUDE_SIMPLE\s+#include "lvgl\.h"\s+#else\s+#include "lvgl/lvgl\.h"\s+#endif', '#include "lvgl.h"'
        Set-Content -Path $outputCFile -Value $cContent -NoNewline -Encoding UTF8
        Write-Host "✓ Fixed include in: $outputCFile" -ForegroundColor Green
        
    } catch {
        Write-Host "✗ Error: $_" -ForegroundColor Red
        exit 1
    }
}

# Main execution
if ($ConfigFile -or $All) {
    if ([string]::IsNullOrEmpty($ConfigFile)) {
        $ConfigFile = Join-Path $PSScriptRoot "fonts.json"
    }
    
    if (-not (Test-Path $ConfigFile)) {
        Write-Host "✗ Config file not found: $ConfigFile" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Reading configuration: $ConfigFile" -ForegroundColor Cyan
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    
    if ($All) {
        Write-Host "Generating all fonts..." -ForegroundColor Yellow
        foreach ($fontDef in $config.fonts) {
            $iconHash = @{}
            foreach ($prop in $fontDef.icons.PSObject.Properties) {
                $iconHash[$prop.Name] = $prop.Value
            }
            
            ProcessFont -Name $fontDef.name -Size $fontDef.size -IconMap $iconHash -Description $fontDef.description
        }
        Write-Host "`n✓ All fonts generated successfully!" -ForegroundColor Green
    } else {
        if ([string]::IsNullOrEmpty($FontName)) {
            Write-Host "✗ Specify -FontName or use -All" -ForegroundColor Red
            exit 1
        }
        
        $fontDef = $config.fonts | Where-Object { $_.name -eq $FontName } | Select-Object -First 1
        
        if (-not $fontDef) {
            Write-Host "✗ Font '$FontName' not found in config" -ForegroundColor Red
            Write-Host "Available:" -ForegroundColor Yellow
            foreach ($f in $config.fonts) {
                Write-Host "  - $($f.name)" -ForegroundColor Gray
            }
            exit 1
        }
        
        $iconHash = @{}
        foreach ($prop in $fontDef.icons.PSObject.Properties) {
            $iconHash[$prop.Name] = $prop.Value
        }
        
        ProcessFont -Name $fontDef.name -Size $fontDef.size -IconMap $iconHash -Description $fontDef.description
    }
} else {
    if ([string]::IsNullOrEmpty($FontName) -or $FontSize -eq 0 -or $Icons.Count -eq 0) {
        Write-Host "✗ Specify font parameters or use -All" -ForegroundColor Red
        Write-Host "`nExamples:" -ForegroundColor Yellow
        Write-Host "  .\Generate-LVGLFont.ps1 -All" -ForegroundColor Gray
        Write-Host "  .\Generate-LVGLFont.ps1 -FontName fontawesome_icons_20" -ForegroundColor Gray
        exit 1
    }
    
    ProcessFont -Name $FontName -Size $FontSize -IconMap $Icons -Font $FontFile
}
