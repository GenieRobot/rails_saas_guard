#!/usr/bin/env bash
set -euo pipefail

cd /workspace
sudo ./ops/test_file_transaction.sh
sudo -u tester ./ops/install.sh --yes --modules fail2ban,nginx,ssh \
  --fail2ban-logpath /var/log/nginx/access.log \
  --fail2ban-findtime 10m --fail2ban-maxretry 5 --fail2ban-bantime 1h

sudo nginx -t
sudo sshd -t
sudo fail2ban-client status rails-saas-guard-php

# Prove the installed jail consumes real Nginx log entries and can ban/unban.
attacker_ip="198.51.100.66"
for attempt in 1 2 3 4 5; do
  printf '%s - - [22/Jul/2026:08:10:0%s +0000] "GET /shell%s.php HTTP/1.1" 403 153 "-" "testbed"\n' "$attacker_ip" "$attempt" "$attempt" | sudo tee -a /var/log/nginx/access.log >/dev/null
done
for _ in 1 2 3 4 5; do
  if sudo fail2ban-client status rails-saas-guard-php | grep -q "$attacker_ip"; then break; fi
  sleep 1
done
sudo fail2ban-client status rails-saas-guard-php | grep -q "$attacker_ip"
sudo fail2ban-client set rails-saas-guard-php unbanip "$attacker_ip"

# Firewall is tested last because it changes the disposable target's network.
sudo -u tester ./ops/install.sh --yes --modules ufw
sudo ufw status | grep -q active
echo "Host-control checks passed"
