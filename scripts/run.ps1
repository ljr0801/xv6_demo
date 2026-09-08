[CmdletBinding()]
param(
    [ValidateSet('qemu', 'grade', 'build', 'shell')][string]$Target = 'qemu',
    [switch]$Clean
)
. (Join-Path $PSScriptRoot 'common.ps1')
Assert-Repository
Assert-NoGitOperation
Assert-CleanTree
$branch = Get-CurrentBranch
$url = Get-OriginUrl
$sha = [string](Invoke-Git -Arguments @('rev-parse', 'HEAD'))
$settings = Get-WorkflowSettings
Assert-ContainerRunning -Name $settings.ContainerName

$cleanFlag = if ($Clean) { '1' } else { '0' }
Invoke-ContainerScript -Container $settings.ContainerName -ScriptPath (Join-Path $PSScriptRoot 'container-run.sh') -ScriptArguments @($settings.ContainerRepoPath, $sha.Trim(), $branch, $url, $Target, $cleanFlag) -Interactive:($Target -in @('qemu', 'shell'))
