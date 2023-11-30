FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    curl \
    libnss3-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv
RUN curl --location --output caddy.tar.gz https://github.com/caddyserver/caddy/releases/download/v2.7.5/caddy_2.7.5_linux_amd64.tar.gz && \
    tar -xf caddy.tar.gz && \
    rm caddy.tar.gz && \
    mkdir /static && echo hello > /static/index.html

COPY ./caddy/Caddyfile .

CMD ["/srv/caddy","run","--config","Caddyfile"]
