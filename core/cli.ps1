# ================================
# DefenceRecon CLI v1.0
# ================================

$script:Version = "1.0"
$script:History = [System.Collections.Generic.List[string]]::new()

# ─── Banner ───────────────────────────────────────────────────────────────────

function Show-Banner {
    Write-Host ""
    Write-Host "██████╗ ███████╗███████╗██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗"
    Write-Host "██╔══██╗██╔════╝██╔════╝██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║"
    Write-Host "██║  ██║█████╗  █████╗  ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║"
    Write-Host "██║  ██║██╔══╝  ██╔══╝  ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║"
    Write-Host "██████╔╝███████╗██║     ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║"
    Write-Host "╚═════╝ ╚══════╝╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝"
    Write-Host " ▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Author  : Nawfal Hajjaj" -ForegroundColor DarkGray
    Write-Host "Version : 1.0" -ForegroundColor DarkGray
    Write-Host ""
}

# ─── Help ─────────────────────────────────────────────────────────────────────

$script:HelpDetails = @{
    "help"    = "  help [command]`n  Show the command list, or detailed info for a specific command.`n  Examples:`n    help`n    help run`n    help export"
    "run"     = "  run <module|all_modules>`n  Execute one or more enumeration modules.`n    defender / firewall : individual modules`n    all_modules        : run every module`n  Examples:`n    run defender`n    run firewall`n    run all_modules"
    "show"    = "  show modules`n  List all registered modules.`n  Example:`n    show modules"
    "export"  = "  export <json|html|pdf>`n  Save current results to a file.`n  Examples:`n    export json`n    export html`n    export pdf"
    "history" = "  history  (alias: hist)`n  Show commands entered this session.`n  Example:`n    history"
    "context" = "  context  (alias: ctx)`n  Re-display system context.`n  Example:`n    context"
    "clear"   = "  clear  (alias: cls)`n  Clear the screen.`n  Example:`n    clear"
    "version" = "  version`n  Show DefenceRecon version.`n  Example:`n    version"
    "exit"    = "  exit  (alias: quit)`n  Exit DefenceRecon.`n  Example:`n    exit"
    "verbose" = "  verbose <true|false>`n  Toggle verbose mode. When true, each check prints the exact registry`n  key path or cmdlet used to retrieve its value.`n  Examples:`n    verbose true`n    verbose false"
    "banner"  = "  banner`n  Re-display the DefenceRecon ASCII banner.`n  Example:`n    banner"
}

function Show-Help {
    param([string]$Cmd = "")

    if ($Cmd -ne "") {
        if ($script:HelpDetails.ContainsKey($Cmd)) {
            Write-Host ""
            Write-Host $script:HelpDetails[$Cmd]
            Write-Host ""
        } else {
            Write-Host "[!] No help entry for '$Cmd'" -ForegroundColor Yellow
        }
        return
    }

    Write-Host "Available Commands:"
    Write-Host ""

    $rows = @(
        "  help [command]",                      "(?)"
        "  run <module|all_modules>",             ""
        "  show modules",                        ""
        "  export <json|html|pdf>",               ""
        "  history",                             "(hist)"
        "  context",                             "(ctx)"
        "  clear",                               "(cls)"
        "  version",                             ""
        "  verbose <true|false>",                ""
        "  banner",                              ""
        "  exit",                                "(quit)"
    )

    for ($i = 0; $i -lt $rows.Count; $i += 2) {
        $left  = $rows[$i].PadRight(42)
        $right = $rows[$i+1]
        Write-Host -NoNewline $left
        if ($right) { Write-Host $right -ForegroundColor DarkGray }
        else        { Write-Host "" }
    }

    Write-Host ""
    Write-Host "  Type 'help <command>' for details and examples." -ForegroundColor DarkGray
    Write-Host ""
}

# ─── Module execution ─────────────────────────────────────────────────────────

function Run-Module([string]$name) {
    if ($Global:Modules.ContainsKey($name)) {
        & $Global:Modules[$name]
    } else {
        Write-Host "[!] Module not found: $name" -ForegroundColor Yellow
    }
}

function Run-All {
    foreach ($m in $Global:Modules.Keys) {
        if ($script:Interrupted) {
            Write-Host "  [!] Scan interrupted." -ForegroundColor Yellow
            Write-Host ""
            return
        }
        & $Global:Modules[$m]
    }
}

# ─── show modules ─────────────────────────────────────────────────────────────

