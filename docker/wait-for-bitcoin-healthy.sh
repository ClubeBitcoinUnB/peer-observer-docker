#!/bin/bash

echo "Waiting for bitcoin-node to be healthy..."
TIMEOUT=60
INTERVAL=6
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
  HEALTH=$(docker container inspect -f '{{.State.Health.Status}}' peer-observer-docker-bitcoin-node-1)
  if [ "$HEALTH" = "healthy" ]; then
    echo "bitcoin-node is healthy!"
    exit 0
  fi

  echo "Current health status: $HEALTH"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "bitcoin-node failed to become healthy within $TIMEOUT seconds."
docker compose logs bitcoin-node
exit 1
