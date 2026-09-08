[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'common.ps1')
Assert-Repository
Assert-NoGitOperation
Assert-CleanTree
$branch = Get-CurrentBranch
$url = Get-OriginUrl
$sha = [string](Invoke-Git -Arguments @('rev-parse', 'HEAD'))
$settings = Get-WorkflowSettings
Assert-ContainerRunning -Name $settings.ContainerName

# Copy only the sync helper. Experiment source reaches the container through Git.
Invoke-ContainerScript -Container $settings.ContainerName -ScriptPath (Join-Path $PSScriptRoot 'container-sync.sh') -ScriptArguments @($url, $branch, $settings.ContainerRepoPath, $sha.Trim())
