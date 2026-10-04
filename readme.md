# DefenceRecon

DefenceRecon is an interactive PowerShell-based Windows security enumeration tool built for red teamers and penetration testers. It queries defence configurations, AV/EDR products, LSASS protections, logging policies, and more — all from a clean interactive shell with Tab completion, history, and structured export.

**Author**: Nawfal Hajjaj  
**Version**: 1.0

---

## Getting Started

```powershell
.\DefenceRecon.ps1
```

Run as Administrator for full accuracy — some registry keys and service states require elevated privileges. Handle execution policy per your environment before launching.

---

## Shell Commands

```
help [command]           Show available commands or detailed help for one
run <module>             Run a specific module (e.g. run defender)
run all_modules          Run every module in sequence
show modules             List all available modules
export <json|html|pdf>   Export results to a file
history                  Show command history
context                  Display system context (hostname, user, OS, privileges)
verbose <true|false>     Show registry keys and cmdlets used during enumeration
banner                   Re-display the ASCII banner
clear                    Clear the terminal
version                  Show version
exit                     Exit the shell
```

---

## Modules

| Module        | What it checks                                                                                    |
|---------------|--------------------------------------------------------------------------------------------------|
| `defender`    | Defender state, real-time/tamper protection, cloud protection, signature version                 |
| `firewall`    | Domain/Private/Public profiles, default inbound/outbound actions, rule counts                    |
| `antivirus`   | Installed AV/EDR via WMI, process scan, and direct Defender detection                            |
| `services`    | Status of 12 security-critical services (WinDefend, Sense, Sysmon, EDR agents…)                 |
| `uac`         | UAC level, admin prompt behavior, secure desktop, virtualization                                 |
| `ps_logging`  | Script Block Logging, Module Logging, Transcription — inverted risk (logging on = attacker risk) |
| `applocker`   | AppIDSvc state, per-collection enforcement mode, WDAC presence and driver blocklist              |
| `lsass`       | RunAsPPL, VBS, Credential Guard, WDigest, LM compat, null sessions, LM hash storage             |
| `all_modules` | Runs all modules above in sequence                                                               |

---

## Risk Levels

Each finding is rated from a red team perspective:

| Tag    | Meaning                                  |
|--------|------------------------------------------|
| `CRIT` | Immediate win — no bypass needed         |
| `HIGH` | Significant obstacle or opportunity      |
| `MED`  | Worth noting, situational                |
| `ok`   | Control is active, must be accounted for |
| `--`   | Informational only                       |

---

## Requirements

- Windows 10 / 11 or Windows Server 2016+
- PowerShell 5.1 or later
- Administrator privileges recommended for complete results
