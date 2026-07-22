#!/usr/bin/env bash
set -eEuo pipefail

YES=0
DRY_RUN=0
MODULES="fail2ban,nginx"
BACKUP_ROOT="/var/backups/rails-saas-guard"
FAIL2BAN_LOGPATH="/var/log/nginx/access.log"
FAIL2BAN_FINDTIME="10m"
FAIL2BAN_MAXRETRY="5"
FAIL2BAN_BANTIME="1h"
FAIL2BAN_IGNOREIP="127.0.0.1/8 ::1"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
declare -a CHANGED_TARGETS=()
backup_dir=""
ROLLBACK_ACTIVE=0
RSG_PRIVILEGE=(sudo)
# shellcheck source=lib/file_transaction.sh
source "$SCRIPT_DIR/lib/file_transaction.sh"

usage() {
  cat <<'USAGE'
Usage: ./ops/install.sh [options]
  --dry-run                       Preview without sudo or changes
  -y, --yes                       Apply without confirmation
  --modules LIST                  fail2ban,nginx,ufw,ssh
  --fail2ban-logpath PATH         Nginx access log path
  --fail2ban-findtime DURATION    Default: 10m
  --fail2ban-maxretry COUNT       Default: 5
  --fail2ban-bantime DURATION     Default: 1h
  --fail2ban-ignoreip LIST        Space-separated trusted CIDRs
USAGE
}

die() { echo "ERROR: $*" >&2; return 1; }
valid_duration() { [[ "$1" =~ ^[1-9][0-9]*[smhdw]?$ ]]; }

while (($#)); do
  case "$1" in
    -y|--yes) YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --modules) shift; MODULES="${1:?--modules requires a value}" ;;
    --fail2ban-logpath) shift; FAIL2BAN_LOGPATH="${1:?missing path}" ;;
    --fail2ban-findtime) shift; FAIL2BAN_FINDTIME="${1:?missing duration}" ;;
    --fail2ban-maxretry) shift; FAIL2BAN_MAXRETRY="${1:?missing count}" ;;
    --fail2ban-bantime) shift; FAIL2BAN_BANTIME="${1:?missing duration}" ;;
    --fail2ban-ignoreip) shift; FAIL2BAN_IGNOREIP="${1:?missing list}" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

