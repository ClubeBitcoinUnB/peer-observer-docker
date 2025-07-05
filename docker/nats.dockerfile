FROM nats:2-alpine
RUN apk add --no-cache wget

COPY docker/nats-server.conf /etc/nats/nats-server.conf

VOLUME ["/data"]
