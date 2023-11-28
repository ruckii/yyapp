FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    curl \
    libnss3-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv

COPY --chmod=755 ./caddy .
COPY ./Caddyfile .

CMD ["/srv/caddy","run","--config","Caddyfile"]
