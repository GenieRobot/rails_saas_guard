FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends redis-server \
    && rm -rf /var/lib/apt/lists/*
EXPOSE 6379
CMD ["redis-server", "--bind", "0.0.0.0", "--protected-mode", "no", "--save", "", "--appendonly", "no"]
