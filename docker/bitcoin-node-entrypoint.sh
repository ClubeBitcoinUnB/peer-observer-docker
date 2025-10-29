#!/bin/bash
set -e

BITCOIND_PID=""
EXTRACTOR_PID=""

cleanup() {
    if [ -n "$EXTRACTOR_PID" ] && kill -0 "$EXTRACTOR_PID" 2>/dev/null; then
        echo "Shutting down extractor (PID $EXTRACTOR_PID)..."
        kill "$EXTRACTOR_PID"
        wait "$EXTRACTOR_PID"
    fi
    if [ -n "$BITCOIND_PID" ] && kill -0 "$BITCOIND_PID" 2>/dev/null; then
        echo "Shutting down bitcoind (PID $BITCOIND_PID)..."
        kill "$BITCOIND_PID"
        wait "$BITCOIND_PID"
    fi
}
trap cleanup EXIT

# Fix permissions on the data directory
chown -R bitcoin:bitcoin /home/bitcoin/.bitcoin 2>/dev/null || true

# Determine network flag for bitcoin-cli
NETWORK=""
case "$BITCOIN_NETWORK" in
  mainnet) NETWORK="" ;;
  signet)  NETWORK="-signet" ;;
  testnet) NETWORK="-testnet" ;;
  regtest|"") NETWORK="-regtest" ;; # regtest is the default
  *)
    echo "Unknown BITCOIN_NETWORK: $BITCOIN_NETWORK"
    exit 1
    ;;
esac

# Set default P2P port and address based on extractor type
P2P_EXTRACTOR_PORT=${P2P_EXTRACTOR_PORT:-8555}
P2P_EXTRACTOR_HOST=${P2P_EXTRACTOR_HOST:-0.0.0.0}

echo "Starting $EXTRACTOR_TYPE-extractor setup..."

# Different startup logic based on extractor type
case "$EXTRACTOR_TYPE" in
  ebpf)
    # For eBPF: start bitcoind normally, then attach extractor
    echo "Launching Bitcoin node in $BITCOIN_NETWORK mode..."
    /usr/sbin/runuser -u bitcoin -- $BTC_BIN_PATH/bitcoind $NETWORK &
    BITCOIND_PID=$!
    
    # Wait for RPC to be ready
    for i in {1..30}; do
        /usr/sbin/runuser -u bitcoin -- $BTC_BIN_PATH/bitcoin-cli $NETWORK getblockchaininfo >/dev/null 2>&1 && break
        sleep 1
    done
    
    if ! /usr/sbin/runuser -u bitcoin -- $BTC_BIN_PATH/bitcoin-cli $NETWORK getblockchaininfo >/dev/null 2>&1; then
        echo "Error: bitcoind did not start in time." >&2
        exit 1
    fi
    
    echo "Starting ebpf-extractor..."
    exec /usr/local/bin/ebpf-extractor \
      --no-idle-exit \
      --nats-address nats://nats:4222 \
      --bitcoind-path $BTC_BIN_PATH/bitcoind \
      --bitcoind-pid $BITCOIND_PID
    ;;
    
  p2p)
    # For P2P: start extractor first (listening), then bitcoind connects to it
    echo "Starting p2p-extractor on $P2P_EXTRACTOR_HOST:$P2P_EXTRACTOR_PORT..."
    /usr/local/bin/p2p-extractor \
      --nats-address nats://nats:4222 \
      --p2p-network ${BITCOIN_NETWORK:-regtest} \
      --p2p-address $P2P_EXTRACTOR_HOST:$P2P_EXTRACTOR_PORT &
    EXTRACTOR_PID=$!
    
    # Give extractor time to start listening
    sleep 2
    
    # Check if extractor is still running
    if ! kill -0 "$EXTRACTOR_PID" 2>/dev/null; then
        echo "Error: p2p-extractor failed to start." >&2
        exit 1
    fi
    
    echo "Launching Bitcoin node in $BITCOIN_NETWORK mode (connecting to p2p-extractor)..."
    # Start bitcoind with addnode pointing to the p2p-extractor
    /usr/sbin/runuser -u bitcoin -- $BTC_BIN_PATH/bitcoind $NETWORK \
      -addnode=127.0.0.1:$P2P_EXTRACTOR_PORT &
    BITCOIND_PID=$!
    
    # Wait for RPC to be ready
    for i in {1..30}; do
        /usr/sbin/runuser -u bitcoin -- $BTC_BIN_PATH/bitcoin-cli $NETWORK getblockchaininfo >/dev/null 2>&1 && break
        sleep 1
    done
    
    if ! /usr/sbin/runuser -u bitcoin -- $BTC_BIN_PATH/bitcoin-cli $NETWORK getblockchaininfo >/dev/null 2>&1; then
        echo "Error: bitcoind did not start in time." >&2
        exit 1
    fi
    
    echo "Bitcoin node connected to p2p-extractor successfully"
    # Keep both processes running
    wait $EXTRACTOR_PID
    ;;
    
  *)
    echo "Unknown EXTRACTOR_TYPE: $EXTRACTOR_TYPE" >&2
    echo "Supported types: ebpf, p2p, rpc" >&2
    exit 1
    ;;
esac