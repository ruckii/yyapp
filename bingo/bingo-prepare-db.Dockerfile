FROM gcr.io/distroless/static-debian12:nonroot
#FROM ubuntu:latest

WORKDIR /opt/bingo

COPY --chmod=755 ./bingo/bingo .
COPY ./bingo/config-prepare-db.yaml ./config.yaml

ENTRYPOINT ["/opt/bingo/bingo","prepare_db"]
