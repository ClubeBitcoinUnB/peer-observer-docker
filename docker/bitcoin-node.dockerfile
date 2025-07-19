### Build stage ###
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG BTC_CORE_TAG=v29.0
ARG PEER_EXTRACTOR_REPO=https://github.com/0xB10C/peer-observer.git
ARG PEER_EXTRACTOR_BRANCH=master

# Install build dependencies
RUN apt-get update && apt-get install -y \
    cmake \
    pkgconf \
    libevent-dev \
    libboost-dev \
    libsqlite3-dev \
    systemtap-sdt-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone Bitcoin Core repository
WORKDIR /bitcoin
RUN git clone --branch $BTC_CORE_TAG --depth=1 https://github.com/bitcoin/bitcoin.git .

# Build Bitcoin Core with USDT tracing support
RUN cmake -B build -DBUILD_GUI=OFF -DWITH_USDT=ON -DCMAKE_BUILD_TYPE=Debug && \
    cmake --build build -j$(nproc)

# Install peer-extractor dependencies
RUN apt-get update && apt-get install -y \
    sudo git curl protobuf-compiler \
    clang elfutils libbpf-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup default stable
RUN rustup component add rustfmt

# Copy the local repository to the container
RUN git clone -b $PEER_EXTRACTOR_BRANCH --single-branch $PEER_EXTRACTOR_REPO /peer-observer

# Set working directory to the repository
WORKDIR /peer-observer

# Copy scripts
COPY docker/set-bpf-environment.sh scripts/set-bpf-environment.sh
RUN sudo chmod +x scripts/set-bpf-environment.sh
COPY docker/bitcoin-node-entrypoint.sh scripts/bitcoin-node-entrypoint.sh
RUN chmod +x scripts/bitcoin-node-entrypoint.sh
COPY docker/bitcoin-node-healthcheck.sh scripts/bitcoin-node-healthcheck.sh
RUN chmod +x scripts/bitcoin-node-healthcheck.sh

# Build the project
RUN bash -c ". scripts/set-bpf-environment.sh && cargo build --release"


### Runtime stage ###
FROM ubuntu:22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libevent-core-2.1-7 \
    libevent-extra-2.1-7 \
    libevent-pthreads-2.1-7 \
    libsqlite3-0 \
    libelf1 \
    && rm -rf /var/lib/apt/lists/*

# Create bitcoin user and directories
# Note we are not summoning this user here,
# we want to run the container as root because the usdt tracing
# point will require it. Yet, this user will run the bitcoin node
# in user land, not as root.
RUN useradd -m -s /bin/bash bitcoin \
    && mkdir -p /home/bitcoin/.bitcoin \
    && mkdir -p /shared \
    && chown -R bitcoin:bitcoin /home/bitcoin /shared

# Copy everything we need from builder
COPY --from=builder /peer-observer/scripts/bitcoin-node-entrypoint.sh /peer-observer/scripts/bitcoin-node-entrypoint.sh
COPY --from=builder /peer-observer/scripts/bitcoin-node-healthcheck.sh /peer-observer/scripts/bitcoin-node-healthcheck.sh
COPY --from=builder /bitcoin/build/bin/ /shared/
COPY --from=builder /peer-observer/target/release/ebpf-extractor /usr/local/bin/ebpf-extractor

# Expose Bitcoin ports (RPC: 8332, P2P: 8333)
EXPOSE 8332 8333

# Set data directory and shared volume
VOLUME /home/bitcoin/.bitcoin
VOLUME /shared

# Spawn bitcoin daemon
WORKDIR /peer-observer
ENTRYPOINT ["scripts/bitcoin-node-entrypoint.sh"]
