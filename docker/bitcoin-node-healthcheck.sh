#!/bin/bash

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

exec su - bitcoin -c "$BTC_BIN_PATH/bitcoin-cli $NETWORK getblockchaininfo"
