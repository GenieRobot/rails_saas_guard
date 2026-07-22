#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
target="$test_root/etc/example.conf"
source_file="$test_root/replacement.conf"
backup_dir="$test_root/backups"
declare -a CHANGED_TARGETS=()
RSG_PRIVILEGE=()
mkdir -p "$(dirname "$target")" "$backup_dir"
touch "$backup_dir/manifest.tsv"
printf 'original\n' > "$target"
printf 'replacement\n' > "$source_file"
chmod 0640 "$target"

if command -v setfattr >/dev/null; then setfattr -n user.rails_saas_guard_test -v preserved "$target"; fi
if command -v setfacl >/dev/null; then setfacl -m "u:$(id -u):rw" "$target"; fi

# shellcheck source=lib/file_transaction.sh
source "$SCRIPT_DIR/lib/file_transaction.sh"
before_stat="$(stat -c '%u:%g:%a' "$target")"
rsg_backup_and_install "$source_file" "$target"
[[ "$(cat "$target")" == "replacement" ]]
[[ "$(stat -c '%u:%g:%a' "$target")" == "$before_stat" ]]
if command -v getfattr >/dev/null; then
  [[ "$(getfattr --only-values -n user.rails_saas_guard_test "$target")" == "preserved" ]]
fi

printf 'damaged\n' > "$target"
rsg_restore_changes
[[ "$(cat "$target")" == "original" ]]
[[ "$(stat -c '%u:%g:%a' "$target")" == "$before_stat" ]]
if command -v getfattr >/dev/null; then
  [[ "$(getfattr --only-values -n user.rails_saas_guard_test "$target")" == "preserved" ]]
fi
grep -q $'^replaced\t' "$backup_dir/manifest.tsv"
echo "File transaction checks passed"
