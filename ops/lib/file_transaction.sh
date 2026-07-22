#!/usr/bin/env bash

# The caller sets RSG_PRIVILEGE=(sudo) for system changes or leaves it empty for
# isolated tests. It also provides backup_dir and CHANGED_TARGETS.
RSG_PRIVILEGE=("${RSG_PRIVILEGE[@]:-}")

rsg_exec() {
  if [[ ${#RSG_PRIVILEGE[@]} -gt 0 && -n "${RSG_PRIVILEGE[0]}" ]]; then
    "${RSG_PRIVILEGE[@]}" "$@"
  else
    "$@"
  fi
}

rsg_restore_changes() {
  local index target saved
  for ((index=${#CHANGED_TARGETS[@]} - 1; index >= 0; index--)); do
    target="${CHANGED_TARGETS[$index]}"
    saved="$backup_dir$target"
    if rsg_exec test -e "$saved"; then
      rsg_exec rm -f -- "$target"
      rsg_exec cp -a --reflink=auto -- "$saved" "$target"
    else
      rsg_exec rm -f -- "$target"
    fi
  done
}

rsg_backup_and_install() {
  local source="$1" target="$2"
  local target_dir reference staging
  local mode owner group state="created" before_sha="-" after_sha
  [[ -f "$source" ]] || { echo "source file missing: $source" >&2; return 1; }
  target_dir="$(dirname -- "$target")"

  if rsg_exec test -e "$target"; then
    owner="$(rsg_exec stat -c %u "$target")"
    group="$(rsg_exec stat -c %g "$target")"
    mode="$(rsg_exec stat -c %a "$target")"
    rsg_exec install -d -m 0700 "$(dirname "$backup_dir$target")"
    rsg_exec cp -a --reflink=auto -- "$target" "$backup_dir$target"
    before_sha="$(rsg_exec sha256sum "$target" | awk '{print $1}')"
    state="replaced"
    staging="$(rsg_exec mktemp --tmpdir="$target_dir" ".rails-saas-guard.$(basename -- "$target").XXXXXX")"
    rsg_exec rm -f -- "$staging"
    rsg_exec cp -a --reflink=auto -- "$target" "$staging"
  else
    rsg_exec install -d "$target_dir"
    reference="$(rsg_exec find "$target_dir" -maxdepth 1 -type f -print -quit)"
    if [[ -n "$reference" ]]; then
      owner="$(rsg_exec stat -c %u "$reference")"
      group="$(rsg_exec stat -c %g "$reference")"
      mode="$(rsg_exec stat -c %a "$reference")"
    else
      owner="$(rsg_exec stat -c %u "$target_dir")"
      group="$(rsg_exec stat -c %g "$target_dir")"
      directory_mode="$(rsg_exec stat -c %a "$target_dir")"
      # Derive a non-executable file mode from the host directory policy.
      mode="$(printf '%04o' "$((8#$directory_mode & 8#666))")"
    fi
    staging="$(rsg_exec mktemp --tmpdir="$target_dir" ".rails-saas-guard.$(basename -- "$target").XXXXXX")"
    rsg_exec chown "$owner:$group" "$staging"
    rsg_exec chmod "$mode" "$staging"
  fi

  CHANGED_TARGETS+=("$target")
  rsg_exec dd if="$source" of="$staging" status=none
  rsg_exec sync -f "$staging"
  rsg_exec mv -f -- "$staging" "$target"
  after_sha="$(rsg_exec sha256sum "$target" | awk '{print $1}')"
  printf '%s\t%s\t%s:%s\t%s\t%s\t%s\n' "$state" "$target" "$owner" "$group" "$mode" "$before_sha" "$after_sha" | rsg_exec tee -a "$backup_dir/manifest.tsv" >/dev/null
}
