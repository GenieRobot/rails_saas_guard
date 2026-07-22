#!/usr/bin/env bash
set -euo pipefail

YES=0
DRY_RUN=0
MODULES="fail2ban,nginx"
BACKUP_ROOT="/var/backups/rails-saas-guard"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: ./ops/install.sh [--dry-run] [-y|--yes] [--modules fail2ban,nginx,ufw,ssh]"
}

while (($#)); do
  case "$1" in
    -y|--yes) YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --modules) shift; MODULES="${1:?--modules requires a comma-separated value}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ ! -r /etc/os-release ]] || ! grep -q '^ID=ubuntu$' /etc/os-release || ! grep -q '^VERSION_ID="24.04"$' /etc/os-release; then
  echo "Unsupported host: v0.1 supports Ubuntu 24.04 LTS only." >&2
  exit 1
fi
if [[ $EUID -eq 0 ]]; then
  echo "Run as a normal sudo-capable user, not as root." >&2
  exit 1
fi

IFS=',' read -r -a selected <<< "$MODULES"
valid_module() { [[ "$1" =~ ^(fail2ban|nginx|ufw|ssh)$ ]]; }
for module in "${selected[@]}"; do valid_module "$module" || { echo "Unknown module: $module" >&2; exit 2; }; done

echo "Rails SaaS Guard operations plan"
echo "  Host: Ubuntu 24.04 LTS"
echo "  Modules: ${MODULES}"
echo "  Backups: ${BACKUP_ROOT}/<timestamp>/"
echo
echo "Planned privileged actions:"
for module in "${selected[@]}"; do
  case "$module" in
    fail2ban) echo "  - Install fail2ban package, filter, and jail; validate and reload fail2ban" ;;
    nginx) echo "  - Install an optional Nginx security snippet; validate Nginx (no automatic include)" ;;
    ufw) echo "  - Allow OpenSSH, HTTP, and HTTPS; enable UFW after showing status" ;;
    ssh) echo "  - Install SSH hardening drop-in after confirming this user has authorized keys" ;;
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
backup_dir="${BACKUP_ROOT}/${timestamp}"
sudo install -d -m 0700 "$backup_dir"

backup_and_install() {
  local source="$1" target="$2" mode="${3:-0644}"
  if sudo test -e "$target"; then
    sudo cp -a "$target" "$backup_dir/$(basename "$target")"
  fi
  sudo install -D -m "$mode" "$source" "$target"
}

for module in "${selected[@]}"; do
  case "$module" in
    fail2ban)
      sudo apt-get update
      sudo apt-get install -y fail2ban
      backup_and_install "$SCRIPT_DIR/fail2ban/filter.d/rails-saas-guard-php.conf" /etc/fail2ban/filter.d/rails-saas-guard-php.conf
      backup_and_install "$SCRIPT_DIR/fail2ban/jail.d/rails-saas-guard.local" /etc/fail2ban/jail.d/rails-saas-guard.local
      sudo fail2ban-client -t
      sudo systemctl enable --now fail2ban
      sudo systemctl reload fail2ban
      ;;
    nginx)
      command -v nginx >/dev/null || { echo "Nginx is not installed; skipping nginx module." >&2; continue; }
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
      [[ -s "$HOME/.ssh/authorized_keys" ]] || { echo "Refusing SSH hardening: $HOME/.ssh/authorized_keys is missing or empty." >&2; exit 1; }
      backup_and_install "$SCRIPT_DIR/ssh/99-rails-saas-guard.conf" /etc/ssh/sshd_config.d/99-rails-saas-guard.conf
      sudo sshd -t
      sudo systemctl reload ssh
      ;;
  esac
done

echo "Installation complete. Backups: $backup_dir"
echo "Verify with: ./ops/verify.sh"
