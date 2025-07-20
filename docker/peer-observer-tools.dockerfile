FROM rust:1.87.0-slim-bookworm AS builder

ARG PEER_EXTRACTOR_REPO=https://github.com/0xB10C/peer-observer.git
ARG PEER_EXTRACTOR_BRANCH=master

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake git \
    protobuf-compiler

# Create a non-root user and configure sudo
RUN useradd -m -s /bin/bash appuser

# Copy repository to the container
RUN git clone -b $PEER_EXTRACTOR_BRANCH --single-branch $PEER_EXTRACTOR_REPO /peer-observer
RUN chown -R appuser:appuser /peer-observer
USER appuser

# Install Rust
RUN rustup default stable

# We build each tool individually to avoid the quircks of the ebpf-extractor.
WORKDIR /peer-observer
RUN cargo build --release \
    --bin logger \
    --bin metrics \
    --bin websocket \
    --bin connectivity-check

### Runtime stage ###
FROM debian:bookworm-slim AS runtime

RUN useradd -m -s /bin/bash appuser
USER appuser
WORKDIR /home/appuser

# Copy everything we need from builder
COPY --from=builder /peer-observer/target/release/logger /home/appuser/logger
COPY --from=builder /peer-observer/target/release/websocket /home/appuser/websocket
COPY --from=builder /peer-observer/target/release/metrics /home/appuser/metrics
COPY --from=builder /peer-observer/target/release/connectivity-check /home/appuser/connectivity-check
