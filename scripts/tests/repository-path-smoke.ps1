# Read-only regression test: Chinese repository paths under legacy encodings.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'common.ps1')
$originalEncoding = [Console]::OutputEncoding
$originalRoot = $script:RepoRoot
$originalLocation = Get-Location
try {
    foreach ($codePage in @(936, 437, 65001)) {
        [Console]::OutputEncoding = [Text.Encoding]::GetEncoding($codePage)
        Assert-Repository
        # Invocation location must not affect root detection.
        Set-Location -LiteralPath (Join-Path $originalRoot 'scripts')
        Assert-Repository
        Set-Location -LiteralPath $originalRoot
        Write-Host "PASS: repository root accepted with code page $codePage."
    }
    $script:RepoRoot = Join-Path $originalRoot 'scripts'
    $rejected = $false
    try { Assert-Repository } catch { $rejected = $true }
    if (-not $rejected) { throw 'A non-root directory was incorrectly accepted.' }
    Write-Host 'PASS: non-root directory rejected.'
} finally {
    $script:RepoRoot = $originalRoot
    [Console]::OutputEncoding = $originalEncoding
    Set-Location -LiteralPath $originalLocation.Path
}
Write-Host 'ALL REPOSITORY PATH TESTS PASSED.'
