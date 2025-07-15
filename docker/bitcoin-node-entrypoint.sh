#!/bin/bash
set -e

BITCOIND_PID=""

cleanup() {
    if [ -n "$BITCOIND_PID" ] && kill -0 "$BITCOIND_PID" 2>/dev/null; then
        echo "Shutting down bitcoind (PID $BITCOIND_PID)..."
        kill "$BITCOIND_PID"
        wait "$BITCOIND_PID"
    fi
}
trap cleanup EXIT

# Fix permissions on the data directory
chown -R bitcoin:bitcoin /home/bitcoin/.bitcoin 2>/dev/null || true

# Determine network flag
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

# Start bitcoind as bitcoin user, in the background
echo "Launching Bitcoin node in $BITCOIN_NETWORK mode..."
/usr/sbin/runuser -u bitcoin -- /shared/bitcoind $NETWORK &
BITCOIND_PID=$!

# Now wait for the RPC
for i in {1..30}; do
    /usr/sbin/runuser -u bitcoin -- /shared/bitcoin-cli $NETWORK getblockchaininfo >/dev/null 2>&1 && break
    sleep 1
done

# Final check
if ! /usr/sbin/runuser -u bitcoin -- /shared/bitcoin-cli $NETWORK getblockchaininfo >/dev/null 2>&1; then
    echo "Error: bitcoind did not start in time." >&2
    exit 1
fi

echo "Starting ebpf-extractor"
# Run ebpf-extractor as root (needs CAP_SYS_ADMIN for BPF)
exec /usr/local/bin/ebpf-extractor --nats-address nats://nats:4222 --bitcoind-path /shared/bitcoind
