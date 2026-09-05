# Parses a Windows minidump's module list + exception stream without windbg.
# Usage: .\dumpmods.ps1 -Dump <path\UEMinidump.dmp> [-Address 0x00007ff90d6854f0]
param(
    [Parameter(Mandatory = $true)][string]$Dump,
    [string]$Address
)
$bytes = [System.IO.File]::ReadAllBytes($Dump)
$u32 = { param($o) [BitConverter]::ToUInt32($bytes, $o) }
$u64 = { param($o) [BitConverter]::ToUInt64($bytes, $o) }
if ([Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne "MDMP") { throw "not a minidump" }
$numStreams = & $u32 8
$dirRva = & $u32 12
$streams = @{}
for ($i = 0; $i -lt $numStreams; $i++) {
    $e = $dirRva + $i * 12
    $streams[[int](& $u32 $e)] = @{ Size = (& $u32 ($e + 4)); Rva = (& $u32 ($e + 8)) }
}

$modules = @()
if ($streams.ContainsKey(4)) {
    $rva = $streams[4].Rva
    $count = & $u32 $rva
    for ($i = 0; $i -lt $count; $i++) {
        $m = $rva + 4 + $i * 108
        $base = & $u64 $m
        $size = & $u32 ($m + 8)
        $nameRva = & $u32 ($m + 20)
        $nameLen = & $u32 $nameRva
        $name = [Text.Encoding]::Unicode.GetString($bytes, $nameRva + 4, $nameLen)
        $modules += [pscustomobject]@{ Base = $base; End = $base + $size; Size = $size; Name = $name }
    }
}

if ($streams.ContainsKey(6)) {
    $e = $streams[6].Rva
    $code = & $u32 ($e + 8)
    $addr = & $u64 ($e + 24)
    $nparams = & $u32 ($e + 32)
    $p0 = & $u64 ($e + 40)
    $p1 = & $u64 ($e + 48)
    Write-Host ("Exception: code=0x{0:X8} at 0x{1:X16} params={2} p0={3} (0=read,1=write,8=exec) p1=0x{4:X16}" -f $code, $addr, $nparams, $p0, $p1)
    $hit = $modules | Where-Object { $addr -ge $_.Base -and $addr -lt $_.End } | Select-Object -First 1
    if ($hit) { Write-Host ("  instruction in {0} + 0x{1:X}" -f (Split-Path $hit.Name -Leaf), ($addr - $hit.Base)) }
}

Write-Host "--- modules of interest ---"
$modules | Where-Object { $_.Name -match 'Dawnwalker|UE4SS|dwmapi|main\.dll|Mods\\|xinput|lua' } |
    ForEach-Object { "{0,-70} 0x{1:X16} - 0x{2:X16} ({3:N0} bytes)" -f (Split-Path $_.Name -Leaf), $_.Base, $_.End, $_.Size }

if ($Address) {
    $a = [Convert]::ToUInt64($Address.Replace("0x", ""), 16)
    $hit = $modules | Where-Object { $a -ge $_.Base -and $a -lt $_.End } | Select-Object -First 1
    if ($hit) { Write-Host ("Address {0} is inside {1} + 0x{2:X}" -f $Address, $hit.Name, ($a - $hit.Base)) }
    else {
        $below = $modules | Where-Object { $_.End -le $a } | Sort-Object End -Descending | Select-Object -First 1
        $above = $modules | Where-Object { $_.Base -gt $a } | Sort-Object Base | Select-Object -First 1
        $belowName = if ($below) { Split-Path $below.Name -Leaf } else { "(none)" }
        $aboveName = if ($above) { Split-Path $above.Name -Leaf } else { "(none)" }
        Write-Host ("Address {0} is NOT inside any module. Nearest below: {1} (ends 0x{2:X}); nearest above: {3} (starts 0x{4:X})" -f $Address, $belowName, [uint64]$(if ($below) { $below.End } else { 0 }), $aboveName, [uint64]$(if ($above) { $above.Base } else { 0 }))
    }
}
Write-Host ("total modules: {0}" -f $modules.Count)
