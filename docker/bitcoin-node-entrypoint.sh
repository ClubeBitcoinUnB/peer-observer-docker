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

# Start bitcoind as bitcoin user, in the background
/usr/sbin/runuser -u bitcoin -- /shared/bitcoind -regtest &
BITCOIND_PID=$!

# Now wait for the RPC
for i in {1..30}; do
    /usr/sbin/runuser -u bitcoin -- /shared/bitcoin-cli -regtest getblockchaininfo >/dev/null 2>&1 && break
    sleep 1
done

# Final check
if ! /usr/sbin/runuser -u bitcoin -- /shared/bitcoin-cli -regtest getblockchaininfo >/dev/null 2>&1; then
    echo "Error: bitcoind did not start in time." >&2
    exit 1
fi

echo "Starting ebpf-extractor"
# Run ebpf-extractor as root (needs CAP_SYS_ADMIN for BPF)
exec /usr/local/bin/ebpf-extractor --nats-address nats://nats:4222 --bitcoind-path /shared/bitcoind
