#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash -n "$SCRIPT_DIR/install.sh"
bash -n "$SCRIPT_DIR/verify.sh"
bash -n "$SCRIPT_DIR/lib/file_transaction.sh"
"$SCRIPT_DIR/test_file_transaction.sh"
"$SCRIPT_DIR/install.sh" --dry-run --modules fail2ban,nginx,ufw,ssh >/dev/null
if command -v fail2ban-regex >/dev/null; then
  output="$(fail2ban-regex "$SCRIPT_DIR/fixtures/nginx-access.log" "$SCRIPT_DIR/fail2ban/filter.d/rails-saas-guard-php.conf")"
  grep -Eq 'Lines: 3 lines, 0 ignored, 2 matched, 1 missed' <<< "$output"
else
  echo "SKIP fail2ban-regex is not installed" >&2
fi
echo "Operations checks passed"
