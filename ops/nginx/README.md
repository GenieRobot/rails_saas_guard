# Nginx snippet

Review `/etc/nginx/snippets/rails_shield.conf`, then add `include snippets/rails_shield.conf;` inside the relevant `server` block. Run `sudo nginx -t` before `sudo systemctl reload nginx`. It is deliberately not included or reloaded automatically.
