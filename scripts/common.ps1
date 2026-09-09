Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Native {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$File failed (exit $LASTEXITCODE). Resolve the error above and retry."
    }
}

function Invoke-Git {
    param([string[]]$Arguments)
    Invoke-Native -File git -Arguments (@('-C', $script:RepoRoot) + $Arguments)
}

function Assert-Repository {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows first.' }
    if (-not (Test-Path -LiteralPath (Join-Path $script:RepoRoot '.git'))) {
        throw 'Run these scripts from a clone of this repository.'
    }
    # Git emits UTF-8 paths, but Windows PowerShell may decode them using GBK
    # or an OEM code page. Check root membership without decoding a full path.
    $inside = [string](Invoke-Git -Arguments @('rev-parse', '--is-inside-work-tree'))
    $prefix = [string](Invoke-Git -Arguments @('rev-parse', '--show-prefix'))
    if ($inside.Trim() -ne 'true' -or $prefix.Length -ne 0) {
        throw 'The scripts must be inside the repository root.'
    }
}

function Assert-NoGitOperation {
    foreach ($name in @('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply', 'sequencer', 'BISECT_START')) {
        $path = [string](Invoke-Git -Arguments @('rev-parse', '--git-path', $name))
        if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $script:RepoRoot $path }
        if (Test-Path -LiteralPath $path) { throw "An unfinished Git operation exists ($name). Finish or abort it first." }
    }
}

function Get-CurrentBranch {
    $branch = [string](Invoke-Git -Arguments @('symbolic-ref', '--quiet', '--short', 'HEAD'))
    if ([string]::IsNullOrWhiteSpace($branch)) { throw 'Detached HEAD: switch to an experiment branch first.' }
    return $branch.Trim()
}

function Assert-CleanTree {
    $status = @(Invoke-Git -Arguments @('status', '--porcelain', '--untracked-files=all'))
    if ($status.Count -gt 0) {
        $status | Out-Host
        throw 'Local changes are not committed. Run push.ps1 -Message "..." first, or commit them yourself.'
    }
}

function Assert-GitHubUrl {
    param([string]$Url)
    # No embedded credentials, query strings, options, or shell syntax.
    if ($Url -notmatch '^(https://github\.com/|git@github\.com:)[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?$') {
        throw 'Use https://github.com/OWNER/REPO.git or git@github.com:OWNER/REPO.git, without a token in the URL.'
    }
}

function Get-OriginUrl {
    $remotes = @(Invoke-Git -Arguments @('remote'))
    if ($remotes -notcontains 'origin') { throw 'GitHub origin is missing. Run scripts/setup.ps1 -RepoUrl <GitHub URL> first.' }
    $urls = @(Invoke-Git -Arguments @('remote', 'get-url', '--all', 'origin'))
    $pushUrls = @(Invoke-Git -Arguments @('remote', 'get-url', '--push', '--all', 'origin'))
    if ($urls.Count -ne 1 -or $pushUrls.Count -ne 1 -or $urls[0] -ne $pushUrls[0]) {
        throw 'origin must have one matching fetch/push URL so the container pulls what you push.'
    }
    $url = [string]$urls[0]
    Assert-GitHubUrl -Url $url
    return $url
}

function Assert-ContainerSettings {
    param($Settings)
    if ($Settings.ContainerName -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { throw 'Invalid ContainerName.' }
    $path = [string]$Settings.ContainerRepoPath
    if ($path -notmatch '^/workspaces/[A-Za-z0-9][A-Za-z0-9_.-]*$') {
        throw 'ContainerRepoPath must be a direct child of /workspaces (for example /workspaces/xv6_own), starting with a letter or number.'
    }
}

function Get-WorkflowSettings {
    $path = Join-Path $script:RepoRoot 'workflow.local.json'
    if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $script:RepoRoot 'workflow.example.json' }
    $settings = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    Assert-ContainerSettings -Settings $settings
    return $settings
}

function Assert-ContainerRunning {
    param([string]$Name)
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Install Docker Desktop first.' }
    $running = [string](Invoke-Native -File docker -Arguments @('inspect', '--format', '{{.State.Running}}', $Name))
    if ($running.Trim() -ne 'true') { throw "Container $Name is stopped. Run: docker start $Name" }
}

function Invoke-ContainerScript {
    param([string]$Container, [string]$ScriptPath, [string[]]$ScriptArguments, [switch]$Interactive)
    $temporaryScript = '/tmp/xv6-workflow-' + [Guid]::NewGuid().ToString('N') + '.sh'
    Invoke-Native -File docker -Arguments @('cp', $ScriptPath, "${Container}:$temporaryScript")
    try {
        $dockerArgs = @('exec')
        if ($Interactive) { $dockerArgs += '-it' }
        $dockerArgs += @($Container, 'bash', $temporaryScript)
        Invoke-Native -File docker -Arguments ($dockerArgs + $ScriptArguments)
    } finally {
        & docker exec $Container rm -f -- $temporaryScript
        if ($LASTEXITCODE -ne 0) { Write-Warning "Could not remove temporary helper $temporaryScript." }
    }
}
