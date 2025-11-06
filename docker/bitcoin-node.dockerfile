### Build stage (btc core) ###
FROM ubuntu:22.04 AS btc-core-builder

ENV DEBIAN_FRONTEND=noninteractive
ARG BTC_CORE_TAG=v29.0

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


### Build stage (peer-observer) ###
FROM ubuntu:22.04 AS peer-observer-builder

ARG PEER_EXTRACTOR_REPO=https://github.com/0xB10C/peer-observer.git
ARG PEER_EXTRACTOR_BRANCH=master
ARG PEER_EXTRACTOR_COMMIT=4a49347dcc764daabd047c01274afc6c5399bee6

# Install peer-extractor dependencies
RUN apt-get update && apt-get install -y \
    sudo git curl protobuf-compiler \
    clang elfutils libbpf-dev \
    cmake pkgconf \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup default stable
RUN rustup component add rustfmt

# Copy repository to the container
RUN git clone -b $PEER_EXTRACTOR_BRANCH --single-branch $PEER_EXTRACTOR_REPO /peer-observer

# Set working directory to the repository and checkout to pinned commit
WORKDIR /peer-observer
RUN git checkout $PEER_EXTRACTOR_COMMIT

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
    && chown -R bitcoin:bitcoin /home/bitcoin

# Set bitcoin binary path environment variable
ENV BTC_BIN_PATH=/bitcoin/build/bin

# Copy everything we need from builder
COPY --from=btc-core-builder $BTC_BIN_PATH $BTC_BIN_PATH
COPY --from=peer-observer-builder /peer-observer/scripts/bitcoin-node-entrypoint.sh /peer-observer/scripts/bitcoin-node-entrypoint.sh
COPY --from=peer-observer-builder /peer-observer/scripts/bitcoin-node-healthcheck.sh /peer-observer/scripts/bitcoin-node-healthcheck.sh
COPY --from=peer-observer-builder /peer-observer/target/release/ebpf-extractor /usr/local/bin/ebpf-extractor

# Expose Bitcoin ports (RPC: 8332, P2P: 8333)
EXPOSE 8332 8333

# Set data directory volume
VOLUME /home/bitcoin/.bitcoin

# Spawn bitcoin daemon
WORKDIR /peer-observer
ENTRYPOINT ["scripts/bitcoin-node-entrypoint.sh"]