[[ -r /etc/os-release ]] || die "cannot identify operating system"
grep -q '^ID=ubuntu$' /etc/os-release && grep -q '^VERSION_ID="24.04"$' /etc/os-release || die "v0.1 supports Ubuntu 24.04 LTS only"
[[ $EUID -ne 0 ]] || die "run as a normal sudo-capable user, not root"
[[ "$FAIL2BAN_LOGPATH" == /* && "$FAIL2BAN_LOGPATH" != *$'\n'* ]] || die "fail2ban log path must be an absolute single-line path"
valid_duration "$FAIL2BAN_FINDTIME" || die "invalid fail2ban findtime"
valid_duration "$FAIL2BAN_BANTIME" || die "invalid fail2ban bantime"
[[ "$FAIL2BAN_MAXRETRY" =~ ^[1-9][0-9]*$ ]] || die "invalid fail2ban maxretry"
[[ "$FAIL2BAN_IGNOREIP" =~ ^[0-9a-fA-F:./[:space:]]+$ ]] || die "invalid fail2ban ignoreip list"

IFS=',' read -r -a selected <<< "$MODULES"
for module in "${selected[@]}"; do
  [[ "$module" =~ ^(fail2ban|nginx|ufw|ssh)$ ]] || die "unknown module: $module"
done

echo "Rails SaaS Guard operations plan"
echo "  Host: Ubuntu 24.04 LTS"
echo "  Modules: $MODULES"
echo "  Backups: $BACKUP_ROOT/<timestamp>/"
for module in "${selected[@]}"; do
  case "$module" in
    fail2ban)
      echo "  - Configure fail2ban: log=$FAIL2BAN_LOGPATH, findtime=$FAIL2BAN_FINDTIME, maxretry=$FAIL2BAN_MAXRETRY, bantime=$FAIL2BAN_BANTIME"
      ;;
    nginx) echo "  - Install optional Nginx snippet and validate Nginx; do not include or reload it" ;;
    ufw) echo "  - Allow OpenSSH, HTTP, and HTTPS, then enable UFW" ;;
    ssh) echo "  - Install SSH hardening after verifying authorized_keys" ;;
  esac
done

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run complete; no sudo authentication or host changes performed."
  exit 0
fi
if [[ $YES -ne 1 ]]; then
  read -r -p "Apply this plan? Type 'yes' to continue: " answer
  [[ "$answer" == "yes" ]] || { echo "Cancelled."; exit 0; }
fi

sudo -v
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="$BACKUP_ROOT/$timestamp"
sudo install -d -m 0700 "$backup_dir"
sudo touch "$backup_dir/manifest.tsv"
sudo chmod 0600 "$backup_dir/manifest.tsv"

rollback() {
  local exit_code=$?
  [[ $ROLLBACK_ACTIVE -eq 1 ]] || exit "$exit_code"
  trap - ERR
  echo "Installation failed; restoring changed files from $backup_dir" >&2
  rsg_restore_changes
  exit "$exit_code"
}
trap rollback ERR

backup_and_install() {
  rsg_backup_and_install "$@"
}

render_fail2ban_jail() {
  local target="$1"
  sed \
    -e "s|@@LOGPATH@@|$FAIL2BAN_LOGPATH|g" \
    -e "s|@@FINDTIME@@|$FAIL2BAN_FINDTIME|g" \
    -e "s|@@MAXRETRY@@|$FAIL2BAN_MAXRETRY|g" \
    -e "s|@@BANTIME@@|$FAIL2BAN_BANTIME|g" \
    -e "s|@@IGNOREIP@@|$FAIL2BAN_IGNOREIP|g" \
    "$SCRIPT_DIR/fail2ban/jail.d/rails-saas-guard.local" > "$target"
}

ROLLBACK_ACTIVE=1
for module in "${selected[@]}"; do
  case "$module" in
    fail2ban)
      sudo apt-get update
      sudo apt-get install -y fail2ban
      jail_tmp="$(mktemp)"
      trap 'rm -f "${jail_tmp:-}"' EXIT
      render_fail2ban_jail "$jail_tmp"
      fail2ban-regex "$SCRIPT_DIR/fixtures/nginx-access.log" "$SCRIPT_DIR/fail2ban/filter.d/rails-saas-guard-php.conf" --print-all-matched
      backup_and_install "$SCRIPT_DIR/fail2ban/filter.d/rails-saas-guard-php.conf" /etc/fail2ban/filter.d/rails-saas-guard-php.conf
      backup_and_install "$jail_tmp" /etc/fail2ban/jail.d/rails-saas-guard.local
      sudo fail2ban-client -t
      sudo systemctl enable --now fail2ban
      sudo systemctl reload fail2ban
      sudo fail2ban-client status rails-saas-guard-php
      ;;
    nginx)
      command -v nginx >/dev/null || die "Nginx is not installed"
      backup_and_install "$SCRIPT_DIR/nginx/rails_saas_guard.conf" /etc/nginx/snippets/rails_saas_guard.conf
      sudo nginx -t
      echo "Snippet installed but not included automatically. See ops/nginx/README.md."
      ;;
    ufw)
      sudo apt-get update
      sudo apt-get install -y ufw
      sudo ufw status verbose
      sudo ufw allow OpenSSH
      sudo ufw allow 80/tcp
      sudo ufw allow 443/tcp
      sudo ufw --force enable
      ;;
    ssh)
      [[ -s "$HOME/.ssh/authorized_keys" ]] || die "$HOME/.ssh/authorized_keys is missing or empty"
      backup_and_install "$SCRIPT_DIR/ssh/99-rails-saas-guard.conf" /etc/ssh/sshd_config.d/99-rails-saas-guard.conf
      sudo sshd -t
      sudo systemctl reload ssh
      ;;
  esac
done
ROLLBACK_ACTIVE=0
trap - ERR

echo "Installation complete. Backups and manifest: $backup_dir"
echo "Verify with: ./ops/verify.sh"
