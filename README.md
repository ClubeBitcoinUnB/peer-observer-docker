# Peer Observer Docker

A Docker configuration repository for [peer-observer](https://github.com/0xB10C/peer-observer), providing easy deployment and orchestration of Bitcoin network monitoring tools.

## Overview

This project contains Docker configurations and orchestration files for running the peer-observer suite, which is a collection of tools for monitoring the Bitcoin network. The peer-observer project helps analyze Bitcoin node connectivity, peer relationships, and network health metrics.

**Purpose**: This repository specifically focuses on providing Docker containerization and orchestration configurations for the peer-observer tools, making it easier to deploy and run the monitoring infrastructure without complex manual setup.

## Architecture

The base system consists of:

- **Bitcoin Node**: A full Bitcoin Core node instrumented for monitoring.
- **ebpf-extractor**: An extractor tool that consumes ebpf kernel events and routes messages to the NATS server.
- **NATS**: Message broker for inter-service communication.

The default network is regtest for test and development, it is provided by [docker-compose.yml](docker-compose.yml) and doesn't require command line arguments.

Other networks are provided by [node.mainnet.yml](node.mainnet.yml), [node.signet.yml](node.signet.yml), and  [node.regtest.yml](node.regtest.yml). You refer to one of them using the `-f` option, e.g., `docker compose -f node.mainnet.yml up`.

There are currently four tools that consume events from the NATS server:

- **Logger**: Logs peer connection events and activities
- **Metrics**: Exposes monitoring metrics via HTTP endpoint
- **WebSocket**: Provides real-time data via WebSocket connections
- **Connectivity Check**: Monitors network connectivity and health

Refer to [https://github.com/0xB10C/peer-observer](https://github.com/0xB10C/peer-observer) for tooling documentation.

Each tool is configured as a service with the `monitoring` profile and a profile with the tool name. A profile is an opt-in mechanism in docker compose, that is, you only get a service running if you explicitly ask for it. That allows on to start and stop tools in the monitoring pipeline without having to restart the base system (see examples below).

## Prerequisites

- Docker Engine: version 20.10.0 or later
- Docker Compose CLI Plugin: version 2.20.0 or later (Required for support of profiles: and include: directives in Compose files)
- Depending on the chosen Bitcoin network:
  - Disk space: varies (e.g., several hundred GB for mainnet)
  - Internet connection: required for peer connectivity and block synchronization

## Quick Start (regtest)

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd peer-observer-docker
   ```

2. **Build everything**:
```bash
   docker compose --profile monitoring build --no-cache
```

3. **Start the base system in regtest**:
   ```bash
   docker compose up -d
   ```

4. **Check service status**:
   ```bash
   docker compose ps
   ```

You should see two containers running since the bitcoin node and the ebpf-extractor tool should run in the same container.

5. **Start the logger tool**:
```bash
   docker compose --profile logger up -d
```

You should now have three containers.

6. **View logs**:
   ```bash
   docker compose --profile logger logs -f   
   ```

## Services and Ports

| Service            | Port       | Description               |
|--------------------|------------|---------------------------|
| Bitcoin Node       | 8332, 8333 | Bitcoin RPC and P2P ports |
| NATS               | 4222       | Message broker            |
| Metrics            | 8001       | Metrics HTTP endpoint     |
| WebSocket          | 47482      | Real-time data WebSocket  |
| Connectivity Check | 18282      | Connectivity metrics      |
| Prometheus         | 9090       | Datasource for Grafana    |
| Grafana            | 3000       | Data visualization        |

## Usage

### Initial Block Download
In mainnet the Bitcoin node will need to sync with the network on first startup. This process can take several hours to days depending on your internet connection and hardware. Monitor the progress with:

```bash
docker compose logs -f bitcoin-node
```

### Accessing Metrics

Once all services are running:

- **Metrics**: `http://localhost:8001`
- **Connectivity Metrics**: `http://localhost:18282`
- **WebSocket Connection**: `ws://localhost:47482`
- **Prometheus**: `http://localhost:9090`
- **Grafana**: `http://localhost:3000`, username: `admin`, password: `admin`

### Stopping Services

```bash
# Stop all services
docker compose --profile monitoring down

# Stop and remove volumes (WARNING: This will delete blockchain data)
docker compose --profile monitoring down -v
```

## Configuration

### Persistent Data

Bitcoin blockchain data is stored in the `bitcoin-data` Docker volume. This ensures data persistence across container restarts.

## Development

### Building Individual Services

```bash
# Build Bitcoin node
docker compose build bitcoin-node

# Build a specific peer observer tool (logger)
docker compose --profile monitoring build logger

# Build NATS
docker compose build nats
```

### Debugging

To access a running container for debugging:

```bash
# Access Bitcoin node container
docker compose exec bitcoin-node bash

# Access peer observer tools container
docker compose --profile logger exec logger bash
```

## Health Checks

Some services include health checks:

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
docker compose logs [service-name]
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `docker compose up`
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
