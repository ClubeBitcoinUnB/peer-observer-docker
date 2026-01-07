# Peer Observer Docker

A Docker configuration repository for [peer-observer](https://github.com/0xB10C/peer-observer), providing easy deployment and orchestration of Bitcoin network monitoring tools.

## Overview

This project contains Docker configurations and orchestration files for running the peer-observer suite, which is a collection of tools for monitoring the Bitcoin network. The peer-observer project helps analyze Bitcoin node connectivity, peer relationships, and network health metrics.

**Purpose**: This repository specifically focuses on providing Docker containerization and orchestration configurations for the peer-observer tools, making it easier to deploy and run the monitoring infrastructure without complex manual setup.

## Architecture

The base system consists of:

- **Bitcoin Node**: A full Bitcoin Core node instrumented for monitoring.
- **Extractor**: Tool that extracts Bitcoin network events and routes messages to the NATS server. Three types are available:
  - **ebpf-extractor** (default): Uses eBPF kernel events to monitor Bitcoin Core internals
  - **p2p-extractor**: Acts as a Bitcoin P2P node to observe network messages
  - **rpc-extractor**: Periodically queries Bitcoin Core RPC interfaces
- **NATS**: Message broker for inter-service communication.

The default network is regtest for test and development, it is provided by [docker-compose.yml](docker-compose.yml) and doesn't require command line arguments. The default extractor is **ebpf-extractor**.

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

3. **Start the base system in regtest** (with default eBPF extractor):
   ```bash
   docker compose up -d
   ```

4. **Check service status**:
   ```bash
   docker compose ps
   ```

You should see two containers running since the bitcoin node and the extractor tool run in the same container.

5. **Start the logger tool**:
```bash
   docker compose --profile logger up -d
```

You should now have three containers.

6. **View logs**:
   ```bash
   docker compose --profile logger logs -f   
   ```

## Choosing an Extractor

You can choose which extractor to use by setting the `EXTRACTOR_TYPE` environment variable:

### eBPF Extractor (Default)

Uses eBPF (extended Berkeley Packet Filter) to monitor Bitcoin Core at the kernel level. Provides the most detailed insights but requires privileged container access.

```bash
# Default - no need to specify
docker compose up -d

# Or explicitly
EXTRACTOR_TYPE=ebpf docker compose up -d
```

**Requirements:**
- Privileged container
- `SYS_ADMIN` and `SYS_PTRACE` capabilities
- Access to `/sys/kernel/debug`

### P2P Extractor

Acts as a Bitcoin P2P peer, intercepting and analyzing network messages between Bitcoin nodes.

```bash
EXTRACTOR_TYPE=p2p docker compose up -d
```

**Configuration Options:**
- `P2P_EXTRACTOR_PORT`: Port for P2P connections (default: 8555)
- `P2P_EXTRACTOR_HOST`: Host address to bind (default: 0.0.0.0)

**Example with custom port:**
```bash
EXTRACTOR_TYPE=p2p P2P_EXTRACTOR_PORT=9000 docker compose up -d
```

### RPC Extractor

Periodically queries Bitcoin Core's RPC interface and publishes the results as events.

```bash
EXTRACTOR_TYPE=rpc docker compose up -d
```

**Configuration Options:**
- `RPC_QUERY_INTERVAL`: Time between queries in seconds (default: 20)
- `RPC_USER`: RPC username (optional, uses cookie file by default)
- `RPC_PASSWORD`: RPC password (optional, uses cookie file by default)

**Example with custom interval:**
```bash
EXTRACTOR_TYPE=rpc RPC_QUERY_INTERVAL=30 docker compose up -d
```

**Example with authentication:**
```bash
EXTRACTOR_TYPE=rpc RPC_USER=peer-observer RPC_PASSWORD=hunter2 docker compose up -d
```

**Note:** If `RPC_USER` and `RPC_PASSWORD` are not provided, the extractor will automatically use Bitcoin Core's cookie file for authentication.

### Using Environment Files

For convenience, create a `.env` file in the project root:

```bash
# .env
EXTRACTOR_TYPE=rpc
RPC_QUERY_INTERVAL=30
RPC_USER=peer-observer
RPC_PASSWORD=hunter2
```

Then simply run:
```bash
docker compose up -d
```

## Services and Ports

| Service            | Port       | Description               |
|--------------------|------------|---------------------------|
| Bitcoin Node       | 8332, 8333 | Bitcoin RPC and P2P ports |
| NATS               | 4222       | Message broker            |
| Metrics            | 8282       | Metrics HTTP endpoint     |
| WebSocket          | 47482      | Real-time data WebSocket  |
| Connectivity Check | 18282      | Connectivity metrics      |

## Usage

### Initial Block Download
In mainnet the Bitcoin node will need to sync with the network on first startup. This process can take several hours to days depending on your internet connection and hardware. Monitor the progress with:

```bash
docker compose logs -f bitcoin-node
```

### Accessing Metrics

Once all services are running:

- **Metrics**: `http://localhost:8282`
- **Connectivity Metrics**: `http://localhost:18282`
- **WebSocket Connection**: `ws://localhost:47482`

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

## Using External Bitcoin Node

If you're already running Bitcoin Core and ebpf-extractor (either locally or on another machine), you can run just the monitoring services:

```bash
docker compose -f monitoring-only.yml --profile monitoring up -d
```

### Local Setup (Same Machine)

When running the monitoring stack on the **same machine** as your Bitcoin node:

1. **Start the monitoring services**:
   ```bash
   docker compose -f monitoring-only.yml --profile monitoring up -d
   ```

2. **Configure ebpf-extractor** to connect to localhost:
   ```bash
   ./ebpf-extractor --nats-address nats://localhost:4222 --bitcoind-path /path/to/bitcoind
   ```

### Remote Setup (Different Machines)

When running the monitoring stack on a **different machine** than your Bitcoin node:

1. **On the monitoring server**, start the services:
   ```bash
   docker compose -f monitoring-only.yml --profile monitoring up -d
   ```

2. **On your Bitcoin node machine**, configure ebpf-extractor to connect remotely:
   ```bash
   # Replace MONITORING_SERVER_IP with your monitoring server's IP address
   ./ebpf-extractor --nats-address nats://MONITORING_SERVER_IP:4222 --bitcoind-path /path/to/bitcoind
   ```

### Managing Individual Services

Start specific monitoring tools as needed:
```bash
# Start all monitoring tools
docker compose -f monitoring-only.yml --profile monitoring up -d

# Or start individual tools
docker compose -f monitoring-only.yml --profile logger up -d
docker compose -f monitoring-only.yml --profile metrics up -d
docker compose -f monitoring-only.yml --profile websocket up -d
docker compose -f monitoring-only.yml --profile connectivity-check up -d
```

### Verify Setup

1. **Check NATS connectivity**:
   ```bash
   docker compose -f monitoring-only.yml logs nats
   ```

2. **Verify ebpf-extractor is publishing events**:
   ```bash
   docker compose -f monitoring-only.yml logs logger
   ```

### Requirements
- Bitcoin Core must be compiled with USDT support (`-DWITH_USDT=ON`)
- ebpf-extractor must run on the same host as bitcoind
- For remote setups: Network connectivity between machines on port 4222

### Security Considerations for Remote Setup
- Use firewall rules to restrict NATS access to your Bitcoin node's IP
- Consider VPN or SSH tunneling between machines
- For production: Enable NATS authentication and TLS
- Monitor logs for unauthorized connection attempts

## Troubleshooting

### Common Issues

1. **Out of disk space**: Ensure you have sufficient disk space for Bitcoin blockchain data
2. **Memory issues**: Increase Docker's memory limit if containers are being killed
3. **Port conflicts**: Ensure the required ports are not in use by other applications
4. **External connection issues**: Verify firewall rules allow connection to NATS port 4222

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
