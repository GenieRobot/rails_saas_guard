#!/usr/bin/env bash
set -euo pipefail
echo "Rails SaaS Guard host verification"
grep -q '^VERSION_ID="24.04"$' /etc/os-release && echo "PASS Ubuntu 24.04" || echo "WARN untested OS"
command -v fail2ban-client >/dev/null && sudo fail2ban-client status rails-saas-guard-php || echo "INFO fail2ban module not installed"
command -v ufw >/dev/null && sudo ufw status verbose || echo "INFO UFW not installed"
command -v nginx >/dev/null && sudo nginx -t || echo "INFO Nginx not installed"
sudo sshd -t && echo "PASS SSH configuration"