# Ordered display list for 'show modules'.
# Each entry: Name, one-line summary, optional tag (e.g. "plugin")
# Add new modules here in the order you want them displayed.
$script:ModuleDisplay = @($Global:ModuleMeta) + @(
    [PSCustomObject]@{ Name = "all_modules"; Summary = "Run all modules at once"; Tag = "" }
)

function Show-Modules {
    Write-Host "Available Modules:"
    Write-Host ""

    # Calculate the longest name so all dashes line up
    $maxLen = ($script:ModuleDisplay | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
    foreach ($entry in $script:ModuleDisplay) {
        $tag     = if ($entry.Tag -ne "") { " [$($entry.Tag)]" } else { "" }
        $namePad = $entry.Name.PadRight($maxLen)

        Write-Host -NoNewline "  $namePad  -  "
        Write-Host -NoNewline $entry.Summary

        if ($tag -ne "") {
            Write-Host $tag -ForegroundColor DarkGray
        } else {
            Write-Host ""
        }
    }

    # Catch any registered modules not in the display list (runtime-loaded plugins)
    foreach ($key in $Global:Modules.Keys) {
        $known = $script:ModuleDisplay | Where-Object { $_.Name -eq $key }
        if (-not $known) {
            $namePad = $key.PadRight($maxLen)
            Write-Host -NoNewline "  $namePad  -  (no description)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

# ─── export ───────────────────────────────────────────────────────────────────

function _Build-HTMLReport {
    $rows = $Global:Results | ForEach-Object {
        $c = switch ($_.Risk) {
            "CRITICAL" {"#ff4c4c"} "HIGH" {"#ff4c4c"} "MEDIUM" {"#ffa500"}
            "LOW"      {"#4caf50"} default {"#888"}
        }
        "<tr><td>$($_.Module)</td><td>$($_.Name)</td><td>$($_.Value)</td><td style='color:$c;font-weight:bold'>$($_.Risk)</td></tr>"
    }
    return @"
<!DOCTYPE html><html><head><meta charset='UTF-8'><title>DefenceRecon</title>
<style>
  body{font-family:monospace;background:#1e1e1e;color:#d4d4d4;padding:20px}
  h2{color:#ccc;margin-bottom:4px}
  p{color:#666;font-size:12px;margin-top:0}
  table{border-collapse:collapse;width:100%}
  th{background:#2a2a2a;color:#aaa;padding:8px;text-align:left;font-weight:normal}
  td{padding:6px 8px;border-bottom:1px solid #2a2a2a}
  tr:hover{background:#222}
</style></head><body>
<h2>DefenceRecon Report</h2>
<p>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &mdash; $($Global:Results.Count) findings</p>
<table><tr><th>Module</th><th>Check</th><th>Value</th><th>Risk</th></tr>
$($rows -join "`n")</table></body></html>
"@
}

function Export-Results([string]$format) {
    if ($Global:Results.Count -eq 0) {
        Write-Host "[!] No results to export. Run a module first." -ForegroundColor Yellow
        return
    }

    $stamp     = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputDir = Join-Path (Split-Path $PSScriptRoot -Parent) "output"
    if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }
    $file      = Join-Path $outputDir "DefenceRecon_$stamp.$format"

    switch ($format) {
        "json" {
            $Global:Results | ConvertTo-Json -Depth 5 | Out-File $file -Encoding UTF8
            Write-Host "[+] Exported to $file" -ForegroundColor Green
        }
        "html" {
            _Build-HTMLReport | Out-File $file -Encoding UTF8
            Write-Host "[+] Exported to $file" -ForegroundColor Green
        }
        "pdf" {
            # Generate HTML to a temp file, then print to PDF via Microsoft Edge.
            # Use a dedicated temporary Edge profile so this also works when
            # DefenceRecon itself is running elevated.
            $tmpHtml = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "DefenceRecon_$stamp.html")
            _Build-HTMLReport | Out-File $tmpHtml -Encoding UTF8

            # Edge can be installed machine-wide or per-user.
            $edgeCandidates = @(
                "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
                "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
                "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
                "$env:USERPROFILE\AppData\Local\Microsoft\Edge\Application\msedge.exe"
            ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

            $edge = $edgeCandidates | Select-Object -First 1

            if (-not $edge) {
                Remove-Item $tmpHtml -Force -ErrorAction SilentlyContinue
                Write-Host "[!] PDF export requires Microsoft Edge — not found." -ForegroundColor Yellow
                return
            }

            $edgeProfile = [System.IO.Path]::Combine(
                [System.IO.Path]::GetTempPath(),
                "DefenceRecon_EdgeProfile_$stamp"
            )
            New-Item -ItemType Directory -Path $edgeProfile -Force -ErrorAction Stop | Out-Null

            $edgeStdOut = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "DefenceRecon_$stamp.edge.stdout.log")
            $edgeStdErr = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "DefenceRecon_$stamp.edge.stderr.log")

            # Use a file:// URI with forward slashes. Quote every path because
            # Windows paths may contain spaces.
            $htmlUri = "file:///" + (($tmpHtml -replace '\\','/') -replace ' ','%20')
            $pdfPath = $file

            $edgeArguments = @(
                '--headless'
                '--disable-gpu'
                '--no-first-run'
                '--no-default-browser-check'
                '--disable-extensions'
                '--disable-background-networking'
                '--disable-sync'
                "--user-data-dir=`"$edgeProfile`""
                "--print-to-pdf=`"$pdfPath`""
                "`"$htmlUri`""
            ) -join ' '

            $edgeProcess = $null

            try {
                # Use System.Diagnostics.Process instead of Start-Process.
                # This gives us a reliable ExitCode and works consistently when
                # PowerShell is elevated.
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $edge
                $psi.Arguments = $edgeArguments
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true

                $edgeProcess = New-Object System.Diagnostics.Process
                $edgeProcess.StartInfo = $psi

                if (-not $edgeProcess.Start()) {
                    throw "Windows could not start Microsoft Edge."
                }

                # Read both redirected streams asynchronously so Edge cannot
                # block because one of its output buffers becomes full.
                $stdoutTask = $edgeProcess.StandardOutput.ReadToEndAsync()
                $stderrTask = $edgeProcess.StandardError.ReadToEndAsync()

                $spinChars = '|','/','-','\'
                $spinIdx   = 0
                while (-not $edgeProcess.HasExited) {
                    Write-Host "`r  [~] Generating PDF... $($spinChars[$spinIdx % 4])" -NoNewline -ForegroundColor DarkGray
                    $spinIdx++
                    Start-Sleep -Milliseconds 120
                }

                # Edge can exit before the PDF is fully committed to disk. Keep
                # the same lightweight spinner visible for the entire operation,
                # including that final file-write window, so elevated execution
                # does not appear to freeze.
                $pdfReady = $false
                $deadline = (Get-Date).AddSeconds(5)
                while ((Get-Date) -lt $deadline) {
                    if (Test-Path -LiteralPath $file) {
                        try {
                            $pdfItem = Get-Item -LiteralPath $file -ErrorAction Stop
                            if ($pdfItem.Length -gt 0) {
                                $pdfReady = $true
                                break
                            }
                        } catch {}
                    }

                    if ($edgeProcess.HasExited) {
                        # Once Edge has exited, continue polling briefly for the
                        # PDF while still showing progress.
                        Start-Sleep -Milliseconds 100
                    }
                    else {
                        Start-Sleep -Milliseconds 120
                    }

                    Write-Host "`r  [~] Generating PDF... $($spinChars[$spinIdx % 4])" -NoNewline -ForegroundColor DarkGray
                    $spinIdx++
                }

                if ($edgeProcess.HasExited) {
                    $stdout = $stdoutTask.GetAwaiter().GetResult()
                    $stderr = $stderrTask.GetAwaiter().GetResult()
                    $exitCode = $edgeProcess.ExitCode
                }
                else {
                    $edgeProcess.WaitForExit()
                    $stdout = $stdoutTask.GetAwaiter().GetResult()
                    $stderr = $stderrTask.GetAwaiter().GetResult()
                    $exitCode = $edgeProcess.ExitCode
                }

                if ($stdout) { Set-Content -LiteralPath $edgeStdOut -Value $stdout -Encoding UTF8 }
                if ($stderr) { Set-Content -LiteralPath $edgeStdErr -Value $stderr -Encoding UTF8 }

                if ($pdfReady) {
                    Write-Host "`r  [~] Generating PDF... done  " -ForegroundColor DarkGray
                    Write-Host "[+] Exported to $file" -ForegroundColor Green
                }
                else {
                    $cleanError = if ($stderr) { $stderr.Trim() } else { "" }
                    Write-Host "[!] PDF generation failed (Edge exit code $exitCode)." -ForegroundColor Yellow
                    if ($cleanError) {
                        Write-Host "    $cleanError" -ForegroundColor Yellow
                    }
                    Write-Host "    Edge: $edge" -ForegroundColor DarkGray
                    Write-Host "    HTML: $tmpHtml" -ForegroundColor DarkGray
                    Write-Host "    PDF:  $file" -ForegroundColor DarkGray
                }
            }
            catch {
                Write-Host "`r  [~] Generating PDF... failed" -ForegroundColor DarkGray
                Write-Host "[!] PDF generation error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            finally {
                if ($edgeProcess) {
                    try { if (-not $edgeProcess.HasExited) { $edgeProcess.Kill() } } catch {}
                    try { $edgeProcess.Dispose() } catch {}
                }
                Remove-Item $tmpHtml -Force -ErrorAction SilentlyContinue
                Remove-Item $edgeStdOut, $edgeStdErr -Force -ErrorAction SilentlyContinue
                Remove-Item $edgeProfile -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        default {
            Write-Host "[!] Unknown format: $format  (use json, html, pdf)" -ForegroundColor Yellow
            return
        }
    }
}


# ─── history ──────────────────────────────────────────────────────────────────

function Show-History {
    if ($script:History.Count -eq 0) {
        Write-Host "  (no history yet)" -ForegroundColor DarkGray
        return
    }
    Write-Host ""
    $i = 1
    foreach ($entry in $script:History) {
        Write-Host ("  {0,3}  {1}" -f $i, $entry) -ForegroundColor White
        $i++
    }
    Write-Host ""
}

# ─── Autocomplete ─────────────────────────────────────────────────────────────

$script:RunTargets = @($Global:Modules.Keys | Sort-Object) + @("all_modules")
$script:ExportFmts = @("json","html","pdf")
$script:ShowOpts   = @("modules")
$script:VerboseOpts = @("true","false")
$script:HelpOpts   = @("help","run","show","export","history","context","clear","version","verbose","banner","exit")
$script:TopCmds    = @("help","run","show","export","history","hist","context","ctx","clear","cls","version","verbose","banner","exit","quit")

# Tab-cycle state — reset whenever the user types or deletes a character
$script:TabCtx = $null

function _Resolve-TabHits([string]$buf) {
    $trailingSpace = $buf -match ' $'
    [string[]]$parts = @($buf.TrimEnd() -split '\s+' | Where-Object { $_ -ne '' })
    $verb  = if ($parts.Count -ge 1) { $parts[0] } else { '' }
    $sub   = if ($parts.Count -ge 2) { $parts[1] } else { '' }
    $inSub = ($verb -ne '') -and ($trailingSpace -or $parts.Count -ge 2)

    if ($inSub) {
        $prefix = if ($trailingSpace) { '' } else { $sub }
        [string[]]$pool = switch ($verb) {
            'run'     { $script:RunTargets  }
            'export'  { $script:ExportFmts  }
            'show'    { $script:ShowOpts    }
            'help'    { $script:HelpOpts    }
            'verbose' { $script:VerboseOpts }
            default   { @() }
        }
        [string[]]$hits = @($pool | Where-Object { $_ -like "$prefix*" })
        return @{ Hits = $hits; Verb = $verb; Sub = $true }
    }

    [string[]]$hits = @($script:TopCmds | Where-Object { $_ -like "$verb*" })
    return @{ Hits = $hits; Verb = $verb; Sub = $false }
}

function _Apply-TabHit($ctx) {
    $hit = $ctx.Hits[$ctx.Idx]
    if ($ctx.Sub) {
        return "$($ctx.Verb) $hit"
    }
    # Top-level: if verb takes a subcommand, check if only one sub-option exists
    $takesArg = @('run','export','show','help','verbose')
    if ($hit -in $takesArg) {
        [string[]]$subPool = @(switch ($hit) {
            'run'     { $script:RunTargets  }
            'export'  { $script:ExportFmts  }
            'show'    { $script:ShowOpts    }
            'help'    { $script:HelpOpts    }
            'verbose' { $script:VerboseOpts }
            default   { @() }
        })
        # Single subcommand available — chain-complete the whole thing
        if ($subPool.Count -eq 1) { return "$hit $($subPool[0])" }
        return "$hit "
    }
    return $hit
}

# ─── Main shell ───────────────────────────────────────────────────────────────

function Start-CLI {

    # Prevent Ctrl+C / Ctrl+Z from killing the process — we handle it ourselves
    $script:Interrupted = $false
    $cancelHandler = [System.ConsoleCancelEventHandler]{
        param($s, $e)
        $e.Cancel = $true                  # never exit the process
        $script:Interrupted = $true
    }
    [Console]::add_CancelKeyPress($cancelHandler)

    # History index: -1 means "not browsing history" (fresh prompt)
    [int]$histIdx = -1

    # Redraw the current input line cleanly and place the real console cursor.
    # This keeps Left/Right, insertion, deletion and Tab completion looking like
    # a normal readline-style prompt instead of printing partial fragments.
    function _Redraw-CLIInput {
        param(
            [string]$Text,
            [int]$Position
        )
        $row = [Console]::CursorTop
        $width = [Console]::BufferWidth
        [Console]::SetCursorPosition(0, $row)
        [Console]::Write((' ' * [Math]::Max(0, $width - 1)))
        [Console]::SetCursorPosition(0, $row)
        [Console]::Write($PROM)
        [Console]::Write($Text)
        $target = [Math]::Min($width - 1, $PLEN + $Position)
        [Console]::SetCursorPosition([Math]::Max(0, $target), $row)
    }

    # ANSI colour codes — work in Windows Terminal, VS Code, modern conhost
    $ESC   = [char]27
    $C     = "$ESC[38;5;88m"     # dark red (DefenceRecon > )
    $R     = "$ESC[0m"          # reset
    $PROM  = "${C}DefenceRecon >${R} "             # full coloured prompt string
    $PLEN  = "DefenceRecon > ".Length              # visual width for redraw padding

    while ($true) {

        $script:Interrupted = $false
        Write-Host -NoNewline $PROM
        [string]$buf = ""
        [int]$cursorPos = 0
        $histIdx = -1          # reset history cursor on each new prompt

        [bool]$prevTab = $false

        while ($true) {
            $key = [System.Console]::ReadKey($true)

            if ($key.Key -eq "Enter") {
                $script:TabCtx = $null
                $prevTab = $false
                Write-Host ""
                break
            }
            elseif ($key.Key -eq "Backspace") {
                $prevTab = $false
                $script:TabCtx = $null
                if ($buf.Length -gt 0) {
                    if ($cursorPos -gt 0) {
                        $buf = $buf.Remove($cursorPos - 1, 1)
                        $cursorPos--
                        _Redraw-CLIInput $buf $cursorPos
                    }
                }
            }
            elseif ($key.Key -eq "Delete") {
                $prevTab = $false
                $script:TabCtx = $null
                # Delete removes the character under the cursor (left-to-right).
                if ($cursorPos -lt $buf.Length) {
                    $buf = $buf.Remove($cursorPos, 1)
                    _Redraw-CLIInput $buf $cursorPos
                }
            }
            elseif ($key.Key -eq "Tab") {
                # Resolve matches for current buffer
                if ($null -eq $script:TabCtx -or $script:TabCtx.Source -ne $buf) {
                    $resolved = _Resolve-TabHits $buf
                    if ($resolved.Hits.Count -eq 0) { $prevTab = $false; continue }
                    $script:TabCtx = @{
                        Hits   = $resolved.Hits
                        Verb   = $resolved.Verb
                        Sub    = $resolved.Sub
                        Idx    = -1
                        Source = $buf
                    }
                }

                $hits = $script:TabCtx.Hits

                # Single match — complete immediately
                if ($hits.Count -eq 1) {
                    $script:TabCtx.Idx = 0
                    $buf = _Apply-TabHit $script:TabCtx
                    $script:TabCtx.Source = $buf
                    $cursorPos = $buf.Length
                    _Redraw-CLIInput $buf $cursorPos
                    $prevTab = $false
                    continue
                }

                # Multiple matches — show choices, then cycle on subsequent Tabs
                if (-not $prevTab) {
                    # First Tab: just show the list, keep buffer unchanged
                    Write-Host ""
                    $maxW = ($hits | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum + 3
                    $cols = [Math]::Max(1, [Math]::Floor(66 / $maxW))
                    for ($i = 0; $i -lt $hits.Count; $i++) {
                        Write-Host -NoNewline "  $($hits[$i].PadRight($maxW))" -ForegroundColor DarkGray
                        if (($i + 1) % $cols -eq 0 -or $i -eq $hits.Count - 1) { Write-Host "" }
                    }
                    Write-Host ""
                    _Redraw-CLIInput $buf $cursorPos
                } else {
                    # Subsequent Tabs: cycle through matches
                    $script:TabCtx.Idx = ($script:TabCtx.Idx + 1) % $hits.Count
                    $buf = _Apply-TabHit $script:TabCtx
                    $script:TabCtx.Source = $buf
                    $cursorPos = $buf.Length
                    _Redraw-CLIInput $buf $cursorPos
                }
                $prevTab = $true
            }
            elseif ($key.Key -eq "LeftArrow") {
                $prevTab = $false
                $script:TabCtx = $null
                if ($cursorPos -gt 0) {
                    $cursorPos--
                    _Redraw-CLIInput $buf $cursorPos
                }
            }
            elseif ($key.Key -eq "RightArrow") {
                $prevTab = $false
                $script:TabCtx = $null
                if ($cursorPos -lt $buf.Length) {
                    $cursorPos++
                    _Redraw-CLIInput $buf $cursorPos
                }
            }
            elseif ($key.Key -eq "Home") {
                $prevTab = $false
                $script:TabCtx = $null
                $cursorPos = 0
                _Redraw-CLIInput $buf $cursorPos
            }
            elseif ($key.Key -eq "End") {
                $prevTab = $false
                $script:TabCtx = $null
                $cursorPos = $buf.Length
                _Redraw-CLIInput $buf $cursorPos
            }
            elseif ($key.Key -eq "UpArrow") {
                $prevTab = $false
                $script:TabCtx = $null
                if ($script:History.Count -eq 0) { continue }
                if ($histIdx -eq -1) {
                    $histIdx = $script:History.Count - 1
                } elseif ($histIdx -gt 0) {
                    $histIdx--
                }
                $buf = $script:History[$histIdx]
                $cursorPos = $buf.Length
                _Redraw-CLIInput $buf $cursorPos
            }
            elseif ($key.Key -eq "DownArrow") {
                $prevTab = $false
                $script:TabCtx = $null
                if ($histIdx -eq -1) { continue }
                if ($histIdx -lt $script:History.Count - 1) {
                    $histIdx++
                    $buf = $script:History[$histIdx]
                    $cursorPos = $buf.Length
                } else {
                    $histIdx = -1
                    $buf = ""
                    $cursorPos = 0
                }
                _Redraw-CLIInput $buf $cursorPos
            }
            else {
                $prevTab = $false
                $script:TabCtx = $null
                $histIdx = -1
                if ($key.KeyChar -ne "`0") {
                    $buf = $buf.Insert($cursorPos, [string]$key.KeyChar)
                    $cursorPos++
                    _Redraw-CLIInput $buf $cursorPos
                }
            }
        }

        [string]$cmd = $buf.Trim()
        if ($cmd -eq "") { continue }

        $script:History.Add($cmd) | Out-Null

        # ── Dispatch ──────────────────────────────────────────────────────────
        if ($cmd -match '^run (\S+)$' -and $Global:Modules.ContainsKey($Matches[1])) {
            Run-Module $Matches[1]
            if ($script:Interrupted) {
                Write-Host "  [!] Interrupted." -ForegroundColor Yellow
                Write-Host ""
            }
        }
        elseif ($cmd -eq 'run all_modules') { Run-All }
        elseif ($cmd -eq    'show modules')                    { Show-Modules }
        elseif ($cmd -match '^export (\S+)$')                  { Export-Results $Matches[1] }
        elseif ($cmd -eq    'history' -or $cmd -eq 'hist')     { Show-History }
        elseif ($cmd -eq    'context' -or $cmd -eq 'ctx')      { Show-SystemContext }
        elseif ($cmd -eq    'clear'   -or $cmd -eq 'cls')      { Clear-Host }
        elseif ($cmd -eq    'version')                         { Write-Host "  DefenceRecon v$script:Version" }
        elseif ($cmd -eq    'banner')                          { Show-Banner }
        elseif ($cmd -match '^help (\S+)$')                    { Show-Help $Matches[1] }
        elseif ($cmd -eq    'help')                            { Show-Help }
        elseif ($cmd -eq    'exit'    -or $cmd -eq 'quit')     { Write-Host "Bye." -ForegroundColor DarkGray; exit }
        elseif ($cmd -eq    'verbose true')  {
            $Global:VerboseMode = $true
            Write-Host "  [+] Verbose mode: true" -ForegroundColor DarkYellow
        }
        elseif ($cmd -eq    'verbose false') {
            $Global:VerboseMode = $false
            Write-Host "  [-] Verbose mode: false" -ForegroundColor DarkGray
        }
        elseif ($cmd -eq    'verbose') {
            $state = if ($Global:VerboseMode) { "true" } else { "false" }
            Write-Host "  Verbose is currently: $state" -ForegroundColor DarkYellow
        }
        else                                                   { Write-Host "[!] Unknown command. Type 'help' for a list." -ForegroundColor Yellow }
    }
}
