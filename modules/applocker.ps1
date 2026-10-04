# ================================
# Module: AppLocker / WDAC
# Enumerates AppLocker enforcement mode per rule collection and
# checks WDAC (Windows Defender App Control) kernel-level policy status.
# Mirrors: modules/applocker.py
# ================================

$script:AppLockerBase = "SOFTWARE\Policies\Microsoft\Windows\SrpV2"

# Registry subkey -> friendly name
$script:RuleCollections = [ordered]@{
    "Exe"    = "Executables"
    "Script" = "Scripts"
    "Msi"    = "Windows Installers"
    "Dll"    = "DLLs"
    "Appx"   = "Packaged Apps"
}

$script:EnforcementModes = @{
    0 = "not configured"
    1 = "enforce"
    2 = "audit only"
}

# ---------- AppIDSvc Query ---------------------------------------------------

function _Query-AppIDSvc {
    Write-Source "Get-Service -Name AppIDSvc"
    try {
        $svc = Get-Service -Name "AppIDSvc" -ErrorAction Stop
        switch ($svc.Status) {
            "Running" { return "running" }
            "Stopped" { return "stopped" }
            default   { return $svc.Status.ToString().ToLower() }
        }
    } catch [Microsoft.PowerShell.Commands.ServiceCommandException] {
        return "not_installed"
    } catch {
        return "unknown"
    }
}

# ---------- AppLocker Policy Query -------------------------------------------

function _Query-AppLockerPolicies {
    $results = [ordered]@{}
    foreach ($regName in $script:RuleCollections.Keys) {
        $friendly = $script:RuleCollections[$regName]
        $keyPath  = "$script:AppLockerBase\$regName"
        Write-Source "[HKLM\$keyPath] :: GetValue('EnforcementMode')"
        try {
            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($keyPath)
            if ($null -eq $key) {
                $results[$friendly] = "not configured"
            } else {
                $val = $key.GetValue("EnforcementMode", $null)
                $key.Close()
                if ($null -eq $val) {
                    $results[$friendly] = "not configured"
                } elseif ($script:EnforcementModes.ContainsKey([int]$val)) {
                    $results[$friendly] = $script:EnforcementModes[[int]$val]
                } else {
                    $results[$friendly] = "unknown (value=$val)"
                }
            }
        } catch {
            $results[$friendly] = "access denied"
        }
    }
    return $results
}

# ---------- WDAC Status Query ------------------------------------------------

function _Query-WDACStatus {
    $keyPath = "SYSTEM\CurrentControlSet\Control\CI\Config"
    Write-Source "[HKLM\$keyPath] :: GetValue('VulnerableDriverBlocklistEnable')"
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($keyPath)
        if ($null -eq $key) {
            return @{ Present = $false }
        }
        $val = $key.GetValue("VulnerableDriverBlocklistEnable", $null)
        $key.Close()
        return @{
            Present         = $true
            DriverBlocklist = ($null -ne $val -and [bool]$val)
        }
    } catch {
        return @{ Present = "access_denied" }
    }
}


# ---------- Main Entry -------------------------------------------------------

