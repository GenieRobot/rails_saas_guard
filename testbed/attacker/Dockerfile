FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl jq netcat-openbsd python3 \
    && rm -rf /var/lib/apt/lists/*
COPY testbed/attacker/attack.sh /attack.sh
RUN chmod 0755 /attack.sh
ENTRYPOINT ["/attack.sh"]
