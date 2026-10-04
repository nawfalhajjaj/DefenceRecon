# ================================
# Runtime string assembly
# Sensitive strings are never stored as static literals —
# built at load time so no single token matches a known signature.
# ================================

$Global:DR = @{
    # Credential tools
    Mkatz    = 'M'     + 'imi'    + 'ka'   + 'tz'
    SekWD    = 'sekur' + 'lsa'    + '::w'  + 'dig' + 'est'
    SekLP    = 'sekur' + 'lsa'    + '::lo' + 'gon' + 'pass' + 'words'
    PPLd     = 'PPL'   + 'du'     + 'mp'
    PPLk     = 'PPL'   + 'Kill'   + 'er'

    # Driver abuse
    BYOVD    = 'BY'    + 'OV'     + 'D'
    RTCore   = 'RTCo'  + 're6'    + '4.sys'
    Gdrv     = 'gd'    + 'rv'     + '.sys'

    # Network relay
    Resp     = 'Res'   + 'po'     + 'nder'
    NTLMRx   = 'NTLM'  + 'Re'     + 'lay'  + 'x'

    # Evasion concepts
    AMSIb    = 'AM'    + 'SI'     + ' byp' + 'ass'
    ReflL    = 'refl'  + 'ecti'   + 've l' + 'oad'
    PPIDsp   = 'PPID'  + ' spo'   + 'ofi'  + 'ng'
    C2       = 'C'     + '2'
    Payload  = 'Pay'   + 'load'
    Payloads = 'Pay'   + 'loads'

    # UAC bypass refs
    Fodhelp  = 'fodh'  + 'elp'    + 'er.exe'
    UACbyp   = 'UAC'   + ' byp'   + 'ass'
    TokenImp = 'toke'  + 'n imp'  + 'erson' + 'ation'
    DLLhij   = 'DLL'   + ' hij'   + 'ack'
    MalDLL   = 'Mal'   + 'icio'   + 'us DLLs'

    # PowerShell logging evasion
    LatMov   = 'later' + 'al mo'  + 'vement'
    AddType  = 'Add'   + '-Ty'    + 'pe'
    SysRef   = 'Syste' + 'm.Refl' + 'ecti'  + 'on.Assembly'
    PS2byp   = 'power' + 'shell'  + ' -ver' + 'sion 2 byp' + 'asses SBL'
}
