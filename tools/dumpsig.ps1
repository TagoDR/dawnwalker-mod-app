# Prints UFunction signatures (params with types/offsets) from UE4SS_ObjectDump.txt.
# Usage: .\dumpsig.ps1 -Class "DogwoodSystem.TimeSystemImpl" [-Functions SetTime,GetCurrentDay] [-Props]
param(
    [Parameter(Mandatory = $true)][string]$Class,
    [string[]]$Functions,
    [switch]$Props,
    [switch]$ListFunctions
)
$d = "D:\SteamLibrary\steamapps\common\The Blood of Dawnwalker\Dawnwalker\Binaries\Win64\UE4SS_ObjectDump.txt"
$esc = [regex]::Escape($Class)

if ($ListFunctions) {
    Select-String -Path $d -Pattern ("^\[[0-9A-F]+\] Function /Script/" + $esc + ":") |
        ForEach-Object { $_.Line -replace '^\[[0-9A-F]+\] Function /Script/[A-Za-z0-9_]+\.[A-Za-z0-9_]+:', '' -replace ' \[n:.*$', '' } |
        Sort-Object -Unique
}

if ($Props) {
    Write-Host "--- Properties of $Class ---"
    Select-String -Path $d -Pattern ("Property /Script/" + $esc + ":[A-Za-z0-9_]+ \[o:") |
        ForEach-Object { $_.Line -replace '^\[[0-9A-F]+\] ', '' -replace ' \[n:.*?\]', '' -replace ' \[c:.*?\]', '' -replace ' \[owr:.*$', '' -replace ("/Script/" + $esc + ":"), '' } |
        Sort-Object -Unique
}

foreach ($n in $Functions) {
    $hits = Select-String -Path $d -Pattern ("^\[[0-9A-F]+\] Function /Script/" + $esc + ":" + [regex]::Escape($n) + " ") -Context 0, 12
    foreach ($h in $hits) {
        $fn = $h.Line
        $owr = ''
        if ($fn -match '^\[([0-9A-F]+)\]') { $owr = $Matches[1] }
        Write-Host ("=== " + ($fn -replace '^\[[0-9A-F]+\] ', '' -replace ' \[n:.*$', ''))
        foreach ($line in $h.Context.PostContext) {
            if ($line -match ("\[owr: " + $owr + "\]")) {
                Write-Host ("    " + ($line -replace '^\[[0-9A-F]+\] ', '' -replace ' \[n:.*?\]', '' -replace ' \[c:.*?\]', '' -replace ' \[owr:.*$', '' -replace ("/Script/" + $esc + ":" + [regex]::Escape($n) + ":"), ''))
            }
        }
    }
}
