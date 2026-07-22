# Isolated security testbed

This testbed targets infrastructure owned and controlled by the developer. It must not be pointed at public or third-party systems.

## Architecture

- Ubuntu 24.04 Rails 8 fixture using the local Rails SaaS Guard checkout.
- Ubuntu 24.04 Redis cache shared by Rack::Attack.
- Ubuntu 24.04 Nginx reverse proxy that overwrites client forwarding headers.
- Ubuntu 24.04 attacker container on an isolated network.
- Optional privileged Ubuntu 24.04 systemd target for fail2ban, UFW, SSH, metadata, installer and rollback tests.

The app-layer profile publishes only Nginx on `127.0.0.1:18080`. Redis and Rails have no host-published ports. The `host-controls` profile is never started implicitly.

## Requirements

Use Docker Compose or Podman Compose with support for Compose profiles. The host-control suite requires Linux, cgroup v2, systemd container support, and permission to start a privileged disposable container. Review `compose.yml` before running it.

The wrapper automatically adds `compose.docker.yml` under Docker so the systemd target shares the host cgroup namespace. Podman uses only the portable base file because older Podman Compose providers reject that Docker-specific setting.

## Run

```sh
./testbed/bin/test_app
./testbed/bin/test_host_controls
# or both:
./testbed/bin/test_all
```

The lifecycle scripts remove containers, networks, and anonymous volumes on exit. Images remain cached and can be removed with the selected container engine.

## Attack corpus

The attacker currently verifies:

- Raw, mixed-case, path-info, percent-encoded and double-encoded PHP probes.
- WordPress, environment-file, Git-repository and database-admin probes.
- Unsupported WebDAV methods.
- Legitimate `/admin`, `/.well-known`, query-string and filename near-matches.
- Expensive endpoint and bearer-token throttling.
- JSON throttling responses.
- Spoofed `X-Forwarded-For` resistance through the configured proxy boundary.
- Malformed encoding and oversized request-target handling.
- IPv4 and IPv6 fail2ban filter fixtures.
- Actual fail2ban log consumption, ban and unban.
- UFW activation in the disposable system target.
- Nginx, SSH and fail2ban configuration validation.
- Filesystem metadata replacement and rollback.

## Explicitly not exhaustive

No finite suite can simulate every attack. This initial corpus does not claim coverage for volumetric DDoS, TLS implementation attacks, kernel/container escapes, cloud metadata services, provider-specific webhook replay, browser DOM behavior, authentication logic absent from the fixture, database injection without a database-backed endpoint, file uploads, deserialization, dependency zero-days, or prompt injection. Add each new class with a threat model, safe fixture, positive exploit assertion, fixed-behavior assertion, bypass cases and false-positive cases.

Do not add uncontrolled internet scanners or exploit packs to the default suite. Tools such as OWASP ZAP can be evaluated later in a separate opt-in profile with pinned images, bounded requests and artifact review.
