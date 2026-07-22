# Roadmap

## Optional prompt-injection protection

Prompt-injection controls are intentionally outside the v0.1 Rack baseline and will remain optional. A later integration may provide bounded request-size checks, structured separation of instructions and untrusted content, configurable high-risk pattern signals, tool allowlists, output validation hooks, and security events for AI endpoints. Pattern matching alone must never be marketed as complete prompt-injection prevention.

The threat-intelligence workflow has a separate prompt-injection boundary: feeds, advisories, webpages, issue text, and vulnerability descriptions are untrusted data. Automation must never follow instructions contained in source material, expose secrets, change its own policy, execute copied commands, merge changes, or publish releases. Candidate information is normalized into data fields, assessed against the repository, tested, and reviewed by a maintainer.

## Optional Rails application firewall

Evaluate a broader, Wordfence-style Rails application firewall only after the smaller security baseline has deployment evidence and independent review. The evaluation should compare established products and separate application-layer controls from edge/network capabilities. Candidate features include versioned rule packs, bounded request canonicalization, exploit-signature detection, upload and content-type controls, anomaly signals, temporary bans, an administrative event view, safe rule updates, and tested false-positive recovery.

Proceed only if the evaluation shows that Rails-specific context creates meaningful value beyond Rack::Attack, Nginx, CDN, and managed-WAF controls. Any future firewall must remain optional, must not claim volumetric DDoS or TLS-layer protection, must treat remotely sourced rules as untrusted signed data, and must provide preview, staged rollout, observability, rollback, and per-rule disablement.

## Later compatibility work

- Additional Ubuntu and Debian releases through contributor-maintained templates.
- Kamal and Thruster-specific deployment verification.
- Cloud-init and Ansible examples.
- Redis and Solid Cache contract suites.
- Cloudflare and common load-balancer proxy fixtures.
- Optional provider-aware webhook adapters.
