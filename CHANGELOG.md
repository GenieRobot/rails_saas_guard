## [Unreleased]

- Rename the unpublished project to Rails Shield (`rails_shield`) and position it for general Rails applications rather than SaaS-only use.
- Require an HMAC secret for every sensitive discriminator, independent of its policy name.
- Add a bounded threat model and explicit compatibility matrix.
- Exercise Rack 2.2/3.2 and Rails 7.1–8.1 combinations in CI.

## [0.1.0] - 2026-07-22

- Add configurable Rack::Attack throttles and Devise-style defaults.
- Block PHP script probes and conservative common vulnerability probes.
- Hash email, bearer-token, and other sensitive throttle discriminators.
- Add HTML/JSON responders with retry metadata.
- Add Ubuntu 24.04 fail2ban, Nginx, UFW, and SSH operations installer.
- Add CI, weekly security review, and approval-gated release workflows.
- Document optional future prompt-injection defenses.
