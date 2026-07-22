#!/usr/bin/env bash
set -euo pipefail
TARGET="${TARGET:-http://nginx:8080}"
failures=0
tests=0

assert_status() {
  local expected="$1" method="$2" path="$3"
  shift 3
  tests=$((tests + 1))
  actual="$(curl --path-as-is -sS -o /tmp/body -w '%{http_code}' -X "$method" "$@" "$TARGET$path")"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL $method $path expected=$expected actual=$actual body=$(head -c 160 /tmp/body)" >&2
    failures=$((failures + 1))
  else
    echo "PASS $method $path -> $actual"
  fi
}

until curl -fsS "$TARGET/up" >/dev/null; do sleep 1; done

# PHP execution probes: raw, mixed-case, path-info, encoded and double-encoded.
for path in /index.php /INDEX.PHP /nested/shell.php/exec /index%2ephp /index%252ephp /wordpress/wp-login.php; do
  assert_status 403 GET "$path"
done

# Common probes and unsupported methods.
for path in /.env /.git/config /wp-admin /phpmyadmin; do assert_status 403 GET "$path"; done
for method in PROPFIND PROPPATCH MKCOL COPY MOVE LOCK UNLOCK SEARCH; do assert_status 403 "$method" /ok; done

# False-positive boundaries.
assert_status 200 GET /admin
assert_status 200 GET /.well-known/acme-challenge/test-token
assert_status 200 GET /image.php.jpg
assert_status 200 GET '/search?q=index.php'

# Expensive endpoint: third request is throttled.
assert_status 200 POST /expensive
assert_status 200 POST /expensive
assert_status 429 POST /expensive -H 'Accept: application/json'

# Bearer-token discriminator: fourth request for one token is throttled.
for _ in 1 2 3; do assert_status 200 GET /api/test -H 'Authorization: Bearer secret-test-token'; done
assert_status 429 GET /api/test -H 'Authorization: Bearer secret-test-token' -H 'Accept: application/json'
grep -q 'Too many requests' /tmp/body || { echo "FAIL JSON throttle body" >&2; failures=$((failures + 1)); }

# Nginx overwrites spoofed forwarding headers, so changing XFF cannot evade the IP bucket.
assert_status 200 GET /proxy-bucket -H 'X-Forwarded-For: 198.51.100.1'
assert_status 200 GET /proxy-bucket -H 'X-Forwarded-For: 198.51.100.2'
assert_status 429 GET /proxy-bucket -H 'X-Forwarded-For: 198.51.100.3'

# Malformed and resource-bound requests must be rejected without crashing Rails.
# Nginx rejects malformed URI encoding before location matching, so 400 is correct.
assert_status 400 GET '/%ZZ.php'
long_path="/$(python3 -c 'print("a" * 9000)')"
status="$(curl --path-as-is -sS -o /dev/null -w '%{http_code}' "$TARGET$long_path")"
[[ "$status" =~ ^(400|414)$ ]] || { echo "FAIL oversized path -> $status" >&2; failures=$((failures + 1)); }
tests=$((tests + 1))

echo "Attack corpus: $tests assertions, $failures failures"
[[ $failures -eq 0 ]]
