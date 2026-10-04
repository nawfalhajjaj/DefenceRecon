# ================================
# Module: PowerShell Logging
# Checks Script Block Logging, Module Logging, and Transcription
# settings - the three primary PS visibility controls for defenders.
# Mirrors: modules/ps_logging.py
# ================================

$script:PSBase = "SOFTWARE\Policies\Microsoft\Windows\PowerShell"

# ---------- Registry helper --------------------------------------------------
# Reads a value from a subkey under the PS policy base.
# Returns $null if the key or value is missing (= feature not configured = OFF).

function _Read-PSReg {
    param([string]$SubKey, [string]$ValueName)
    $fullPath = "$script:PSBase\$SubKey"
    Write-Source "[HKLM\$fullPath] :: GetValue('$ValueName')"
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($fullPath)
        if ($null -eq $key) { return $null }
        $val = $key.GetValue($ValueName, $null)
        $key.Close()
        return $val
    } catch {
        return $null
    }
}

# ---------- Transcription path helper ----------------------------------------
# Only called when Transcription is enabled. Returns the configured output
# directory, or "not configured" if the value is absent.

function _Read-TranscriptionPath {
    $fullPath = "$script:PSBase\Transcription"
    Write-Source "[HKLM\$fullPath] :: GetValue('OutputDirectory')"
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($fullPath)
        if ($null -eq $key) { return "not configured" }
        $val = $key.GetValue("OutputDirectory", $null)
        $key.Close()
        if ($null -eq $val -or $val -eq "") { return "not configured" }
        return $val
    } catch {
        return "not configured"
    }
}


# ---------- Main Entry -------------------------------------------------------

function Get-LoggingState {

    Write-RunningHeader "ps_logging"

    # -- Query all values first -----------------------------------------------
    $sbl       = _Read-PSReg "ScriptBlockLogging" "EnableScriptBlockLogging"
    $sbli      = _Read-PSReg "ScriptBlockLogging" "EnableScriptBlockInvocationLogging"
    $mod       = _Read-PSReg "ModuleLogging"      "EnableModuleLogging"
    $trans     = _Read-PSReg "Transcription"      "EnableTranscription"

    # Absent key = OFF (same default behaviour as Python: missing -> False)
    $sblOn   = ($null -ne $sbl)   -and [bool]$sbl
    $sbliOn  = ($null -ne $sbli)  -and [bool]$sbli
    $modOn   = ($null -ne $mod)   -and [bool]$mod
    $transOn = ($null -ne $trans) -and [bool]$trans

    # Transcription path only relevant when transcription is on
    $transPath = if ($transOn) { _Read-TranscriptionPath } else { "not configured" }

    # -- Overall risk: mirrors Python exactly ---------------------------------
    # Inverted from other modules - logging ON is bad for the attacker
    # LOW  = none of the three main controls are on
    # HIGH = all three are on
    # MEDIUM = some are on
    $anyLogging = $sblOn -or $modOn -or $transOn
    $allLogging = $sblOn -and $modOn -and $transOn

    $overallRisk = if (-not $anyLogging) { "LOW" } `
        elseif ($allLogging)             { "HIGH" } `
        else                             { "MEDIUM" }

    # -- Header ---------------------------------------------------------------
    Write-ModuleHeader "POWERSHELL LOGGING" $overallRisk

    # -- Rows -----------------------------------------------------------------
    $sblValue   = if ($sblOn)   { "enabled" } else { "disabled" }
    $sbliValue  = if ($sbliOn)  { "enabled" } else { "disabled" }
    $modValue   = if ($modOn)   { "enabled" } else { "disabled" }
    $transValue = if ($transOn) { "enabled" } else { "disabled" }
    $sblRisk    = if ($sblOn)   { "HIGH"    } else { "LOW" }
    $sbliRisk   = if ($sbliOn)  { "MEDIUM"  } else { "LOW" }
    $modRisk    = if ($modOn)   { "HIGH"    } else { "LOW" }
    $transRisk  = if ($transOn) { "HIGH"    } else { "LOW" }

    Write-ModuleRow "Script Block Logging" $sblValue  $sblRisk  "Captures full script content before obfuscation is applied."
    Write-ModuleRow "Invocation Logging"   $sbliValue $sbliRisk "Logs start/stop events for every script block."
    Write-ModuleRow "Module Logging"       $modValue  $modRisk  "Logs pipeline output for specified modules. Catches cmdlet-level activity."
    Write-ModuleRow "Transcription"        $transValue $transRisk "Saves a full session transcript to a file."

    if ($transOn) {
        Write-ModuleRow "Transcription Output Dir" $transPath "INFO" ""
    }

    # -- Notes ----------------------------------------------------------------
    Write-ModuleNotes @(
        "No SBL / logging       ->  PowerShell runs unlogged. Use freely for staging and $($Global:DR.LatMov)."
        "SBL enabled            ->  Use .NET direct ($($Global:DR.AddType) / [$($Global:DR.SysRef)]) instead."
        "SBL enabled            ->  $($Global:DR.PS2byp) if v2 is installed."
        "Module logging on      ->  Avoid well-known modules (ActiveDirectory, PSSession)."
        "Transcription on       ->  Output path may reveal a central log share. Check the path."
    )

    # -- Feed global results silently -----------------------------------------
    Add-Result "PSLogging" "Script Block Logging" $sblValue   $sblRisk
    Add-Result "PSLogging" "Invocation Logging"   $sbliValue  $sbliRisk
    Add-Result "PSLogging" "Module Logging"       $modValue   $modRisk
    Add-Result "PSLogging" "Transcription"        $transValue $transRisk
    if ($transOn) { Add-Result "PSLogging" "Transcription Output Dir" $transPath "INFO" }
}

Register-Module "ps_logging" "Script Block Logging, Module Logging, Transcription status" { Get-LoggingState }
