#!/bin/sh
# Every case is run against a real daukle, because this plugin's output is a
# real compiler's, and a stub of daukle.exec would be testing the stub.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work="$root/test/.work"

daukle=${DAUKLE:-}
if [ -z "$daukle" ]; then
  for candidate in \
    "$root/.daukle/build/daukle" \
    "$root/.daukle/build/daukle.exe" \
    "$root/.daukle/build/Release/daukle.exe" \
    "$root/.daukle/build/Debug/daukle.exe"
  do
    [ -x "$candidate" ] && daukle=$candidate && break
  done
fi
if [ -z "$daukle" ] || [ ! -x "$daukle" ]; then
  echo "no daukle binary: set DAUKLE, or check out daukle/daukle into .daukle and build it" >&2
  exit 1
fi

passed=0
failed=0
skipped=0

fail() {
  echo "FAIL $1: $2" >&2
  failed=$((failed + 1))
}

# This plugin is multi-file, so the whole plugin directory is staged rather
# than the single plugin.lua the other repositories copy.
stage_plugin() {
  mkdir -p "$1/plugins/c"
  cp "$root/plugin.lua" "$1/plugins/c/plugin.lua"
  cp -R "$root/lib" "$1/plugins/c/lib"
}

# Every non-empty line of the file is one clause, all of which must be present
# when wanted is 1 and absent when it is 0. A multi-clause file is what lets a
# case assert that a message was ADDED TO rather than replaced.
assert_clauses() {
  clause_file=$1
  wanted=$2
  if [ ! -f "$clause_file" ]; then
    fail "$label" "$(basename "$clause_file") is missing, so this case asserts nothing"
    return 1
  fi
  any=0
  while IFS= read -r clause || [ -n "$clause" ]; do
    [ -z "$clause" ] && continue
    any=1
    if grep -qF "$clause" "$sandbox/stderr.txt" "$sandbox/stdout.txt"; then
      if [ "$wanted" -eq 0 ]; then
        fail "$label" "message carries what it must not: $clause"
        return 1
      fi
    elif [ "$wanted" -eq 1 ]; then
      fail "$label" "message does not carry: $clause"
      sed -n '1,40p' "$sandbox/stderr.txt" >&2
      return 1
    fi
  done < "$clause_file"
  if [ "$any" -eq 0 ]; then
    fail "$label" "the clause file is empty, so this case asserts nothing"
    return 1
  fi
  return 0
}

# Windows names an executable .exe and a manifest's "output" does not, so a
# case naming the produced binary names it without the suffix and both
# spellings are accepted here.
resolve_executable() {
  if [ -f "$1" ]; then echo "$1"; return 0; fi
  if [ -f "$1.exe" ]; then echo "$1.exe"; return 0; fi
  return 1
}

run_error_case() {
  if (cd "$sandbox" && "$daukle" sync "$manifest_name" >stdout.txt 2>stderr.txt); then
    fail "$label" "expected a failure, got success"
    return 1
  fi
  assert_clauses "$case_dir/expect-error.txt" 1
}

run_task_error_case() {
  if (cd "$sandbox" && "$daukle" "$task" >stdout.txt 2>stderr.txt); then
    fail "$label" "expected task $task to fail, got success"
    return 1
  fi
  assert_clauses "$case_dir/expect-task-error.txt" 1 || return 1
  # Without this half, a plugin that appends its host-prerequisite sentence to
  # every failing compile passes every case above it.
  if [ -f "$case_dir/expect-task-absent.txt" ]; then
    assert_clauses "$case_dir/expect-task-absent.txt" 0 || return 1
  fi
  return 0
}

run_task_case() {
  if ! (cd "$sandbox" && "$daukle" "$task" >stdout.txt 2>stderr.txt); then
    fail "$label" "task $task failed"
    sed -n '1,40p' "$sandbox/stderr.txt" >&2
    return 1
  fi
  if [ ! -f "$case_dir/produces.txt" ] || ! grep -q . "$case_dir/produces.txt"; then
    fail "$label" "produces.txt is missing or lists nothing, so this case asserts nothing"
    return 1
  fi
  while IFS= read -r produced || [ -n "$produced" ]; do
    [ -z "$produced" ] && continue
    if [ ! -s "$sandbox/$produced" ]; then
      fail "$label" "$produced is missing or empty"
      return 1
    fi
  done < "$case_dir/produces.txt"
  [ -f "$case_dir/runs.txt" ] || return 0
  # There is no c:run, so a case that wants to prove the link produced a
  # working program runs the program itself.
  if ! executable=$(resolve_executable "$sandbox/$(cat "$case_dir/runs.txt")"); then
    fail "$label" "$(cat "$case_dir/runs.txt") was not linked"
    return 1
  fi
  if ! "$executable" >"$sandbox/stdout.txt" 2>"$sandbox/stderr.txt"; then
    fail "$label" "the linked program failed to run"
    sed -n '1,20p' "$sandbox/stderr.txt" >&2
    return 1
  fi
  assert_clauses "$case_dir/expect-output.txt" 1
}

