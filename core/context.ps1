function Show-SystemContext {

    $hostname = $env:COMPUTERNAME
    $user     = $env:USERNAME

    $cs = Get-CimInstance Win32_ComputerSystem
    $domain = if ($cs.PartOfDomain) { $cs.Domain } else { "WORKGROUP" }

    $os = (Get-CimInstance Win32_OperatingSystem).Version

    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $priv = if ($isAdmin) { "Administrator" } else { "Standard User" }

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-Host ""
    Write-Host "  [+] SYSTEM CONTEXT" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "    Hostname     $hostname"
    Write-Host "    User         $user"
    Write-Host "    Domain       $domain"
    Write-Host "    OS           $os"
    Write-Host "    Privileges   $priv"
    Write-Host "    Timestamp    $time"

    if (-not $isAdmin) {
        Write-Host ""
        Write-Host "    [!] Not running as Administrator" -ForegroundColor Yellow
        Write-Host "    [!] Some results may be limited" -ForegroundColor Yellow
    }    
}