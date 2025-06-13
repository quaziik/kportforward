# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

kportforward is a modular Bash tool for macOS that automates managing and monitoring multiple Kubernetes port-forwards. It reads a YAML configuration file, starts the defined port-forwards using `kubectl port-forward`, and continuously monitors their status—automatically restarting any connection that fails. The tool also detects Kubernetes context changes and refreshes the port-forwards accordingly.

## Development Commands

```bash
# Make script executable
chmod +x kportforward.sh

# Test basic functionality
./kportforward.sh

# Test with UI features
./kportforward.sh --grpcui --swaggerui

# Check script syntax
bash -n kportforward.sh
bash -n src/*.sh
```

## Key Components

- `kportforward.sh`: The main Bash script that coordinates all functionality
- `src/config.sh`: Configuration module for dependency checking and YAML parsing
- `src/utils.sh`: Utility functions for port checking, PID tracking, etc.
- `src/port_forward.sh`: Module for managing Kubernetes port-forwards
- `src/ui_handlers.sh`: Module for managing gRPC UI and Swagger UI interfaces
- `src/display.sh`: Module for terminal display formatting
- `kportforward.yaml`: Configuration file defining port-forwards to manage

## Usage Commands

To use the tool:

```bash
# Display help information
./kportforward.sh --help

# Basic usage
./kportforward.sh

# With gRPC UI support for RPC services
./kportforward.sh --grpcui

# With Swagger UI support for REST services
./kportforward.sh --swaggerui

# With both gRPC UI and Swagger UI support
./kportforward.sh --grpcui --swaggerui
```

## Dependencies

The tool requires the following tools:

- `kubectl`: Kubernetes CLI for managing clusters
  ```bash
  brew install kubectl
  ```

- `yq`: YAML processor for parsing configuration
  ```bash
  brew install yq
  ```

Optional dependencies:

- `grpcui`: For gRPC web interfaces (when using the `--grpcui` flag)
  ```bash
  go install github.com/fullstorydev/grpcui/cmd/grpcui@latest
  ```

- `netcat (nc)`: Required for gRPC UI and Swagger UI support
  ```bash
  brew install netcat
  ```

- `docker`: Required for Swagger UI support (when using the `--swaggerui` flag)
  ```bash
  # Install from https://www.docker.com/products/docker-desktop
  ```

## Architecture

The tool uses a modular design with these core patterns:

- **Main Loop**: `kportforward.sh` coordinates all modules and runs the monitoring loop
- **Associative Arrays**: Service data is stored in bash associative arrays (e.g., `target_map`, `status_map`, `pid_map`)
- **Process Management**: Each port-forward runs as a background `kubectl port-forward` process
- **Real-time Monitoring**: Main loop checks process status every second and restarts failed connections
- **UI Integration**: Optional gRPC UI and Swagger UI processes are spawned and managed alongside port-forwards
- **Context Awareness**: Detects Kubernetes context changes and restarts all port-forwards accordingly

## Configuration

The `kportforward.yaml` file defines port-forwards with the following structure:

```yaml
portForwards:
  service-name:
    target: "service/service-name"
    targetPort: 80
    localPort: 8080
    namespace: "namespace"
    type: "web"  # Optional: "web", "rest", or "rpc"
    swaggerPath: "api/docs"  # Optional: for Swagger UI
    apiPath: "api"  # Optional: base API path
```

Each entry must include:
- `target`: The Kubernetes resource to forward to (e.g., `service/name`)
- `targetPort`: The port on the target resource
- `localPort`: The local machine port to forward
- `namespace`: The namespace where the target resource is located
- `type`: (optional) The API type to categorize the service ("rest", "rpc", "web")
- `swaggerPath`: (optional) Path to Swagger docs for REST services
- `apiPath`: (optional) Base API path for REST services

## Key Features

- Modular architecture for better maintainability
- Automated port-forwards from YAML configuration
- Real-time monitoring with automatic restart of disconnected tunnels
- Interactive terminal display with color-coded status
- Kubernetes context change detection
- gRPC UI support for RPC services
- Swagger UI support for REST services
- Port conflict detection and resolution
- Exponential backoff for frequently failing services
- Graceful shutdown

## Development Notes

- When modifying modules, source them in the correct order in `kportforward.sh`
- UI handlers use temporary log files in `/tmp/kpf_*` for debugging
- Process cleanup is handled via trap signals (SIGINT, SIGTERM)
- Port conflict resolution automatically finds next available port starting from configured port
- Exponential backoff prevents resource exhaustion from frequently failing services

## Testing

The tool doesn't have formal tests. Manual testing can be performed by:
1. Setting up a test configuration in `kportforward.yaml`
2. Running the script with `./kportforward.sh`
3. Verifying port-forwards are established and monitored correctly
4. Testing UI features with `--grpcui` and `--swaggerui` flags
5. Syntax checking with `bash -n` on all shell scripts

## Troubleshooting

Common issues:
- Missing dependencies: Install required tools using Homebrew
- Port conflicts: The tool automatically handles these by finding the next available port
- gRPC UI issues: Check logs in `/tmp/kpf_grpcui_*.log` for detailed error messages
- Swagger UI issues: Ensure Docker is running on your machine
- Kubernetes context issues: Verify correct context with `kubectl config current-context`
- Excessive restarts: Services that restart frequently will enter a cooldown period with exponential backoff