compare_expected() {
  expected_root=$case_dir/expected
  # An empty expected/ would compare nothing and pass, which is the one way a
  # case can look green while asserting nothing at all.
  if [ -z "$(cd "$expected_root" && find . -type f)" ]; then
    fail "$1" "expected/ holds no files, so this case asserts nothing"
    return 1
  fi
  ok=0
  for expected in $(cd "$expected_root" && find . -type f); do
    if ! cmp -s "$expected_root/$expected" "$sandbox/$expected"; then
      fail "$1" "$expected differs"
      diff -u "$expected_root/$expected" "$sandbox/$expected" >&2 || true
      ok=1
    fi
  done
  return $ok
}

run_sync_case() {
  # Twice, because applying twice must equal applying once for every case,
  # not only for the one a test remembered to say it about.
  if ! (cd "$sandbox" && "$daukle" sync "$manifest_name" >stdout.txt 2>stderr.txt); then
    fail "$label" "sync failed"
    sed -n '1,40p' "$sandbox/stderr.txt" >&2
    return 1
  fi
  compare_expected "$label (first)" || return 1
  if ! (cd "$sandbox" && "$daukle" sync "$manifest_name" >stdout.txt 2>stderr.txt); then
    fail "$label" "second sync failed"
    return 1
  fi
  compare_expected "$label (second)" || return 1
}

run_case() {
  case_dir=$1
  name=$(basename "$case_dir")

  for manifest in "$case_dir"/daukle*.toml; do
    manifest_name=$(basename "$manifest")
    label="$name/$manifest_name"

    # A clang archive is a quarter of a gigabyte on Linux and half of one on
    # Windows, which no local run should pay for unasked. CI sets the variable
    # on every runner, because the per-platform archives and the per-host flag
    # table are exercised by nothing else.
    if [ -f "$case_dir/needs-clang" ] && [ "${DAUKLE_C_E2E:-}" != "1" ]; then
      echo "skip $label: set DAUKLE_C_E2E=1 to run it here" >&2
      skipped=$((skipped + 1))
      continue
    fi

    sandbox="$work/$name-$manifest_name"
    rm -rf "$sandbox"
    mkdir -p "$(dirname "$sandbox")"
    cp -R "$case_dir" "$sandbox"
    rm -rf "$sandbox/expected" "$sandbox/expect-error.txt" "$sandbox/task.txt" \
           "$sandbox/produces.txt" "$sandbox/expect-task-error.txt" \
           "$sandbox/expect-task-absent.txt" "$sandbox/expect-output.txt" \
           "$sandbox/runs.txt" "$sandbox/needs-clang"
    stage_plugin "$sandbox"

    if [ -f "$case_dir/expect-error.txt" ]; then
      run_error_case && passed=$((passed + 1))
      continue
    fi

    if [ -f "$case_dir/task.txt" ]; then
      if [ "$manifest_name" != "daukle.toml" ]; then
        fail "$label" "a task case's manifest must be daukle.toml"
        continue
      fi
      task=$(cat "$case_dir/task.txt")
      if [ -f "$case_dir/expect-task-error.txt" ] && [ -f "$case_dir/produces.txt" ]; then
        fail "$label" "a case carries both expect-task-error.txt and produces.txt; they are mutually exclusive"
        continue
      fi
      if [ -f "$case_dir/expect-task-error.txt" ]; then
        run_task_error_case && passed=$((passed + 1))
        continue
      fi
      run_task_case && passed=$((passed + 1))
      continue
    fi

    run_sync_case && passed=$((passed + 1))
  done
  # A failing case must not end this function on a non-zero status: set -e
  # would then take a single red case for a broken runner and stop the suite.
  return 0
}

rm -rf "$work"
for case_dir in "$root"/test/cases/*/; do
  [ -d "$case_dir" ] || continue
  run_case "${case_dir%/}"
done

echo "$passed passed, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
