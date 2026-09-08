#!/usr/bin/env bash
# Run inside the lab container. Arguments are passed separately by PowerShell.
set -Eeuo pipefail

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 4 ]] || fail 'Usage: container-sync.sh <repo-url> <branch> <target-dir> <expected-local-HEAD>'
repo_url=$1
branch=$2
target_dir=$3
expected_head=${4,,}

command -v git >/dev/null 2>&1 || fail 'Git is not installed in the container.'
[[ -n "$repo_url" && "$repo_url" != -* ]] || fail 'The repository URL is empty or invalid.'
[[ "$branch" != -* && "$branch" != HEAD ]] || fail 'Use a named branch, not an option or HEAD.'
git check-ref-format "refs/heads/$branch" >/dev/null 2>&1 || fail 'Invalid branch name.'
[[ "$expected_head" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] || fail 'Expected HEAD must be a full Git commit ID.'
[[ "$target_dir" =~ ^/workspaces/[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
  fail 'The target must be a direct child of /workspaces, with a name containing only letters, numbers, dot, underscore or hyphen.'

# A caller's Git environment must not redirect these operations elsewhere.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR
export GIT_TERMINAL_PROMPT=0

[[ ! -L /workspaces ]] || fail '/workspaces must not be a symbolic link.'
[[ ! -e /workspaces || -d /workspaces ]] || fail '/workspaces exists and is not a directory.'
[[ ! -L "$target_dir" ]] || fail 'The target must not be a symbolic link.'
mkdir -p -- /workspaces
for parent_dir in / /workspaces; do
  [[ ! -e "$parent_dir/.git" && ! -L "$parent_dir/.git" ]] ||
    fail 'The target must not be nested inside another Git working tree.'
done
if git -C /workspaces rev-parse --git-dir >/dev/null 2>&1; then
  fail '/workspaces must not itself belong to a Git repository.'
fi

# Serialize this script's operations on the same target. Never remove a stale
# lock automatically: another synchronization may still own it.
lock_dir="${target_dir}.sync-lock"
mkdir -- "$lock_dir" 2>/dev/null || fail "Cannot acquire synchronization lock: $lock_dir"
staging_dir=''
cleanup() {
  local result=$?
  trap - EXIT
  if [[ -n "$staging_dir" && -d "$staging_dir" ]]; then
    if ! rmdir -- "$staging_dir" 2>/dev/null; then
      printf 'Temporary checkout retained for inspection: %s\n' "$staging_dir" >&2
    fi
  fi
  rmdir -- "$lock_dir" 2>/dev/null ||
    printf 'Could not remove the synchronization lock: %s\n' "$lock_dir" >&2
  exit "$result"
}
trap cleanup EXIT

assert_repository() {
  local checkout=$1 actual_root actual_url
  [[ -d "$checkout" && ! -L "$checkout" ]] || fail 'The target is not a regular directory.'
  [[ -d "$checkout/.git" && ! -L "$checkout/.git" ]] ||
    fail 'The target must contain its own .git directory; linked worktrees are not supported.'
  actual_root=$(git -C "$checkout" rev-parse --show-toplevel) || fail 'Cannot read the target Git root.'
  [[ "$actual_root" == "$checkout" ]] || fail 'The target is not the root of its own Git working tree.'
  actual_url=$(git -C "$checkout" remote get-url origin) || fail 'The target has no origin remote.'
  [[ "$actual_url" == "$repo_url" ]] || fail 'The target origin URL differs from the requested repository URL.'
}

assert_clean() {
  local checkout=$1 state status
  for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG rebase-apply rebase-merge sequencer; do
    [[ ! -e "$checkout/.git/$state" ]] || fail "An unfinished Git operation exists: $state"
  done
  status=$(git -C "$checkout" status --porcelain=v1 --untracked-files=all) || fail 'Cannot inspect the container working tree.'
  [[ -z "$status" ]] || fail 'The container working tree has tracked or untracked changes. Preserve or commit them before synchronizing.'
}

if [[ ! -e "$target_dir" ]]; then
  staging_dir=$(mktemp -d /workspaces/.xv6-sync.XXXXXXXX) || fail 'Cannot create a temporary checkout directory.'
  staging_checkout="$staging_dir/repository"
  git clone --origin origin --branch "$branch" --single-branch -- "$repo_url" "$staging_checkout" ||
    fail 'Clone failed; the requested target was not installed.'
  assert_repository "$staging_checkout"
  assert_clean "$staging_checkout"
  actual_head=$(git -C "$staging_checkout" rev-parse --verify HEAD) || fail 'Cannot read the cloned HEAD.'
  [[ "$actual_head" == "$expected_head" ]] ||
    fail 'The remote branch does not match the local commit. Push the selected local branch first, then retry.'
  [[ ! -e "$target_dir" && ! -L "$target_dir" ]] || fail 'The target appeared while cloning; refusing to overwrite it.'
  # --no-clobber also protects against a target appearing after the check.
  mv --no-clobber --no-target-directory -- "$staging_checkout" "$target_dir"
  [[ ! -e "$staging_checkout" ]] || fail 'The target appeared while installing the checkout; nothing was overwritten.'
else
  assert_repository "$target_dir"
  assert_clean "$target_dir"

  # An empty refmap disables origin's default +refs/heads/* mapping. Fetch only
  # the selected branch into FETCH_HEAD; do not force or prune any saved refs.
  git -C "$target_dir" fetch --no-tags --no-prune --no-recurse-submodules --refmap= origin "refs/heads/$branch" ||
    fail 'Fetch failed; the container working tree was not updated.'
  fetched_head=$(git -C "$target_dir" rev-parse --verify 'FETCH_HEAD^{commit}') || fail 'Cannot resolve the fetched commit.'
  [[ "$fetched_head" == "$expected_head" ]] ||
    fail 'The remote branch does not match the local commit. Push the selected local branch first, then retry.'

  if git -C "$target_dir" show-ref --verify --quiet "refs/heads/$branch"; then
    branch_head=$(git -C "$target_dir" rev-parse --verify "refs/heads/$branch")
    git -C "$target_dir" merge-base --is-ancestor "$branch_head" "$fetched_head" ||
      fail 'The container branch is ahead of or has diverged from the requested commit. Its commits were preserved.'
    # The trailing -- disambiguates a branch from a path. Refuse to overwrite
    # ignored build files if a branch introduces tracked files at those paths.
    git -C "$target_dir" checkout --no-overwrite-ignore "$branch" --
    git -C "$target_dir" merge --ff-only --no-edit --no-overwrite-ignore FETCH_HEAD
  else
    git -C "$target_dir" checkout --no-overwrite-ignore -b "$branch" FETCH_HEAD --
  fi
fi

assert_repository "$target_dir"
assert_clean "$target_dir"
actual_branch=$(git -C "$target_dir" symbolic-ref --quiet --short HEAD) || fail 'The container checkout is detached.'
actual_head=$(git -C "$target_dir" rev-parse --verify HEAD) || fail 'Cannot read the final container HEAD.'
[[ "$actual_branch" == "$branch" && "$actual_head" == "$expected_head" ]] ||
  fail 'The final container branch or HEAD differs from the requested state.'
printf 'Synchronized %s at %s in %s\n' "$branch" "$actual_head" "$target_dir"
