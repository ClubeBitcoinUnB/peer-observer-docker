# Peer Observer Docker

A Docker configuration repository for [peer-observer](https://github.com/0xB10C/peer-observer), providing easy deployment and orchestration of Bitcoin network monitoring tools.

## Overview

This project contains Docker configurations and orchestration files for running the peer-observer suite, which is a collection of tools for monitoring Bitcoin network peer behavior. The peer-observer project helps analyze Bitcoin node connectivity, peer relationships, and network health metrics.

**Purpose**: This repository specifically focuses on providing Docker containerization and orchestration configurations for the peer-observer tools, making it easy to deploy and run the monitoring infrastructure without complex manual setup.

## Architecture

The system consists of several interconnected services:

- **Bitcoin Node**: A full Bitcoin Core node configured for monitoring
- **NATS**: Message broker for inter-service communication
- **Peer Logger**: Logs peer connection events and activities
- **Peer Metrics**: Exposes monitoring metrics via HTTP endpoint
- **Peer WebSocket**: Provides real-time data via WebSocket connections
- **Peer Connectivity Check**: Monitors network connectivity and health

## Prerequisites

- Docker Engine (20.10 or later)
- Docker Compose (2.0 or later)
- At least 8GB RAM (for Bitcoin node)
- Depending on the network: minimum disk space and internet connection

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd peer-observer-docker
   ```

2. **Build and start all services**:
   ```bash
   docker-compose up -d
   ```

3. **Check service status**:
   ```bash
   docker-compose ps
   ```

4. **View logs**:
   ```bash
   # All services
   docker-compose logs -f
   
   # Specific service
   docker-compose logs -f bitcoin-node
   ```

## Services and Ports

| Service | Port | Description |
|---------|------|-------------|
| Bitcoin Node | 8332, 8333 | Bitcoin RPC and P2P ports |
| NATS | 4222 | Message broker |
| Peer Metrics | 8282 | Metrics HTTP endpoint |
| Peer WebSocket | 47482 | Real-time data WebSocket |
| Peer Connectivity Check | 18282 | Connectivity metrics |

## Usage

### Initial Blockchain Sync
In mainnet the Bitcoin node will need to sync with the network on first startup. This process can take several hours to days depending on your internet connection and hardware. Monitor the progress with:

```bash
docker-compose logs -f bitcoin-node
```

### Accessing Metrics

Once all services are running:

- **Peer Metrics**: `http://localhost:8282`
- **Connectivity Metrics**: `http://localhost:18282`
- **WebSocket Connection**: `ws://localhost:47482`

### Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: This will delete blockchain data)
docker-compose down -v
```

## Configuration

### Persistent Data

Bitcoin blockchain data is stored in the `bitcoin-data` Docker volume. This ensures data persistence across container restarts.

## Development

### Building Individual Services

```bash
# Build Bitcoin node
docker-compose build bitcoin-node

# Build peer observer tools
docker-compose build peer-logger peer-metrics peer-websocket peer-connectivity-check

# Build NATS
docker-compose build nats
```

### Debugging

To access a running container for debugging:

```bash
# Access Bitcoin node container
docker-compose exec bitcoin-node bash

# Access peer observer tools container
docker-compose exec peer-logger bash
```

## Health Checks

All services include health checks:

- **Bitcoin Node**: Checks if the node is responsive
- **NATS**: Verifies the message broker is healthy
- Other services depend on NATS being healthy before starting

## Troubleshooting

### Common Issues

1. **Out of disk space**: Ensure you have sufficient disk space for Bitcoin blockchain data
2. **Memory issues**: Increase Docker's memory limit if containers are being killed
3. **Port conflicts**: Ensure the required ports are not in use by other applications

### Logs

Check service logs for detailed error information:

```bash
docker-compose logs [service-name]
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `docker-compose up`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [peer-observer](https://github.com/0xB10C/peer-observer) - The main peer observer tools
- [Bitcoin Core](https://github.com/bitcoin/bitcoin) - Bitcoin reference implementation

## Support

For issues related to:
- Docker configurations: Open an issue in this repository
- Peer observer tools: Check the [main peer-observer repository](https://github.com/0xB10C/peer-observer)