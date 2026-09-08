#!/usr/bin/env bash
# Run in the existing Linux lab container; only disposable test paths are used.
set -euo pipefail
sync_script=$(realpath "${1:?Pass the path to container-sync.sh}")
run_script=$(realpath "${2:?Pass the path to container-run.sh}")
scratch=$(mktemp -d /tmp/xv6-workflow-test.XXXXXXXX)
target="/workspaces/xv6-test-${scratch##*.}"
cleanup() {
  case "$scratch" in /tmp/xv6-workflow-test.*) rm -rf -- "$scratch" ;; esac
  case "$target" in /workspaces/xv6-test-*) rm -rf -- "$target" "${target}-occupied" "${target}-link" ;; esac
}
trap cleanup EXIT
expect_failure() {
  if "$@" >"$scratch/failure.log" 2>&1; then
    echo 'ERROR: operation unexpectedly succeeded' >&2; exit 1
  fi
  cat "$scratch/failure.log"
}
git init --bare "$scratch/remote.git" >/dev/null
git init "$scratch/local" >/dev/null
git -C "$scratch/local" config user.name 'Workflow Test'
git -C "$scratch/local" config user.email 'workflow-test@example.invalid'
git -C "$scratch/local" checkout -b util
printf 'baseline\n' >"$scratch/local/source.txt"
git -C "$scratch/local" add .
git -C "$scratch/local" commit -m baseline >/dev/null
git -C "$scratch/local" remote add origin "$scratch/remote.git"
git -C "$scratch/local" push origin util >/dev/null
first=$(git -C "$scratch/local" rev-parse HEAD)
bash "$sync_script" "$scratch/remote.git" util "$target" "$first"
bash "$sync_script" "$scratch/remote.git" util "$target" "$first"
printf 'PASS: initial clone and repeat sync\n'

printf 'uncommitted\n' >>"$target/source.txt"
expect_failure bash "$sync_script" "$scratch/remote.git" util "$target" "$first"
git -C "$target" checkout -- source.txt
printf 'untracked\n' >"$target/untracked.txt"
expect_failure bash "$sync_script" "$scratch/remote.git" util "$target" "$first"
rm -- "$target/untracked.txt"
expect_failure bash "$sync_script" "$scratch/wrong.git" util "$target" "$first"
printf 'PASS: dirty tree, untracked file and wrong origin refused\n'

printf 'update\n' >>"$scratch/local/source.txt"
git -C "$scratch/local" commit -am update >/dev/null
second=$(git -C "$scratch/local" rev-parse HEAD)
git -C "$scratch/local" push origin util >/dev/null
expect_failure bash "$sync_script" "$scratch/remote.git" util "$target" "$first"
[[ "$(git -C "$target" rev-parse HEAD)" == "$first" ]]
bash "$sync_script" "$scratch/remote.git" util "$target" "$second"
[[ "$(git -C "$target" rev-parse refs/remotes/origin/util)" == "$second" ]]
printf 'PASS: SHA mismatch refused and fast-forward succeeds\n'

git -C "$scratch/local" checkout -b lab/syscall "$first"
printf 'syscall\n' >"$scratch/local/lab.txt"
git -C "$scratch/local" add .
git -C "$scratch/local" commit -m syscall >/dev/null
lab=$(git -C "$scratch/local" rev-parse HEAD)
git -C "$scratch/local" push origin lab/syscall >/dev/null
bash "$sync_script" "$scratch/remote.git" lab/syscall "$target" "$lab"
bash "$sync_script" "$scratch/remote.git" util "$target" "$second"
printf 'PASS: experiment branch switch and return\n'

git -C "$target" -c user.name=Test -c user.email=test@example.invalid commit --allow-empty -m container-only >/dev/null
ahead=$(git -C "$target" rev-parse HEAD)
expect_failure bash "$sync_script" "$scratch/remote.git" util "$target" "$second"
[[ "$(git -C "$target" rev-parse HEAD)" == "$ahead" ]]
expect_failure bash "$run_script" "$target" "$second" util "$scratch/remote.git" build 0
printf 'PASS: container-only commits preserved and stale run refused\n'

mkdir "${target}-occupied"
printf 'keep\n' >"${target}-occupied/keep.txt"
expect_failure bash "$sync_script" "$scratch/remote.git" util "${target}-occupied" "$second"
[[ "$(cat "${target}-occupied/keep.txt")" == keep ]]
ln -s "$target" "${target}-link"
expect_failure bash "$sync_script" "$scratch/remote.git" util "${target}-link" "$second"
expect_failure bash "$sync_script" "$scratch/remote.git" util /root/xv6-labs-2021 "$second"
printf 'PASS: occupied directory, symlink and original lab directory refused\n'
printf 'ALL SYNC SMOKE TESTS PASSED\n'
