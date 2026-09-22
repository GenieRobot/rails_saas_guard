# Compatibility matrix

The gem supports only combinations exercised in CI or explicitly identified as documentation-only. “Supported” means the gem specs pass and the package resolves with the stated framework family; it does not imply that every Rails cache adapter or proxy topology has been verified.

## Runtime

| Component | Supported/tested range | Evidence |
| --- | --- | --- |
| Ruby | 3.2, 3.3, 3.4 | Full gem suite, style checks, gem build, and operations checks on each version. |
| Rack | 2.2 and 3.2 | Dedicated dependency-resolution and gem-spec jobs. The gem constraint remains `>= 2.2, < 4`. |
| Rack::Attack | 6.7 and 6.8 | Dedicated compatibility jobs and gem constraint. |
| Rails | 7.1, 7.2, 8.0, 8.1 | Dedicated dependency-resolution and gem-spec jobs; Rails 8.1 also boots and runs the isolated fixture. |
| Cache | Redis through `ActiveSupport::Cache::RedisCacheStore` | Multi-container Rails fixture exercises shared throttling state. Atomicity/expiry contract suites for additional adapters remain roadmap work. |

The minimum Ruby version is 3.2. A newer Ruby, Rails, Rack, or Rack::Attack release is not supported merely because dependency resolution succeeds locally; add it to CI first.

## Deployment

| Component | Status |
| --- | --- |
| Ubuntu 24.04 | Tested operations target. |
| Nginx 1.24 on Ubuntu 24.04 | Configuration and reverse-proxy attack fixture tested. |
| Redis 7 on Ubuntu 24.04 | Shared throttling fixture tested. |
| Docker Compose | Application and privileged host-control CI jobs. |
| Rootless Podman Compose on WSL2 | Application and privileged host-control suites tested locally. |
| Cloudflare, Thruster, Kamal proxies | Configuration guidance only until dedicated fixtures land. |
| Solid Cache | Not yet contract-tested. |
| Other Ubuntu/Debian releases | Not supported by the operations installer yet. |

## Compatibility policy

- Patch releases may add tested patch/minor framework versions without changing default traffic behavior.
- Dropping a Ruby, Rack, Rails, cache, proxy, or operating-system family requires release notes and a versioned compatibility change.
- Traffic-affecting changes require bypass and false-positive coverage and are never hidden inside a compatibility-only release.
- Consumer applications remain responsible for testing their real routes, cache topology, proxy chain, NAT population, and response negotiation.

See [THREAT_MODEL.md](THREAT_MODEL.md) for the security properties these combinations must preserve.
