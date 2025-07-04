#!/bin/sh
set -e

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    export CPATH="/usr/include/x86_64-linux-gnu:/usr/include/bcc"
    ;;
  aarch64)
    export CPATH="/usr/include/aarch64-linux-gnu:/usr/include/bcc"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

exec "$@"
