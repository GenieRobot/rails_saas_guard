# Rails SaaS Guard

Secure, conservative defaults for production Rails SaaS applications, from request throttling to deployment-level bot protection.

Rails SaaS Guard packages configurable Rack::Attack policies, safe response behavior, testable Rails integration, and explicit Ubuntu operations templates. It is a defense layer—not a WAF, authentication framework, vulnerability scanner, or substitute for timely Rails, Ruby, dependency, proxy, and operating-system updates.

## What v0.1 provides

- General per-client request throttling.
- Devise-style login, password-reset, and signup throttles.
- Login throttling by a keyed hash of normalized email, never the email itself.
- Configurable expensive/API/portal endpoint throttles.
- Keyed hashing for bearer tokens and other sensitive discriminators.
- Case-insensitive blocking of requests for PHP scripts, including bounded common encoding variants.
- Conservative WordPress, repository, environment-file, and admin-tool probe blocking.
- Optional unsupported WebDAV-method blocking.
- HTML and JSON 403/429 responses with `Retry-After` for throttles.
- Ubuntu 24.04 fail2ban, UFW, Nginx, and SSH modules with preview and confirmation.

Aggressive behavior is opt-in. Rails SaaS Guard deliberately does not block all `/admin` or `/.well-known` routes, does not ban clients after a couple of ordinary 404 responses, and does not use user-agent strings as decisive evidence.

## Requirements

- Ruby 3.2 or newer.
- Rack 2.2 or 3.x.
- Rack::Attack 6.7 or newer in the 6.x series.
- Rails is optional for the core Rack integration. The generator and automatic Railtie installation require Rails.
- A shared production cache is required for consistent limits across processes or hosts. Verify atomic increment and expiry behavior for the selected Rack::Attack cache store.

The initial operations installer supports Ubuntu 24.04 LTS only.

## Installation

Add the gem:

```ruby
gem "rails_saas_guard"
```

Then run:

```sh
bundle install
bin/rails generate rails_saas_guard:install
```

The generator writes `config/initializers/rails_saas_guard.rb`. Review it before deployment.

## Five-minute conservative setup

```ruby
RailsSaasGuard.configure do |config|
  config.general_requests limit: 300, period: 5.minutes
  config.devise_defaults!
end
```

The Railtie installs configured policies after Rails initializes. A non-Rails Rack application can configure the gem and call `RailsSaasGuard.install!` explicitly.

Sensitive discriminators require a secret. Rails applications use `secret_key_base` by default. To isolate the keys, use an independent credential:

```ruby
config.discriminator_secret = Rails.application.credentials.rails_saas_guard_secret
```

Outside Rails, set `RAILS_SAAS_GUARD_SECRET` or assign `discriminator_secret` directly. Rotating it resets sensitive throttle buckets.

## Endpoint policies

IP-based expensive endpoint:

```ruby
config.endpoint "ai/ip",
  path: %r{\A/(generate|ai|studio)(?:/|\z)},
  methods: :post,
  limit: 10,
  period: 1.minute
```

Prefer an authenticated account or user dimension for expensive work:

```ruby
config.endpoint "ai/account",
  path: %r{\A/(generate|ai|studio)(?:/|\z)},
  methods: :post,
  limit: 30,
  period: 1.minute,
  discriminator: ->(request) {
    request.env["warden"]&.user&.account_id.to_s
  }
```

Non-IP discriminators are keyed before reaching Rack::Attack. Never put raw bearer tokens, emails, portal tokens, or webhook secrets into policy names, logs, or metrics.

For bearer-token APIs:

```ruby
config.api_prefix "/api/", limit: 60, period: 1.minute
```

Webhook limits should be provider-aware and tolerate legitimate retry bursts. Match the exact webhook path and use a stable provider/account identifier after signature verification where possible.

## PHP and probe blocking

PHP script requests are blocked regardless of filename case. Matching applies to the bounded path only, not arbitrary query-string values, and performs at most two decode passes. Examples blocked include `/index.php`, `/INDEX.PHP`, `/foo.php/bar`, and commonly encoded forms. `/image.php.jpg` and `/search?q=index.php` are not treated as PHP execution probes.

Applications with a legitimate PHP service mounted in the same Rack routing boundary must disable probe blocking or place that service on a separate host:

```ruby
config.block_probe_paths = false
```

The bundled Nginx template can reject PHP before Rails, and fail2ban can impose a temporary network-level ban after repeated rejected requests.

## Unsupported methods

If the application does not use WebDAV, opt in:

```ruby
config.block_webdav_methods!
```

This blocks `PROPFIND`, `PROPPATCH`, `MKCOL`, `COPY`, `MOVE`, `LOCK`, `UNLOCK`, and `SEARCH`. It is off by default to avoid breaking applications that deliberately expose those methods.

## Proxies and client IP

Rate limiting is only as correct as `request.ip`. Configure Rails trusted proxies for the actual Nginx, Thruster, load-balancer, or CDN hops. Never trust forwarded headers from arbitrary clients. Test direct requests, every proxy hop, spoofed `Forwarded`/`X-Forwarded-For`, IPv4, IPv6, and IPv4-mapped IPv6 before enabling strict IP limits.

