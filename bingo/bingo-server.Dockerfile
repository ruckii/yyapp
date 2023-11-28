FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/bingo

COPY --chmod=755 bingo .
COPY ./config-server.yaml ./config.yaml
COPY --chmod=755 healthcheck.sh .

RUN mkdir -p /opt/bongo/logs/21b3c4259a/ && \
    touch /opt/bongo/logs/21b3c4259a/main.log && \
    chmod +w /opt/bongo/logs/21b3c4259a/main.log && \
    chown 1000:1000 /opt/bongo/logs/21b3c4259a/main.log

# Absolute log rotation
# ln -s /dev/null /opt/bongo/logs/21b3c4259a/main.log

USER 1000

CMD ["/opt/bingo/bingo","run_server"]

HEALTHCHECK --interval=5s --timeout=2s \
  CMD ./healthcheck.sh || kill 1