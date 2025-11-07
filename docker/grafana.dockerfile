FROM grafana/grafana:latest

# Optional argument for deterministic builds
ARG PEER_EXTRACTOR_REPO=https://github.com/0xB10C/peer-observer.git
ARG PEER_EXTRACTOR_BRANCH=master
ARG PEER_EXTRACTOR_COMMIT=87823b767c74e60b23c9a150984c7001d245277b

USER root
RUN apk add --no-cache git

# Clone only the needed commit and extract dashboards
RUN git clone -b $PEER_EXTRACTOR_BRANCH --single-branch $PEER_EXTRACTOR_REPO /tmp/peer-observer \
    && cd /tmp/peer-observer \
    && git checkout $PEER_OBSERVER_COMMIT \
    && mkdir -p /etc/grafana/dashboards \
    && cp -r tools/metrics/dashboards/playlist/*.json /etc/grafana/dashboards/ \
    && rm -rf /tmp/peer-observer

COPY grafana/provisioning /etc/grafana/provisioning

USER grafana