Cloudflare deployments should accept client-IP headers only from Cloudflare's published network ranges at the edge. Rails SaaS Guard does not silently alter `ActionDispatch::RemoteIp` because the correct trust boundary is deployment-specific.

## Cache behavior

Rack::Attack counters must use a production store shared by every web process and host. Redis is a conventional choice; Solid Cache requires validation of atomic increments, expiry, cleanup, and contention for the deployed version. Decide and document whether unavailable rate-limiting storage should fail open or fail closed. The safer availability default is usually fail open with urgent alerting, while high-risk endpoints may need a different application-level control.

Shared-IP environments such as schools, offices, mobile carriers, and NAT gateways can create false positives. Use account/user dimensions where authentication exists and keep global IP limits conservative.

## Responses and observability

Throttled responses return `429`, `Retry-After`, `Cache-Control: no-store`, and JSON for API requests. Blocked probes return `403`. Browser requests receive a small accessible HTML response.

Do not attach raw identifiers to metrics. Policy names should have bounded cardinality. Sanitize request paths before logging when they can contain application tokens.

## Testing policies

Reset Rack::Attack state between examples, use a deterministic cache store, and test both allowed and rejected requests. Every new probe rule should include:

- A demonstrated malicious request.
- Encoded and malformed variants.
- Boundary and resource-limit tests.
- Legitimate near-match cases.
- Proxy and shared-IP implications.

Run this gem's suite with:

```sh
bundle exec rake
```

## Ubuntu 24.04 operations

Review the complete plan without sudo or changes:

```sh
./ops/install.sh --dry-run --modules fail2ban,nginx,ufw,ssh
```

Apply selected modules interactively:

```sh
./ops/install.sh --modules fail2ban,nginx
```

The script prints its plan and requires typing `yes`. Sudo itself requests the password via `sudo -v`; Rails SaaS Guard never reads or stores it. For deliberate unattended deployment:

```sh
./ops/install.sh --yes --modules fail2ban,nginx
```

The installer backs up replaced files under `/var/backups/rails-saas-guard/<timestamp>/`, validates fail2ban/Nginx/SSH before reloads, and refuses SSH password hardening unless the current user has an `authorized_keys` file. The Nginx snippet is installed but not automatically included or reloaded.

Existing root-owned configuration files retain their original owner, group, and mode. Newly created system configuration files use `root:root 0644`. Full-path backups and a manifest are written before replacement; configuration files changed during a failed run are restored automatically. Package installation and firewall state are reported separately and are not silently removed during file rollback.

Fail2ban is installed with an enabled PHP-probe jail and is configurable at installation time:

```sh
./ops/install.sh --modules fail2ban \
  --fail2ban-logpath /var/log/nginx/access.log \
  --fail2ban-findtime 10m \
  --fail2ban-maxretry 5 \
  --fail2ban-bantime 1h \
  --fail2ban-ignoreip "127.0.0.1/8 ::1"
```

The installer tests the filter against bundled IPv4/IPv6 Nginx fixtures, validates the complete fail2ban configuration, reloads the service, and verifies that the jail is active.

UFW opens OpenSSH, ports 80 and 443 before enabling the firewall. Review cloud firewalls and any additional required ports first. SSH hardening disables password and root login; keep an existing session open and verify a second key-based login before disconnecting.

Verify installed components:

```sh
./ops/verify.sh
```

For a later manual rollback, restore the relevant full-path file from the printed backup directory, validate the service configuration, and reload that service. Keep the generated manifest with deployment records.

## Threat-intelligence maintenance

New rules must be evidence-driven. The maintenance workflow should monitor Rails security announcements, RubySec/GitHub dependency advisories, CISA's Known Exploited Vulnerabilities catalog, and NVD enrichment. Generic security news can provide leads but cannot directly generate blocking behavior.

The safe workflow is: collect → deduplicate → assess Rails/Rack/Ubuntu relevance → reproduce → add assumed-red bypass and false-positive tests → implement → run CI → open a reviewed pull request → prepare release notes → approve and publish. No feed item may autonomously publish a gem or modify consumer applications.

The scheduled GitHub workflow opens a bounded weekly review task and audits Ruby dependencies. External text is always untrusted data. Optional consumer-facing prompt-injection controls and the automation's own prompt-injection boundary are described in [docs/ROADMAP.md](docs/ROADMAP.md).

## Release policy

Behavioral changes that could reject traffic are documented prominently and versioned. Releases require a green compatibility matrix, gem-content inspection, operational dry-run checks, reviewed release notes, and MFA-protected RubyGems publishing. Do not describe the package as “hardened” until independent review and real deployment evidence exist.

## Security reporting

See [SECURITY.md](SECURITY.md). Do not report vulnerabilities publicly before coordinated disclosure.

## License

Apache License 2.0. See [LICENSE.txt](LICENSE.txt).
