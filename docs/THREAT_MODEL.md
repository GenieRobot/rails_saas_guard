# Threat model

This document defines the security boundary for Rails Shield 0.1. It is intentionally bounded: the gem is one application-layer control in a defense-in-depth deployment, not a WAF, authentication system, IDS, SIEM, vulnerability scanner, or volumetric DDoS service.

## Protected assets

- Availability of ordinary Rails requests and explicitly classified expensive endpoints.
- Authentication and recovery endpoints exposed through configurable route adapters.
- Secrets and personal identifiers used to distinguish rate-limit buckets.
- Integrity of generated host configuration and its rollback material.
- Reliable security events without leaking bearer tokens, email addresses, or tokenized paths.

## Trust boundaries

```text
untrusted client
    -> CDN / load balancer (optional)
    -> reviewed reverse proxy
    -> Rack::Attack + Rails Shield
    -> Rails routes, authentication and application code
    -> shared cache store

administrator
    -> reviewed ops preview
    -> explicit sudo authorization
    -> host configuration and services
```

All request bytes, headers, paths, query parameters, bodies, user agents, webhook payloads, threat feeds, advisory text, and issue content are untrusted. Forwarding headers become trustworthy only when Rails is configured with the exact proxies that overwrite them. Cache stores and host files are privileged dependencies, not sanitization boundaries.

## Adversaries and capabilities

The baseline considers unauthenticated scanners, credential-stuffing clients, abusive authenticated users, callers attempting rate-limit evasion, and compromised or misleading threat-intelligence content. They may send malformed encodings, mixed-case or multiply encoded paths, unusual HTTP methods, spoofed forwarding headers, IPv4 or IPv6 traffic, high request concurrency, sensitive values intended to reach logs, and near-matches intended to trigger false positives.

The baseline does not assume an attacker already controls the Rails process, host root account, reverse proxy, cache server, CI secrets, gem-signing credentials, or a trusted administrator. Compromise of those components requires separate containment controls.

## Security properties

### Runtime

- Conservative policies are explicit, individually configurable, and route-independent where possible.
- Sensitive discriminators are keyed with HMAC before becoming cache keys; raw emails and bearer or portal tokens must not be logged or emitted as metric labels.
- Path inspection is length-bounded, performs at most two decoding passes, tolerates malformed encoding, and tests legitimate near-matches.
- A proxy may supply the client address only after Rails has been configured to trust that exact proxy. Untrusted forwarding headers must not create independent rate-limit identities.
- Shared-IP deployments must retain conservative global limits and prefer account or user dimensions for expensive authenticated work.
- Blocking and throttling responses must remain cache-resistant, accessible, and appropriate for HTML and JSON clients.
- Cache outage behavior is inherited from Rack::Attack and the configured Rails cache adapter. Operators must deliberately choose and document whether their adapter fails open or raises; Rails Shield does not silently replace that policy.

### Operations

- Gem installation, Bundler, Rails boot, and generators never invoke sudo, edit `/etc`, change firewall state, or restart services.
- Host changes require an explicit operations command, a preview, and interactive confirmation unless `--yes` is deliberately supplied.
- Replaced files receive byte-only updates while retaining the original numeric ownership, mode, ACLs, extended attributes, capabilities, and security context where supported.
- Backups are full-path, auditable copies. Rollback restores the archived inode metadata rather than applying hard-coded ownership or modes.
- Nginx, SSH, and fail2ban configuration is validated before service reload; UFW permits reviewed access before activation.

### Maintenance and supply chain

- External advisories are normalized as data and can open a review issue; they cannot execute commands, alter policy, merge code, or publish releases.
- CI uses read-only repository permissions unless a narrowly documented workflow needs more.
- Publishing is manual, environment-gated, MFA-protected, and occurs only after compatibility, content, and security checks pass.

## Abuse cases and mitigations

| Abuse case | Current mitigation | Residual risk / operator action |
| --- | --- | --- |
| PHP and common exploit probes | Bounded canonicalization plus conservative path rules; Nginx and fail2ban templates | Signatures are incomplete and are not a WAF. Review events and keep edge controls patched. |
| Credential stuffing | IP and HMAC-hashed normalized-identity throttles | Distributed attacks and shared NATs require application-specific identity/risk controls. |
| Expensive endpoint exhaustion | Configurable endpoint policies with custom account/user discriminators | IP-only configuration can harm shared users or be bypassed by distributed clients. |
| Bearer-token bucket leakage | HMAC-derived cache discriminator; bounded policy names | Applications must not log raw Authorization headers elsewhere. |
| Forwarded-header spoofing | Exact trusted-proxy configuration and testbed proxy overwrite | A broad Rails trusted-proxy list defeats this property. |
| Regex/decoding resource exhaustion | Fixed path byte limit, fixed decode count, simple bounded matching | Request-body and upstream parser limits remain the proxy/application's responsibility. |
| False-positive route blocking | Conservative defaults and near-match tests; no blanket `/admin` or `/.well-known` block | Every application must test its real routes before enabling aggressive rules. |
| Malicious advisory or prompt injection | Feed content treated only as normalized untrusted fields; no autonomous patches or releases | Human reviewers must not execute copied commands without independent verification. |
| Host configuration damage | Preview, validation, metadata-preserving transaction and rollback manifest | Package and firewall state are reported but are not silently rolled back. |

## Required verification

Every traffic-affecting rule needs an assumed-red malicious case, encoding and malformed-input cases where relevant, bypass coverage, and legitimate near-matches. Release candidates must pass the documented compatibility matrix, isolated application attacks, privileged disposable host checks, gem-content inspection, and a real consumer integration. Independent review is required before describing the project as hardened.

## Explicit non-goals

Rails Shield does not provide TLS security, kernel or container isolation, malware scanning, authentication correctness, authorization, CSRF or XSS prevention beyond Rails itself, SQL-injection prevention, upload inspection, webhook authenticity, browser defenses, secret storage, volumetric DDoS absorption, or protection after host/process compromise. Optional prompt-injection controls and a possible future Rails-aware WAF remain roadmap work.

## Review triggers

Review this model whenever a release adds a new trust boundary, remote rule distribution, upload/body inspection, automated remediation, another privileged operation, a new cache adapter, proxy/CDN support, or an AI/tool-execution integration. Security reports follow [SECURITY.md](../SECURITY.md).
