[CmdletBinding()]
param([string]$Message)
. (Join-Path $PSScriptRoot 'common.ps1')
Assert-Repository
Assert-NoGitOperation
$branch = Get-CurrentBranch
$url = Get-OriginUrl

if ($PSBoundParameters.ContainsKey('Message')) {
    if ([string]::IsNullOrWhiteSpace($Message)) { throw 'The commit message must not be empty.' }
    # Check identity before staging anything. Do not invent a user identity.
    $null = Invoke-Git -Arguments @('var', 'GIT_AUTHOR_IDENT')
    $null = Invoke-Git -Arguments @('var', 'GIT_COMMITTER_IDENT')
    Invoke-Git -Arguments @('diff', '--check')
    Invoke-Git -Arguments @('diff', '--cached', '--check')
    Invoke-Git -Arguments @('add', '--all', '--', '.')
    Invoke-Git -Arguments @('diff', '--cached', '--check')
    $staged = @(Invoke-Git -Arguments @('diff', '--cached', '--name-only'))
    if ($staged.Count -gt 0) {
        Invoke-Git -Arguments @('diff', '--cached', '--stat')
        Invoke-Git -Arguments @('commit', '-m', $Message)
    } else {
        Write-Host 'No new changes to commit; pushing existing commits.'
    }
} else {
    Assert-CleanTree
}
Assert-CleanTree
Invoke-Git -Arguments @('push', '--set-upstream', 'origin', "HEAD:refs/heads/$branch")
$sha = [string](Invoke-Git -Arguments @('rev-parse', 'HEAD'))
Write-Host "Pushed $branch ($($sha.Trim())) to $url"