function Get-AppLockerState {

    Write-RunningHeader "applocker"

    # -- Query everything first -----------------------------------------------
    $svcStatus  = _Query-AppIDSvc
    $policies   = _Query-AppLockerPolicies
    $wdac       = _Query-WDACStatus

    $svcRunning         = $svcStatus -eq "running"
    $enforcedCollections = @($policies.Keys | Where-Object { $policies[$_] -eq "enforce" })
    $auditCollections    = @($policies.Keys | Where-Object { $policies[$_] -eq "audit only" })

    # Overall risk mirrors Python logic
    if ($enforcedCollections.Count -gt 0 -and $svcRunning -and $wdac.Present -eq $true) {
        $overallRisk = "HIGH"
    } elseif ($enforcedCollections.Count -gt 0 -and $svcRunning) {
        $overallRisk = "MEDIUM"
    } else {
        $overallRisk = "LOW"
    }

    # -- Header ---------------------------------------------------------------
    Write-ModuleHeader "APPLOCKER / WDAC" $overallRisk

    # -- AppIDSvc -------------------------------------------------------------
    $svcRisk = if ($svcRunning) { "HIGH" } else { "LOW" }
    Write-ModuleRow "AppIDSvc" $svcStatus $svcRisk `
        "Rules NOT enforced if stopped, even when policies are configured."

    # -- Rule Collections -----------------------------------------------------
    foreach ($collection in $policies.Keys) {
        $mode = $policies[$collection]
        $colRisk = switch ($mode) {
            "enforce"        { "HIGH"    }
            "audit only"     { "MEDIUM"  }
            "not configured" { "LOW"     }
            default          { "UNKNOWN" }
        }
        Write-ModuleRow $collection $mode $colRisk `
            "audit only means violations are logged but not blocked."
    }

    # -- WDAC -----------------------------------------------------------------
    if ($wdac.Present -eq "access_denied") {
        Write-ModuleRow "WDAC Policy Key" "access denied" "UNKNOWN" ""
    } elseif ($wdac.Present -eq $true) {
        Write-ModuleRow "WDAC Policy Key" "present" "HIGH" `
            "Kernel-level block (CI.dll). Harder to bypass than AppLocker."
        $blValue = if ($wdac.DriverBlocklist) { "enabled" } else { "disabled" }
        $blRisk  = if ($wdac.DriverBlocklist) { "HIGH" } else { "LOW" }
        Write-ModuleRow "Driver Blocklist" $blValue $blRisk `
            "Disabled: $($Global:DR.BYOVD) viable ($($Global:DR.RTCore), $($Global:DR.Gdrv))."
    } else {
        Write-ModuleRow "WDAC Policy Key" "not present" "LOW" ""
    }

    # -- Notes ----------------------------------------------------------------
    Write-ModuleNotes @(
        "AppIDSvc stopped     ->  All AppLocker rules unenforced regardless of policy."
        "Audit mode only      ->  $($Global:DR.Payloads) run but may generate 8003/8004 events."
        "Scripts restricted   ->  Try mshta.exe, wscript.exe, or COM scriptlets (.sct)."
        "DLLs not restricted  ->  Sideload $($Global:DR.MalDLL) via signed host processes."
        "WDAC present         ->  Standard AppLocker bypasses blocked. Focus on CI policy trust levels."
        "No driver blocklist  ->  $($Global:DR.BYOVD) attacks viable (e.g. $($Global:DR.RTCore), $($Global:DR.Gdrv))."
    )

    # -- Feed global results silently -----------------------------------------
    $svcRisk = if ($svcRunning) { "HIGH" } else { "LOW" }
    Add-Result "AppLocker" "AppIDSvc" $svcStatus $svcRisk

    foreach ($collection in $policies.Keys) {
        $mode = $policies[$collection]
        $risk = switch ($mode) {
            "enforce"        { "HIGH"    }
            "audit only"     { "MEDIUM"  }
            "not configured" { "LOW"     }
            default          { "UNKNOWN" }
        }
        Add-Result "AppLocker" "AppLocker - $collection" $mode $risk
    }

    $wdacValue = if ($wdac.Present -eq $true) { "present" } elseif ($wdac.Present -eq $false) { "not present" } else { "access denied" }
    $wdacRisk  = if ($wdac.Present -eq $true) { "HIGH" } else { "LOW" }
    Add-Result "AppLocker" "WDAC Policy Key" $wdacValue $wdacRisk

    if ($wdac.Present -eq $true) {
        $blRisk  = if ($wdac.DriverBlocklist) { "LOW" } else { "HIGH" }
        $blValue = if ($wdac.DriverBlocklist) { "enabled" } else { "disabled" }
        Add-Result "AppLocker" "Vulnerable Driver Blocklist" $blValue $blRisk
    }
}

Register-Module "applocker" "AppLocker enforcement per collection, WDAC policy status" { Get-AppLockerState }
