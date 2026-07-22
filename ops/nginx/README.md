# Nginx snippet

Review `/etc/nginx/snippets/rails_saas_guard.conf`, then add `include snippets/rails_saas_guard.conf;` inside the relevant `server` block. Run `sudo nginx -t` before `sudo systemctl reload nginx`. It is deliberately not included or reloaded automatically.
