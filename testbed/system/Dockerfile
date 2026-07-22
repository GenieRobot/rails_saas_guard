FROM ubuntu:24.04
ENV container=docker DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      acl attr ca-certificates fail2ban iproute2 nginx openssh-server sudo systemd systemd-sysv ufw \
    && useradd -m -s /bin/bash tester \
    && install -d -m 0700 -o tester -g tester /home/tester/.ssh \
    && printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestbedOnlyNotARealCredential rails-saas-guard-testbed\n' > /home/tester/.ssh/authorized_keys \
    && chown tester:tester /home/tester/.ssh/authorized_keys \
    && chmod 0600 /home/tester/.ssh/authorized_keys \
    && printf 'tester ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/tester \
    && systemctl enable nginx ssh fail2ban \
    && rm -rf /var/lib/apt/lists/*
COPY ops /workspace/ops
COPY testbed/system/test_host_controls.sh /workspace/testbed/system/test_host_controls.sh
RUN chown -R tester:tester /workspace
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
