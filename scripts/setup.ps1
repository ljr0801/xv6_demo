[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoUrl,
    [string]$GitUserName,
    [string]$GitUserEmail,
    [string]$ContainerName,
    [string]$ContainerRepoPath
)
. (Join-Path $PSScriptRoot 'common.ps1')
Assert-Repository
Assert-GitHubUrl -Url $RepoUrl
$settings = Get-WorkflowSettings
if ($ContainerName) { $settings.ContainerName = $ContainerName }
if ($ContainerRepoPath) { $settings.ContainerRepoPath = $ContainerRepoPath }
Assert-ContainerSettings -Settings $settings

$remotes = @(Invoke-Git -Arguments @('remote'))
if ($remotes -contains 'origin') {
    $existing = Get-OriginUrl
    if ($existing -ne $RepoUrl) { throw "origin is already $existing. Inspect it and explicitly change it with git remote set-url origin <URL> if intended." }
} else {
    Invoke-Git -Arguments @('remote', 'add', 'origin', $RepoUrl)
}
Invoke-Git -Arguments @('config', '--local', 'core.autocrlf', 'false')
Invoke-Git -Arguments @('config', '--local', 'core.fileMode', 'false')
Invoke-Git -Arguments @('config', '--local', 'remote.pushDefault', 'origin')
if ($GitUserName) { Invoke-Git -Arguments @('config', '--local', 'user.name', $GitUserName) }
if ($GitUserEmail) { Invoke-Git -Arguments @('config', '--local', 'user.email', $GitUserEmail) }
$configPath = Join-Path $script:RepoRoot 'workflow.local.json'
$json = ($settings | ConvertTo-Json) + "`n"
[IO.File]::WriteAllText($configPath, $json, (New-Object Text.UTF8Encoding $false))
Write-Host "Configured origin: $RepoUrl"
Write-Host "Container checkout: $($settings.ContainerName):$($settings.ContainerRepoPath)"
Write-Host 'Next: scripts/push.ps1 -Message "chore: set up xv6 workflow"'
Write-Host 'If Git asks for an identity, rerun setup with -GitUserName and -GitUserEmail.'
