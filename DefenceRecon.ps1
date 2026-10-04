# ================================
# DefenceRecon - Entry Point
# ================================

Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------- Import Core ----------
. "$PSScriptRoot\core\output.ps1"
. "$PSScriptRoot\core\registry.ps1"
. "$PSScriptRoot\core\strings.ps1"

# ---------- Import Modules ----------
# Auto-discover: any .ps1 dropped in modules\ is loaded and self-registers via Register-Module
Get-ChildItem "$PSScriptRoot\modules\*.ps1" | Sort-Object Name | ForEach-Object { . $_.FullName }

# ---------- Import Context ----------
. "$PSScriptRoot\core\context.ps1"

# ---------- Import CLI ----------
. "$PSScriptRoot\core\cli.ps1"

# ---------- Start ----------
Clear-Host
Show-Banner
Show-SystemContext

Write-Host ""
Write-Host "  Welcome to DefenceRecon. Type 'help' for available commands." -ForegroundColor DarkGray
Write-Host ""

Start-CLI
