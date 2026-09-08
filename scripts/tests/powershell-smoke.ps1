# Local fixtures only. The test redirects push transport to a disposable bare repo.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$testRoot = Join-Path $sourceRoot ('.workflow-tests/' + [Guid]::NewGuid().ToString('N'))
$fixture = Join-Path $testRoot 'fixture with spaces'
$bare = Join-Path $testRoot 'remote.git'
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'scripts') -Destination $fixture -Recurse
Copy-Item -LiteralPath (Join-Path $sourceRoot 'workflow.example.json') -Destination $fixture
$utf8 = New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), "workflow.local.json`n", $utf8)
$gitExe = (Get-Command git.exe).Source
function Invoke-TestGit {
    & $gitExe @args
    if ($LASTEXITCODE -ne 0) { throw 'Fixture git command failed.' }
}
function Expect-Failure {
    param([scriptblock]$Action)
    $failed = $false
    try { & $Action } catch { $failed = $true; Write-Host "Expected failure: $($_.Exception.Message)" }
    if (-not $failed) { throw 'Expected the operation to fail.' }
}
Invoke-TestGit init --bare $bare
Invoke-TestGit init $fixture
Invoke-TestGit -C $fixture checkout -b util
$setup = Join-Path $fixture 'scripts/setup.ps1'
$push = Join-Path $fixture 'scripts/push.ps1'
$pull = Join-Path $fixture 'scripts/pull.ps1'
& $setup -RepoUrl 'https://github.com/workflow-test/example.git' -GitUserName 'Workflow Test' -GitUserEmail 'workflow-test@example.invalid'
& $setup -RepoUrl 'https://github.com/workflow-test/example.git'
Expect-Failure { & $setup -RepoUrl 'https://github.com/other/example.git' }
Expect-Failure { & $setup -RepoUrl 'https://token@github.com/workflow-test/example.git' }
Expect-Failure { & $setup -RepoUrl 'https://github.com/workflow-test/example.git' -ContainerRepoPath '/root/xv6-labs-2021' }
Expect-Failure { & $push }
Expect-Failure { & $pull }

# Scripts still validate a GitHub origin; only the test's git push is redirected.
function git {
    $nativeArgs = @($args)
    $pushIndex = [Array]::IndexOf($nativeArgs, 'push')
    if ($pushIndex -ge 0) {
        $originIndex = [Array]::IndexOf($nativeArgs, 'origin', $pushIndex)
        if ($originIndex -lt 0) { throw 'Unexpected push arguments.' }
        $nativeArgs[$originIndex] = $bare
    }
    & $gitExe @nativeArgs
    $global:LASTEXITCODE = $LASTEXITCODE
}
try {
    & $push -Message 'test: first workflow commit'
    & $push
    $localHead = & $gitExe -C $fixture rev-parse HEAD
    $remoteHead = & $gitExe --git-dir=$bare rev-parse refs/heads/util
    if ($localHead -ne $remoteHead) { throw 'Pushed HEAD does not match local HEAD.' }
    [IO.File]::WriteAllText((Join-Path $fixture 'example.txt'), "new work`n", $utf8)
    & $push -Message 'test: update source'
    $localHead = & $gitExe -C $fixture rev-parse HEAD
    $remoteHead = & $gitExe --git-dir=$bare rev-parse refs/heads/util
    if ($localHead -ne $remoteHead) { throw 'Second push did not update the remote.' }
    Invoke-TestGit -C $fixture checkout --detach
    Expect-Failure { & $push }
} finally {
    Remove-Item Function:git
}
Write-Host "ALL POWERSHELL SMOKE TESTS PASSED. Fixtures: $testRoot"
