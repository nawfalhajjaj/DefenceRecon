# ================================
# Module registry
# ================================

# Invoke map: name -> scriptblock (populated by Register-Module)
$Global:Modules    = @{}

# Ordered metadata list: used by 'show modules' and tab completion
$Global:ModuleMeta = [System.Collections.Generic.List[PSCustomObject]]::new()

function Register-Module {
    param(
        [string]$Name,
        [string]$Summary,
        [scriptblock]$Invoke
    )
    $Global:Modules[$Name] = $Invoke
    $Global:ModuleMeta.Add([PSCustomObject]@{ Name = $Name; Summary = $Summary; Tag = "" })
}
