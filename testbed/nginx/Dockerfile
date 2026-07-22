FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends nginx ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY testbed/nginx/default.conf /etc/nginx/sites-available/default
COPY ops/nginx/rails_saas_guard.conf /etc/nginx/snippets/rails_saas_guard.conf
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
