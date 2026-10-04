# ================================
# Module: Windows Defender Status
# Checks Defender state, real-time/tamper protection, cloud protection,
# and signature version via registry.
# Hive: HKLM\SOFTWARE\Microsoft\Windows Defender
# Mirrors: modules/defender.py
# ================================

$script:DefenderBase = "SOFTWARE\Microsoft\Windows Defender"

# ---------- Registry helper --------------------------------------------------

function _Read-DefReg {
    param([string]$KeyPath, [string]$ValueName)
    Write-Source "[HKLM\$KeyPath] :: GetValue('$ValueName')"
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($KeyPath)
        if ($null -eq $key) { return $null }
        $val = $key.GetValue($ValueName, $null)
        $key.Close()
        return $val
    } catch {
        return $null
    }
}

# ---------- Display helper ---------------------------------------------------



# ---------- Main Entry -------------------------------------------------------

function Get-DefenderState {

    Write-RunningHeader "defender"

    # -- Query all values first -----------------------------------------------
    $disabled = _Read-DefReg $script:DefenderBase "DisableAntiSpyware"
    $realtime = _Read-DefReg "$script:DefenderBase\Real-Time Protection" "DisableRealtimeMonitoring"
    $tamper   = _Read-DefReg "$script:DefenderBase\Features"             "TamperProtection"
    $cloud    = _Read-DefReg "$script:DefenderBase\Spynet"               "SpynetReporting"
    $sigVer   = _Read-DefReg "$script:DefenderBase\Signature Updates"    "AVSignatureVersion"

    # -- Build result rows ----------------------------------------------------
    $rows = @()

    # 1. Defender Disabled
    if ($null -eq $disabled) {
        $rows += [PSCustomObject]@{ Label = "Defender Disabled"; Value = "unknown"; Risk = "UNKNOWN"
            Detail = "Registry key not accessible - may require admin rights." }
    } elseif ([bool]$disabled) {
        $rows += [PSCustomObject]@{ Label = "Defender Disabled"; Value = "True"; Risk = "CRITICAL"
            Detail = "Defender is fully disabled. Likely replaced by a third-party EDR or intentionally turned off." }
    } else {
        $rows += [PSCustomObject]@{ Label = "Defender Disabled"; Value = "False"; Risk = "LOW"
            Detail = "Defender is active." }
    }

    # 2. Real-Time Protection (inverted flag: 1 = OFF)
    if ($null -eq $realtime) {
        $rows += [PSCustomObject]@{ Label = "Real-Time Protection"; Value = "unknown"; Risk = "UNKNOWN"
            Detail = "Could not read registry value." }
    } elseif ([bool]$realtime) {
        $rows += [PSCustomObject]@{ Label = "Real-Time Protection"; Value = "disabled"; Risk = "CRITICAL"
            Detail = "Real-time scanning is OFF. Files are not inspected on access." }
    } else {
        $rows += [PSCustomObject]@{ Label = "Real-Time Protection"; Value = "enabled"; Risk = "LOW"
            Detail = "Real-time protection is active." }
    }

    # 3. Tamper Protection (5=on, 4=off/HIGH, other=partial/MEDIUM)
    if ($null -eq $tamper) {
        $rows += [PSCustomObject]@{ Label = "Tamper Protection"; Value = "unknown"; Risk = "UNKNOWN"
            Detail = "Could not read TamperProtection value." }
    } elseif ($tamper -eq 5) {
        $rows += [PSCustomObject]@{ Label = "Tamper Protection"; Value = "enabled"; Risk = "LOW"
            Detail = "Tamper protection is on. Registry/service modifications by non-privileged processes are blocked." }
    } elseif ($tamper -eq 4) {
        $rows += [PSCustomObject]@{ Label = "Tamper Protection"; Value = "disabled (value=4)"; Risk = "HIGH"
            Detail = "Tamper protection is off (value=4). Defender settings can be modified without elevation." }
    } else {
        $rows += [PSCustomObject]@{ Label = "Tamper Protection"; Value = "partially off (value=$tamper)"; Risk = "MEDIUM"
            Detail = "Tamper protection is off (value=$tamper). Defender settings can be modified without elevation." }
    }

    # 4. Cloud Protection (SpynetReporting > 0 = enabled)
    $cloudOn = ($null -ne $cloud) -and ($cloud -gt 0)
    if ($cloudOn) {
        $rows += [PSCustomObject]@{ Label = "Cloud Protection"; Value = "enabled"; Risk = "LOW"
            Detail = "Cloud-delivered protection sends suspicious samples to Microsoft." }
    } else {
        $rows += [PSCustomObject]@{ Label = "Cloud Protection"; Value = "disabled"; Risk = "MEDIUM"
            Detail = "Cloud protection is off. Signature-only detection in use." }
    }

    # 5. Signature Version
    $sigValue = if ($null -eq $sigVer -or $sigVer -eq "") { "unknown" } else { $sigVer }
    $rows += [PSCustomObject]@{ Label = "Signature Version"; Value = $sigValue; Risk = "INFO"
        Detail = "Outdated signatures reduce detection capability." }

    # -- Overall risk: mirrors Python (CRITICAL > HIGH/MEDIUM > LOW) ----------
    $overallRisk = "LOW"
    foreach ($r in $rows) {
        if ($r.Risk -eq "CRITICAL")                                    { $overallRisk = "CRITICAL"; break }
        if ($r.Risk -eq "HIGH"   -and $overallRisk -ne "CRITICAL")    { $overallRisk = "HIGH" }
        if ($r.Risk -eq "MEDIUM" -and $overallRisk -notin @("CRITICAL","HIGH")) { $overallRisk = "MEDIUM" }
    }

    # -- Header ---------------------------------------------------------------
    Write-ModuleHeader "WINDOWS DEFENDER STATUS" $overallRisk

    # -- Rows -----------------------------------------------------------------
    foreach ($r in $rows) {
        Write-ModuleRow $r.Label $r.Value $r.Risk $r.Detail
    }

    # -- Notes ----------------------------------------------------------------
    Write-ModuleNotes @(
        "Real-time protection off  ->  Drop $($Global:DR.Payloads) directly without in-memory evasion."
        "Tamper protection off     ->  Modify Defender exclusions via registry (HKLM\...\Exclusions)."
        "Cloud protection off      ->  Unsigned/unknown binaries less likely submitted for analysis."
        "Check signature age       ->  Outdated sigs mean recent $($Global:DR.Payloads) may evade detection."
    )

    # -- Feed global results silently -----------------------------------------
    foreach ($r in $rows) { Add-Result "Defender" $r.Label $r.Value $r.Risk }
}

Register-Module "defender" "Defender state, real-time/tamper protection, signature version" { Get-DefenderState }
