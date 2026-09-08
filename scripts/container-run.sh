#!/usr/bin/env bash
set -euo pipefail
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $# -eq 6 ]] || fail 'Expected directory, commit, branch, URL, target and clean flag.'
target=$1
expected=$2
branch=$3
url=$4
action=$5
clean=$6
[[ "$target" =~ ^/workspaces/[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'Invalid checkout path.'
[[ "$action" =~ ^(qemu|grade|build|shell)$ && "$clean" =~ ^[01]$ ]] || fail 'Invalid run options.'
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR
[[ "$(realpath -m -- "$target")" == "$target" ]] || fail 'Container path contains symlinks.'
cd -- "$target"
[[ -d .git && ! -L .git ]] || fail 'The checkout must have its own .git directory.'
[[ "$(git rev-parse --show-toplevel)" == "$target" ]] || fail 'Invalid Git root.'
[[ "$(git rev-parse HEAD)" == "$expected" ]] || fail 'Container commit differs. Run pull.ps1 first.'
[[ "$(git symbolic-ref --short HEAD)" == "$branch" ]] || fail 'Container branch differs. Run pull.ps1 first.'
[[ "$(git remote get-url origin)" == "$url" ]] || fail 'Container origin differs.'
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || fail 'Container has uncommitted changes.'
for marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer BISECT_START; do
  [[ ! -e "$(git rev-parse --git-path "$marker")" ]] || fail 'Container has an unfinished Git operation.'
done
printf 'Running branch %s at %s\n' "$branch" "$expected"
if [[ "$clean" == 1 ]]; then make clean; fi
case "$action" in
  qemu) exec make qemu ;;
  grade) exec make grade ;;
  build) exec make kernel/kernel fs.img ;;
  shell) exec bash ;;
esac
