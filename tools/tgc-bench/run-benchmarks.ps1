# Compare GC backends for tgc development
# Requires a built dmd/druntime from feature/tgc with tgc registered.
param(
    [int]$Iters = 50000,
    [int]$Threads = 4
)

$ErrorActionPreference = "Stop"
$env:TGC_BENCH_ITERS = "$Iters"
$env:TGC_BENCH_THREADS = "$Threads"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bench = Join-Path $root "druntime\test\gc\generated\windows\release\64\tgc_bench.exe"

if (-not (Test-Path $bench)) {
    Write-Error "Build tgc_bench first: make -C druntime/test/gc OS=windows MODEL=64 (from dmd fork root after druntime build)"
}

$runs = @(
    @{ Name = "conservative (default)"; Args = @() },
    @{ Name = "tgc"; Args = @("--DRT-gcopt=gc:tgc") },
    @{ Name = "tgc (native shared regions)"; Args = @("--DRT-gcopt=gc:tgc", "tgcShared:native") }
)

foreach ($run in $runs) {
    Write-Host "`n=== $($run.Name) ===" -ForegroundColor Cyan
    & $bench @($run.Args)
}

Write-Host "`nOptional SymGC row (requires symgc-linked build):" -ForegroundColor Yellow
Write-Host "  tgc_bench --DRT-gcopt=gc:sdc"
