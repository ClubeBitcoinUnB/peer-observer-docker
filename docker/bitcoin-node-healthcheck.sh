#!/bin/bash
exec su - bitcoin -c "/shared/bitcoin-cli -regtest getblockchaininfo"
