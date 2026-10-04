# ================================
# Module: Security-Related Services
# Queries the status of security-critical Windows services including
# AV, logging, firewall, EDR, and credential protection.
# Mirrors: modules/services.py
# ================================

# Ordered list - hashtables have no guaranteed order
$script:ServiceOrder = @(
    "WinDefend", "Sense", "WdNisSvc", "wscsvc",
    "EventLog", "wecsvc", "Sysmon", "Sysmon64",
    "AppIDSvc", "MpsSvc", "VaultSvc", "NgcSvc",
    "IKEEXT", "PolicyAgent",
    "CSFalconService", "SentinelAgent", "CylanceSvc", "ekrn", "SAVService"
)

# Service name -> [Description, Importance]
$script:SecurityServices = @{
    "WinDefend"       = @("Windows Defender Antivirus",            "CRITICAL")
    "Sense"           = @("Microsoft Defender for Endpoint (MDE)", "CRITICAL")
    "WdNisSvc"        = @("Windows Defender Network Inspection",   "MEDIUM")
    "wscsvc"          = @("Windows Security Center",               "MEDIUM")
    "EventLog"        = @("Windows Event Log",                     "HIGH")
    "wecsvc"          = @("Windows Event Collector",               "MEDIUM")
    "Sysmon"          = @("Sysinternals Sysmon (32-bit)",          "HIGH")
    "Sysmon64"        = @("Sysinternals Sysmon (64-bit)",          "HIGH")
    "AppIDSvc"        = @("Application Identity (AppLocker)",      "HIGH")
    "MpsSvc"          = @("Windows Firewall",                      "HIGH")
    "VaultSvc"        = @("Credential Manager",                    "MEDIUM")
    "NgcSvc"          = @("Microsoft Passport / Windows Hello",    "LOW")
    "IKEEXT"          = @("IKE/AuthIP IPSec Keying",               "MEDIUM")
    "PolicyAgent"     = @("IPSec Policy Agent",                    "MEDIUM")
    "CSFalconService" = @("CrowdStrike Falcon",                    "CRITICAL")
    "SentinelAgent"   = @("SentinelOne Agent",                     "CRITICAL")
    "CylanceSvc"      = @("Cylance PROTECT",                       "CRITICAL")
    "ekrn"            = @("ESET Kernel Service",                   "CRITICAL")
    "SAVService"      = @("Sophos Anti-Virus",                     "CRITICAL")
}

# Stopped state = favorable for attacker (EDR/AV/logging gone)
$script:FavorableStopped = @(
    "WinDefend", "WdNisSvc", "MpsSvc",
    "Sense", "wecsvc", "Sysmon", "Sysmon64", "AppIDSvc",
    "CSFalconService", "SentinelAgent", "CylanceSvc", "ekrn", "SAVService"
)

# ---------- Service Query ----------------------------------------------------

function _Query-Service {
    param([string]$Name)
    Write-Source "Get-Service -Name $Name"
    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
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

# ---------- Risk helpers -----------------------------------------------------

function _Get-SvcRisk {
    param([string]$SvcName, [string]$Status)
    $favorable = $script:FavorableStopped -contains $SvcName
    if ($Status -eq "running") {
        if ($favorable) { return "HIGH" } else { return "LOW" }
    }
    if ($Status -eq "stopped") {
        if ($favorable) { return "LOW" } else { return "HIGH" }
    }
    return "UNKNOWN"
}

function _Get-OverallRisk {
    param($Rows)
    if ($Rows | Where-Object { $_.Risk -eq "CRITICAL" }) { return "CRITICAL" }
    if ($Rows | Where-Object { $_.Risk -eq "HIGH"     }) { return "HIGH" }
    if ($Rows | Where-Object { $_.Risk -eq "MEDIUM"   }) { return "MEDIUM" }
    return "LOW"
}



# ---------- Main Entry -------------------------------------------------------

function Get-ServiceState {

    Write-RunningHeader "services"

    $rows = @()

    foreach ($svcName in $script:ServiceOrder) {
        $desc       = $script:SecurityServices[$svcName][0]
        $importance = $script:SecurityServices[$svcName][1]
        $status     = _Query-Service $svcName

        if ($status -eq "not_installed") { continue }

        $risk = _Get-SvcRisk $svcName $status

        $rows += [PSCustomObject]@{
            Name       = $svcName
            Desc       = $desc
            Importance = $importance
            Status     = $status
            Risk       = $risk
        }
    }

    $overallRisk = _Get-OverallRisk $rows

    # -- Header ---------------------------------------------------------------
    Write-ModuleHeader "SECURITY-RELATED SERVICES" $overallRisk

    # -- Rows -----------------------------------------------------------------
    foreach ($r in $rows) {
        Write-ModuleRow $r.Name $r.Status $r.Risk ""
    }

    Write-ModuleRow "Total Services Found" "$($rows.Count)" "INFO" ""

    # -- Notes ----------------------------------------------------------------
    Write-ModuleNotes @(
        "Sysmon not installed  ->  No process/network event logging. Operate freely."
        "wecsvc stopped        ->  Events not forwarded to SIEM; logs remain local only."
        "EventLog stopped      ->  No event logging at all (rare, but loud in IR)."
        "AppIDSvc stopped      ->  AppLocker rules exist but are NOT enforced."
        "EDR service stopped   ->  Verify tamper protection is off before assuming safe."
        "Sense running         ->  MDE telemetry active; cloud-based detections in play."
    )

    # -- Feed global results silently -----------------------------------------
    foreach ($r in $rows) { Add-Result "Services" "$($r.Name) ($($r.Desc))" $r.Status $r.Risk }
    Add-Result "Services" "Total Services Found" $rows.Count "INFO"
}

Register-Module "services" "Status of security-critical Windows services" { Get-ServiceState }
