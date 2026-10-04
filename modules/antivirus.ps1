# ================================
# Module: AV / EDR Detection
# Detects AV/EDR products via WSC (WMI) and running process scan.
# Mirrors: modules/antivirus.py
# ================================

# Known EDR/AV process names mapped to product labels
$script:KnownSecurityProcesses = @{
    "msmpseng.exe"        = "Windows Defender"
    "sentinelagent.exe"   = "SentinelOne"
    "sentinelone.exe"     = "SentinelOne"
    "csagent.exe"         = "CrowdStrike Falcon"
    "csfalconservice.exe" = "CrowdStrike Falcon"
    "cb.exe"              = "Carbon Black"
    "cbsensor.exe"        = "Carbon Black"
    "cylancesvc.exe"      = "Cylance PROTECT"
    "mcshield.exe"        = "McAfee"
    "ekrn.exe"            = "ESET"
    "bdagent.exe"         = "Bitdefender"
    "savservice.exe"      = "Sophos"
    "cyserver.exe"        = "Cybereason"
    "amagent.exe"         = "Trellix (FireEye)"
    "xagt.exe"            = "Trellix (FireEye)"
    "paxentsvc.exe"       = "Palo Alto Cortex XDR"
    "trapsagent.exe"      = "Palo Alto Cortex XDR"
    "wdagentservice.exe"  = "Elastic EDR"
}

# Products known to aggressively block red team tools
$script:HighRiskProducts = @(
    "CrowdStrike Falcon",
    "SentinelOne",
    "Carbon Black",
    "Palo Alto Cortex XDR",
    "Trellix (FireEye)",
    "Cybereason"
)

# ---------- Windows Defender Detection --------------------------------------
# Uses Get-MpComputerStatus (reliable on Win10/11) with WinDefend service fallback.

function _Check-WindowsDefender {
    Write-Source "Get-MpComputerStatus"
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        if ($mp -and $mp.AMServiceEnabled) { return "Windows Defender" }
    } catch {}
    # Fallback: check service directly
    Write-Source "Get-Service WinDefend"
    try {
        $svc = Get-Service -Name "WinDefend" -ErrorAction Stop
        if ($svc.Status -eq "Running") { return "Windows Defender" }
    } catch {}
    return $null
}

# ---------- WSC Query --------------------------------------------------------
# Queries Windows Security Center (root\SecurityCenter2) via WMIC.

function _Query-WSC {
    $products = @()
    try {
        Write-Source "wmic /namespace:\\root\SecurityCenter2 path AntiVirusProduct get displayName,productState /format:list"
        $raw = & wmic /namespace:"\\root\SecurityCenter2" path AntiVirusProduct `
                    get displayName,productState /format:list 2>$null
        $current = @{}
        foreach ($line in $raw) {
            $line = $line.Trim()
            if ($line -match "^(.+?)=(.*)$") {
                $current[$Matches[1].Trim()] = $Matches[2].Trim()
            } elseif ($line -eq "" -and $current.Count -gt 0) {
                $products += $current
                $current = @{}
            }
        }
        if ($current.Count -gt 0) { $products += $current }
    } catch {
        # WSC not available or access denied - silently continue
    }
    return $products
}

# ---------- Process Scan -----------------------------------------------------
# Runs tasklist and checks for known EDR/AV agent process names.

function _Scan-Processes {
    $found = @()
    try {
        Write-Source "tasklist /fo csv /nh"
        $raw = & tasklist /fo csv /nh 2>$null
        $runningLower = ($raw -join "`n").ToLower()
        foreach ($procName in $script:KnownSecurityProcesses.Keys) {
            if ($runningLower -like "*$procName*") {
                $found += $script:KnownSecurityProcesses[$procName]
            }
        }
    } catch {
        # tasklist unavailable - silently continue
    }
    return ($found | Select-Object -Unique)
}

# ---------- Exclusion Paths Query --------------------------------------------
# Reads Defender exclusion paths from the registry.
# These paths are not scanned - dropping payloads here bypasses real-time protection.

function _Query-ExclusionPaths {
    $keyPath = "SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
    Write-Source "[HKLM\$keyPath] :: GetValueNames()"
    $paths = @()
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($keyPath)
        if ($null -eq $key) { return $paths }
        $paths = @($key.GetValueNames() | Where-Object { $_ -ne "" })
        $key.Close()
    } catch {
        # Access denied or key missing - silently continue
    }
    return $paths
}


# ---------- Main Entry -------------------------------------------------------

