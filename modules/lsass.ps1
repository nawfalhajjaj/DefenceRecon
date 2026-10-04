# ================================
# Module: LSASS Protections
# Checks RunAsPPL, Credential Guard, WDigest, LM compatibility,
# and LSA hardening settings - the key barriers to credential dumping.
# Mirrors: modules/lsass.py
# ================================

$script:LSAKey      = "SYSTEM\CurrentControlSet\Control\Lsa"
$script:DevGuardKey = "SYSTEM\CurrentControlSet\Control\DeviceGuard"

$script:PPLMeanings = @{
    0 = "disabled"
    1 = "PPL enabled"
    2 = "PPL + UEFI lock"
}

$script:CGMeanings = @{
    0 = "disabled"
    1 = "enabled (no UEFI lock)"
    2 = "enabled + UEFI lock"
}

$script:LMMeanings = @{
    0 = "LM + NTLM (very weak)"
    1 = "LM + NTLM, NTLMv2 if negotiated"
    2 = "NTLM only"
    3 = "NTLMv2 only"
    4 = "NTLMv2 only, refuse LM from servers"
    5 = "NTLMv2 only, refuse LM+NTLM from servers (strongest)"
}

# ---------- Registry helper --------------------------------------------------

function _Read-LSAReg {
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



# ---------- Main Entry -------------------------------------------------------

function Get-CredentialState {

    Write-RunningHeader "lsass"

    # -- Query all values first -----------------------------------------------
    $ppl          = _Read-LSAReg $script:LSAKey      "RunAsPPL"
    $vbs          = _Read-LSAReg $script:DevGuardKey "EnableVirtualizationBasedSecurity"
    $cfg          = _Read-LSAReg $script:DevGuardKey "LsaCfgFlags"
    $wdigest      = _Read-LSAReg $script:LSAKey      "UseLogonCredential"
    $restrictAnon = _Read-LSAReg $script:LSAKey      "RestrictAnonymous"
    $lmCompat     = _Read-LSAReg $script:LSAKey      "LmCompatibilityLevel"
    $noLMHash     = _Read-LSAReg $script:LSAKey      "NoLMHash"

    # -- Derive states --------------------------------------------------------
    $pplEnabled = ($null -ne $ppl) -and ($ppl -in @(1, 2))
    $cgEnabled  = ($null -ne $cfg) -and ($cfg -in @(1, 2))
    $wdigestOn  = ($null -ne $wdigest) -and [bool]$wdigest  # absent = off by default on Win8+

    # -- Build result rows ----------------------------------------------------
    $rows = @()

    # 1. RunAsPPL
    $pplLabel = if ($null -eq $ppl) { "unknown" } `
        elseif ($script:PPLMeanings.ContainsKey([int]$ppl)) { $script:PPLMeanings[[int]$ppl] } `
        else { "unknown (value=$ppl)" }
    $pplRisk = if ($pplEnabled) { "LOW" } elseif ($ppl -eq 0) { "CRITICAL" } else { "UNKNOWN" }
    $rows += [PSCustomObject]@{ Label = "RunAsPPL"; Value = $pplLabel; Risk = $pplRisk
        Detail = "PPL prevents non-PPL processes from opening LSASS with PROCESS_VM_READ. Blocks most $($Global:DR.Mkatz) variants." }

    # 2. Virtualization-Based Security
    $vbsValue = if ($null -eq $vbs) { "unknown" } elseif ([bool]$vbs) { "True" } else { "False" }
    $vbsRisk  = if ($null -eq $vbs) { "UNKNOWN" } elseif ([bool]$vbs) { "LOW" } else { "MEDIUM" }
    $rows += [PSCustomObject]@{ Label = "VBS Enabled"; Value = $vbsValue; Risk = $vbsRisk
        Detail = "VBS is required for Credential Guard. Isolates credential storage in a hypervisor enclave." }

    # 3. Credential Guard (LsaCfgFlags)
    $cgLabel = if ($null -eq $cfg) { "unknown" } `
        elseif ($script:CGMeanings.ContainsKey([int]$cfg)) { $script:CGMeanings[[int]$cfg] } `
        else { "unknown (value=$cfg)" }
    $cgRisk = if ($cgEnabled) { "LOW" } elseif ($cfg -eq 0) { "CRITICAL" } else { "UNKNOWN" }
    $rows += [PSCustomObject]@{ Label = "Credential Guard"; Value = $cgLabel; Risk = $cgRisk
        Detail = "When enabled, NTLM hashes and Kerberos tickets are in an isolated enclave - dumping returns encrypted blobs." }

    # 4. WDigest (UseLogonCredential=1 = BAD - cleartext in memory)
    $wdigestValue = if ($wdigestOn) { "enabled" } else { "disabled" }
    $wdigestRisk  = if ($wdigestOn) { "CRITICAL" } else { "LOW" }
    $rows += [PSCustomObject]@{ Label = "WDigest Cleartext Creds"; Value = $wdigestValue; Risk = $wdigestRisk
        Detail = "WDigest=1 stores cleartext passwords in LSASS memory. Direct $($Global:DR.Mkatz) $($Global:DR.SekWD) dump possible." }

    # 5. RestrictAnonymous
    $anonValue = if ($null -eq $restrictAnon) { "False" } elseif ([bool]$restrictAnon) { "True" } else { "False" }
    $anonRisk  = if ($null -ne $restrictAnon -and [bool]$restrictAnon) { "LOW" } else { "MEDIUM" }
    $rows += [PSCustomObject]@{ Label = "Restrict Anonymous"; Value = $anonValue; Risk = $anonRisk
        Detail = "Allows null sessions and anonymous share/user enumeration." }

    # 6. LM Compatibility Level
    $lmValue = if ($null -eq $lmCompat) { "unknown" } `
        elseif ($script:LMMeanings.ContainsKey([int]$lmCompat)) { $script:LMMeanings[[int]$lmCompat] } `
        else { "unknown (value=$lmCompat)" }
    $lmRisk = if ($null -eq $lmCompat) { "UNKNOWN" } `
        elseif ($lmCompat -in @(0, 1)) { "CRITICAL" } `
        elseif ($lmCompat -eq 2)       { "MEDIUM" } `
        else                           { "LOW" }
    $rows += [PSCustomObject]@{ Label = "LM Compatibility Level"; Value = $lmValue; Risk = $lmRisk
        Detail = "Low values enable LM/NTLM relay and cracking attacks. Level 5 is recommended." }

    # 7. NoLMHash
    $noLMValue = if ($null -eq $noLMHash) { "unknown" } elseif ([bool]$noLMHash) { "True" } else { "False" }
    $noLMRisk  = if ($null -ne $noLMHash -and [bool]$noLMHash) { "LOW" } else { "MEDIUM" }
    $rows += [PSCustomObject]@{ Label = "LM Hash Storage Disabled"; Value = $noLMValue; Risk = $noLMRisk
        Detail = "If LM hashes are stored, they can be cracked instantly (no salting, max 7 chars)." }

    # -- Overall risk: mirrors Python exactly ---------------------------------
    $hasCritical = $rows | Where-Object { $_.Risk -eq "CRITICAL" }
    $hasWarning  = $rows | Where-Object { $_.Risk -in @("MEDIUM", "HIGH") }

    $overallRisk = if ($hasCritical) { "CRITICAL" } `
        elseif (-not $pplEnabled -and -not $cgEnabled) { "HIGH" } `
        elseif ($hasWarning) { "MEDIUM" } `
        else { "LOW" }

    # -- Header ---------------------------------------------------------------
    Write-ModuleHeader "LSASS PROTECTIONS" $overallRisk

    # -- Rows -----------------------------------------------------------------
    foreach ($r in $rows) {
        Write-ModuleRow $r.Label $r.Value $r.Risk $r.Detail
    }

    # -- Notes ----------------------------------------------------------------
    Write-ModuleNotes @(
        "WDigest enabled          ->  $($Global:DR.Mkatz) $($Global:DR.SekWD) for cleartext passwords."
        "No PPL + no CredGuard    ->  $($Global:DR.SekLP) will work."
        "PPL enabled              ->  $($Global:DR.PPLd), $($Global:DR.PPLk), or $($Global:DR.BYOVD) driver to remove PPL first."
        "Credential Guard enabled ->  Dump returns encrypted blobs. Target DPAPI, browser creds, or vault."
        "LM compat < 3            ->  Relay attacks viable ($($Global:DR.Resp) + $($Global:DR.NTLMRx) -> SMB/LDAP)."
        "RestrictAnonymous=0      ->  Null session: net use \\target\IPC$ without credentials."
    )

    # -- Feed global results silently -----------------------------------------
    foreach ($r in $rows) { Add-Result "LSASS" $r.Label $r.Value $r.Risk }
}

Register-Module "lsass" "RunAsPPL, Credential Guard, WDigest, LM compat, null sessions" { Get-CredentialState }
