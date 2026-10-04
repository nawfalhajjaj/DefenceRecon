# Global results — List for O(1) Add instead of array-copy on every +=
$Global:Results = [System.Collections.Generic.List[PSCustomObject]]::new()

# Verbose flag — set via -ShowSource switch in DefenceRecon.ps1 or 'verbose true/false' in CLI
$Global:VerboseMode = $false

# ─── Shared colour / risk helpers ────────────────────────────────────────────

function _Get-RiskColor {
    param([string]$Risk)
    switch ($Risk) {
        "CRITICAL" { return "Red"      }
        "HIGH"     { return "Red"      }
        "MEDIUM"   { return "Yellow"   }
        "LOW"      { return "Green"    }
        default    { return "DarkGray" }
    }
}

function _Get-RiskTag {
    param([string]$Risk)
    switch ($Risk) {
        "CRITICAL" { return "CRIT" }
        "HIGH"     { return "HIGH" }
        "MEDIUM"   { return "MED"  }
        "LOW"      { return "ok"   }
        "UNKNOWN"  { return "?"    }
        default    { return "--"   }
    }
}

# ─── Shared display functions (used by every module) ─────────────────────────

function Write-RunningHeader {
    param([string]$ModuleName)
    Write-Host ""
    Write-Host "  [+] $($ModuleName.ToUpper())" -ForegroundColor Yellow
    Write-Host ""
}

function Write-ModuleHeader {
    param([string]$Title, [string]$Risk)
    $riskColor = _Get-RiskColor $Risk
    $sep       = ([string][char]0x2500) * 68
    $riskLabel = "RISK: $Risk"
    $gap       = [math]::Max(2, 68 - $Title.Length - $riskLabel.Length)
    Write-Host ""
    Write-Host -NoNewline "  $Title" -ForegroundColor White
    Write-Host -NoNewline (" " * $gap)
    Write-Host $riskLabel -ForegroundColor $riskColor
    Write-Host "  $sep" -ForegroundColor DarkGray
}

function Write-ModuleRow {
    param([string]$Label, [string]$Value, [string]$Risk, [string]$Detail = "")
    $riskColor  = _Get-RiskColor $Risk
    $riskTag    = _Get-RiskTag   $Risk
    $valueColor = switch ($Risk) {
        "CRITICAL" { "Red"    } "HIGH"   { "Red"    } "MEDIUM" { "Yellow" }
        "LOW"      { "Green"  } default  { "White"  }
    }

    # Enforce column widths — truncate with ... if over limit
    $maxL = 28; $maxV = 22
    $lbl  = if ($Label.Length -gt $maxL) { $Label.Substring(0, $maxL - 3) + "..." } else { $Label }
    $val  = if ($Value.Length -gt $maxV) { $Value.Substring(0, $maxV - 3) + "..." } else { $Value }

    $labelPad = $lbl.PadRight(30)
    $valuePad = $val.PadRight(24)

    Write-Host -NoNewline "   $labelPad" -ForegroundColor Gray
    Write-Host -NoNewline $valuePad      -ForegroundColor $valueColor
    Write-Host $riskTag                  -ForegroundColor $riskColor

    # Detail line — only for actionable risks, word-wrapped at 63 chars
    if ($Detail -ne "" -and $Risk -in @("CRITICAL","HIGH","MEDIUM")) {
        $indent   = "     "
        $maxWidth = 63
        $words    = $Detail -split ' '
        $line     = $indent
        foreach ($word in $words) {
            if (($line + $word).Length -gt $maxWidth) {
                Write-Host $line.TrimEnd() -ForegroundColor DarkGray
                $line = "$indent$word "
            } else {
                $line += "$word "
            }
        }
        if ($line.Trim() -ne "") { Write-Host $line.TrimEnd() -ForegroundColor DarkGray }
    }
}

function Write-ModuleNotes {
    param([string[]]$Notes)
    $sep = ([string][char]0x2500) * 68
    Write-Host "  $sep" -ForegroundColor DarkGray
    foreach ($n in $Notes) {
        Write-Host "  $n" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ─── Source tracing (verbose mode) ───────────────────────────────────────────

function Write-Source {
    param([string]$Source)
    if ($Global:VerboseMode) {
        Write-Host "  [src] $Source" -ForegroundColor DarkGray
    }
}

# ─── Result accumulator ───────────────────────────────────────────────────────

function Add-Result {
    param($Module, $Name, $Value, $Risk)
    $Global:Results.Add([PSCustomObject]@{
        Module = $Module
        Name   = $Name
        Value  = $Value
        Risk   = $Risk
    })
}