function Get-AVState {

    Write-RunningHeader "antivirus"

    # -- Query everything first -----------------------------------------------
    $wscProducts = _Query-WSC
    $registered  = @($wscProducts | ForEach-Object {
        if ($_["displayName"]) { $_["displayName"] }
    } | Where-Object { $_ } | Select-Object -Unique)

    $edrHits = @(_Scan-Processes)

    # Dedicated Defender check — WSC/process scan can miss it on Win10/11
    $defenderDetected = _Check-WindowsDefender
    if ($defenderDetected -and ($registered + $edrHits) -notcontains $defenderDetected) {
        $edrHits += $defenderDetected
    }

    $allDetected  = @($registered + $edrHits | Select-Object -Unique)
    $highRisk     = @($allDetected | Where-Object { $script:HighRiskProducts -contains $_ })
    $exclusions   = @(_Query-ExclusionPaths)

    # -- Overall risk mirrors Python ------------------------------------------
    if ($highRisk.Count -gt 0) {
        $overallRisk = "CRITICAL"
    } elseif ($edrHits.Count -gt 0) {
        $overallRisk = "HIGH"
    } elseif ($registered.Count -gt 0) {
        $overallRisk = "MEDIUM"
    } else {
        $overallRisk = "LOW"
    }

    # -- Header ---------------------------------------------------------------
    Write-ModuleHeader "AV / EDR DETECTION" $overallRisk

    # -- 1. WSC Registered Products -------------------------------------------
    if ($registered.Count -eq 0) {
        Write-ModuleRow "WSC Registered Products" "none" "INFO" ""
    } else {
        foreach ($name in $registered) {
            Write-ModuleRow "WSC Registered" $name "INFO" ""
        }
    }

    # -- 2. EDR Process Scan --------------------------------------------------
    if ($edrHits.Count -eq 0) {
        Write-ModuleRow "EDR Processes Detected" "none" "LOW" ""
    } else {
        foreach ($product in $edrHits) {
            Write-ModuleRow "EDR Process Found" $product "HIGH" `
                "Known EDR agent process running."
        }
    }

    # -- 3. High-Risk EDR Products --------------------------------------------
    if ($highRisk.Count -eq 0) {
        Write-ModuleRow "High-Risk EDR" "none" "LOW" ""
    } else {
        foreach ($product in $highRisk) {
            Write-ModuleRow "High-Risk EDR" $product "CRITICAL" `
                "Actively hunts offensive tooling and memory injection."
        }
    }

    # -- 4. Defender Exclusion Paths ------------------------------------------
    if ($exclusions.Count -eq 0) {
        Write-ModuleRow "Exclusion Paths" "none found" "INFO" ""
    } else {
        foreach ($path in $exclusions) {
            Write-ModuleRow "Exclusion Path" $path "CRITICAL" `
                "Files dropped here are NOT scanned. Prime $($Global:DR.Payload) staging location."
        }
    }

    # -- Notes ----------------------------------------------------------------
    Write-ModuleNotes @(
        "Defender only             ->  $($Global:DR.AMSIb) + $($Global:DR.ReflL) likely sufficient."
        "CrowdStrike / SentinelOne ->  Requires injection into trusted process + $($Global:DR.PPIDsp)."
        "No EDR detected           ->  Standard $($Global:DR.C2) without heavy OPSEC may work."
        "Exclusion paths listed    ->  Drop $($Global:DR.Payload) directly there; no evasion needed."
    )

    # -- Feed global results silently -----------------------------------------
    if ($registered.Count -eq 0) {
        Add-Result "Antivirus" "WSC Registered Products" "none" "INFO"
    } else {
        foreach ($name in $registered) { Add-Result "Antivirus" "WSC Registered" $name "INFO" }
    }

    if ($edrHits.Count -eq 0) {
        Add-Result "Antivirus" "EDR Processes Detected" "none" "LOW"
    } else {
        foreach ($product in $edrHits) { Add-Result "Antivirus" "EDR Process Found" $product "HIGH" }
    }

    if ($highRisk.Count -eq 0) {
        Add-Result "Antivirus" "High-Risk EDR Products" "none" "LOW"
    } else {
        foreach ($product in $highRisk) { Add-Result "Antivirus" "High-Risk EDR" $product "CRITICAL" }
    }

    if ($exclusions.Count -eq 0) {
        Add-Result "Antivirus" "Exclusion Paths" "none found" "INFO"
    } else {
        foreach ($path in $exclusions) { Add-Result "Antivirus" "Exclusion Path" $path "CRITICAL" }
    }
}

Register-Module "antivirus" "Installed AV/EDR products via WMI and process scanning" { Get-AVState }
