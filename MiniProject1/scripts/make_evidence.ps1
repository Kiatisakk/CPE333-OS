# Create small, traceable transcript excerpts for the PDF report.
# Every excerpt is copied from a numbered range of a file under results/;
# no output is edited or invented.  The full logs remain the source of truth.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "evidence"
New-Item -ItemType Directory -Force $out | Out-Null

function Write-Excerpt {
    param(
        [string]$Name,
        [string]$Source,
        [int]$Start,
        [int]$End
    )
    $sourcePath = Join-Path $root $Source
    $lines = @(Get-Content -LiteralPath $sourcePath)
    $last = [Math]::Min($End, $lines.Count)
    if ($Start -lt 1 -or $Start -gt $last) {
        throw "Invalid range $Start-$End for $Source ($($lines.Count) lines)"
    }
    $slice = $lines[($Start - 1)..($last - 1)]
    Set-Content -LiteralPath (Join-Path $out $Name) -Value $slice -Encoding UTF8
}

function Write-Combined {
    param(
        [string]$Name,
        [object[]]$Ranges
    )
    $all = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $Ranges) {
        $sourcePath = Join-Path $root $r.Source
        $lines = @(Get-Content -LiteralPath $sourcePath)
        $last = [Math]::Min($r.End, $lines.Count)
        if ($r.Start -lt 1 -or $r.Start -gt $last) {
            throw "Invalid range $($r.Start)-$($r.End) for $($r.Source) ($($lines.Count) lines)"
        }
        if ($all.Count -gt 0) { $all.Add("") }
        $all.Add("# excerpt: $($r.Source) lines $($r.Start)-$last")
        $all.AddRange([string[]]$lines[($r.Start - 1)..($last - 1)])
    }
    Set-Content -LiteralPath (Join-Path $out $Name) -Value $all -Encoding UTF8
}

Write-Excerpt vm_baseline.txt results/vm/01_env.txt 1 23
Write-Excerpt wsl_baseline.txt results/wsl/01_env.txt 1 23
Write-Excerpt vm_swap.txt results/vm/01a_swap.txt 1 19
Write-Excerpt wsl_sources.txt results/wsl/02_sources.txt 1 13
Write-Combined wsl_packages.txt @(
    [pscustomobject]@{ Source = "results/wsl/03_packages.txt"; Start = 1;   End = 30  },
    [pscustomobject]@{ Source = "results/wsl/03_packages.txt"; Start = 32;  End = 68  },
    [pscustomobject]@{ Source = "results/wsl/03_packages.txt"; Start = 793; End = 793 },
    [pscustomobject]@{ Source = "results/wsl/03_packages.txt"; Start = 795; End = 814 },
    [pscustomobject]@{ Source = "results/wsl/03_packages.txt"; Start = 912; End = 912 }
)
Write-Excerpt wsl_source.txt results/wsl/04_source.txt 12668 12676
Write-Excerpt wsl_prepare.txt results/wsl/05_prepare.txt 1 64
Write-Excerpt wsl_abi.txt results/wsl/06_abi.txt 1 15
Write-Excerpt vm_build_partial.txt results/vm/07_build_partial.txt 3889 3952
Write-Combined wsl_build.txt @(
    [pscustomobject]@{ Source = "results/wsl/07_build.txt"; Start = 1;     End = 3     },
    [pscustomobject]@{ Source = "results/wsl/07_build.txt"; Start = 65290; End = 65317 },
    [pscustomobject]@{ Source = "results/wsl/07_build.txt"; Start = 65507; End = 65537 }
)
Write-Excerpt vm_install.txt results/vm/08_install.txt 1 50
Write-Excerpt vm_configure.txt results/vm/08a_configure.txt 1 57
Write-Excerpt vm_verify.txt results/vm/09_verify.txt 1 22

Write-Output "Evidence excerpts written to $out"
