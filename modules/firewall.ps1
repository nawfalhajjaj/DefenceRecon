# ================================
# Module: Firewall Configuration
# Reads Firewall profile states (domain/private/public), default
# inbound/outbound actions, and total rule counts via registry + netsh.
# Mirrors: modules/firewall.py
# ================================

$script:FWBase = "SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy"

# Registry subkey -> friendly name (ordered for consistent output)
$script:Profiles = [ordered]@{
    "DomainProfile"   = "Domain"
    "StandardProfile" = "Private"
    "PublicProfile"   = "Public"
}

# ---------- Registry helper --------------------------------------------------

function _Read-FWReg {
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

# ---------- Rule count via netsh ---------------------------------------------
# Parses 'netsh advfirewall firewall show rule name=all' and counts
# enabled inbound/outbound rules - mirrors _count_rules() in the Python.

function _Count-FirewallRules {
    Write-Source "netsh advfirewall firewall show rule name=all"
    try {
        [string[]]$lines = & netsh advfirewall firewall show rule name=all 2>$null
        $inbound  = 0
        $outbound = 0
        $direction = $null
        foreach ($line in $lines) {
            $l = $line.Trim().ToLower()
            if ($l -like "direction:*") {
                $direction = ($l -split ":", 2)[1].Trim()
            }
            if ($l -like "enabled:*" -and $l -like "*yes*") {
                if ($direction -eq "in")  { $inbound++  }
                if ($direction -eq "out") { $outbound++ }
            }
        }
        return @{ Inbound = $inbound; Outbound = $outbound }
    } catch {
        return @{ Inbound = 0; Outbound = 0 }
    }
}



# ---------- Main Entry -------------------------------------------------------

function Get-FirewallState {

    Write-RunningHeader "firewall"

    # -- Query all profiles from registry -------------------------------------
    $profileRows = @()
    $anyDisabled = $false

    foreach ($regName in $script:Profiles.Keys) {
        $friendly = $script:Profiles[$regName]
        $keyPath  = "$script:FWBase\$regName"

        $enabledVal  = _Read-FWReg $keyPath "EnableFirewall"
        $inboundVal  = _Read-FWReg $keyPath "DefaultInboundAction"
        $outboundVal = _Read-FWReg $keyPath "DefaultOutboundAction"

        # Enabled state
        if ($null -eq $enabledVal) {
            $enabledStr  = "unknown"
            $enabledRisk = "UNKNOWN"
        } elseif ([bool]$enabledVal) {
            $enabledStr  = "enabled"
            $enabledRisk = "LOW"
        } else {
            $enabledStr  = "disabled"
            $enabledRisk = "CRITICAL"
            $anyDisabled = $true
        }

        # Inbound default action: 0=allow, 1=block
        $inStr = if ($null -eq $inboundVal) { "unknown" } elseif ($inboundVal -eq 1) { "block" } else { "allow" }
        $inRisk = switch ($inStr) { "block" { "LOW" } "allow" { "HIGH" } default { "UNKNOWN" } }

        # Outbound default action: 0=allow, 1=block
        $outStr = if ($null -eq $outboundVal) { "unknown" } elseif ($outboundVal -eq 1) { "block" } else { "allow" }

        $profileRows += [PSCustomObject]@{
            Friendly    = $friendly
            EnabledStr  = $enabledStr
            EnabledRisk = $enabledRisk
            InStr       = $inStr
            InRisk      = $inRisk
            OutStr      = $outStr
        }
    }

    # -- Rule counts ----------------------------------------------------------
    $ruleCounts = _Count-FirewallRules

    # -- Overall risk ---------------------------------------------------------
    $overallRisk = if ($anyDisabled) { "CRITICAL" } else { "LOW" }

    # -- Header ---------------------------------------------------------------
    Write-ModuleHeader "FIREWALL CONFIGURATION" $overallRisk

    # -- Profile rows ---------------------------------------------------------
    foreach ($p in $profileRows) {
        Write-ModuleRow "$($p.Friendly) Profile"          $p.EnabledStr $p.EnabledRisk `
            "Firewall is $($p.EnabledStr) for the $($p.Friendly) profile."
        Write-ModuleRow "$($p.Friendly) Default Inbound"  $p.InStr      $p.InRisk `
            "Default action for unsolicited inbound traffic."
        Write-ModuleRow "$($p.Friendly) Default Outbound" $p.OutStr     "INFO" ""
    }

    # -- Rule counts ----------------------------------------------------------
    Write-ModuleRow "Enabled Inbound Rules"  "$($ruleCounts.Inbound)"  "INFO" ""
    Write-ModuleRow "Enabled Outbound Rules" "$($ruleCounts.Outbound)" "INFO" ""

    # -- Notes ----------------------------------------------------------------
    Write-ModuleNotes @(
        "Profile disabled         ->  Direct network access without host-based filtering."
        "Inbound allow (default)  ->  Enumerate listening services for direct exploitation."
        "Outbound unrestricted    ->  $($Global:DR.C2) egress via HTTP/HTTPS beaconing likely works."
        "High rule counts         ->  Check for any/any rules: netsh advfirewall firewall show rule name=all"
        "Firewall log             ->  %systemroot%\system32\LogFiles\Firewall\pfirewall.log"
    )

    # -- Feed global results silently -----------------------------------------
    foreach ($p in $profileRows) {
        Add-Result "Firewall" "$($p.Friendly) Profile"          $p.EnabledStr $p.EnabledRisk
        Add-Result "Firewall" "$($p.Friendly) Default Inbound"  $p.InStr      $p.InRisk
        Add-Result "Firewall" "$($p.Friendly) Default Outbound" $p.OutStr     "INFO"
    }
    Add-Result "Firewall" "Enabled Inbound Rules"  $ruleCounts.Inbound  "INFO"
    Add-Result "Firewall" "Enabled Outbound Rules" $ruleCounts.Outbound "INFO"
}

Register-Module "firewall" "Firewall profiles, default inbound/outbound actions, rule counts" { Get-FirewallState }
