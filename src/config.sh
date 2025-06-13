#!/usr/bin/env bash
# config.sh - Configuration and dependency checking for kportforward

# Default configuration
CONFIG_FILE="kportforward.yaml"

# ANSI color codes for output
GREEN=$'\033[32m'
RED=$'\033[31m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
RESET=$'\033[0m'

# Function to display help message
display_help() {
  echo "kportforward - A robust Kubernetes port-forwarding utility"
  echo
  echo "Usage: ./kportforward.sh [OPTIONS]"
  echo
  echo "Options:"
  echo "  --help, -h       Display this help message and exit"
  echo "  --grpcui         Enable gRPC UI for RPC services"
  echo "  --swaggerui      Enable Swagger UI for REST services"
  echo
  echo "Description:"
  echo "  This script manages multiple port-forwards to Kubernetes services, with features including:"
  echo "  - Automatic detection and handling of port conflicts"
  echo "  - Support for gRPC UI and Swagger UI for API services"
  echo "  - Real-time monitoring and automatic recovery of broken connections"
  echo "  - Rich status display with color-coded indicators"
  echo
  echo "Configuration:"
  echo "  Port-forwards are defined in kportforward.yaml file in the current directory."
  echo "  See README.md for detailed configuration options."
}

# Function to check dependencies
check_dependencies() {
  # Check command-line arguments
  ENABLE_GRPCUI=false
  ENABLE_SWAGGERUI=false
  
  for arg in "$@"; do
    case "$arg" in
      --grpcui)
        ENABLE_GRPCUI=true
        ;;
      --swaggerui)
        ENABLE_SWAGGERUI=true
        ;;
    esac
  done
  
  # Check core dependencies
  missing=""
  for cmd in kubectl yq; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+="$cmd "
    fi
  done
  
  # Check for grpcui if enabled
  if [[ "$ENABLE_GRPCUI" == "true" ]]; then
    if ! command -v grpcui &>/dev/null; then
      echo "Warning: grpcui is not installed, but --grpcui option was specified."
      echo "Install grpcui with: go install github.com/fullstorydev/grpcui/cmd/grpcui@latest"
      echo "Continuing without gRPC UI..."
      ENABLE_GRPCUI=false
    fi
    
    # Also check for nc (netcat), which is used to check port availability
    if ! command -v nc &>/dev/null; then
      echo "Warning: nc (netcat) is not installed, but is required for gRPC UI support."
      echo "Install nc with: brew install netcat"
      echo "Continuing without gRPC UI..."
      ENABLE_GRPCUI=false
    fi
  fi
  
  # Check for docker if swaggerui is enabled
  if [[ "$ENABLE_SWAGGERUI" == "true" ]]; then
    if ! command -v docker &>/dev/null; then
      echo "Warning: docker is not installed, but --swaggerui option was specified."
      echo "Install docker from https://www.docker.com/products/docker-desktop"
      echo "Continuing without Swagger UI..."
      ENABLE_SWAGGERUI=false
    fi
  
    # Also check for nc (netcat), which is used to check port availability
    if ! command -v nc &>/dev/null; then
      echo "Warning: nc (netcat) is not installed, but is required for Swagger UI support."
      echo "Install nc with: brew install netcat"
      echo "Continuing without Swagger UI..."
      ENABLE_SWAGGERUI=false
    fi
  fi
  
  # Check optional watch/tmux (not strictly required, but inform user if missing)
  for opt in watch tmux; do
    if ! command -v "$opt" &>/dev/null; then
      # Just note missing optional tools (don't count as blocking missing)
      if [ "$opt" == "watch" ] || [ "$opt" == "tmux" ]; then
        echo "Note: Optional tool '$opt' is not installed. You can install it via Homebrew (e.g., 'brew install $opt')."
      fi
    fi
  done
  
  if [ -n "$missing" ]; then
    echo "Error: Missing required dependencies: $missing"
    echo "Please install the above before running this script."
    echo "- kubectl: Kubernetes CLI (e.g., brew install kubectl)"
    echo "- yq: YAML parser (e.g., brew install yq)"
    exit 1
  fi
  
  # Return values to main script
  echo "$ENABLE_GRPCUI $ENABLE_SWAGGERUI"
}

# Function to parse the YAML configuration file
parse_config() {
  # Read and parse YAML configuration using yq
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
  fi
  
  # Use yq to extract all port-forward entries
  # We'll fill associative arrays for each attribute, indexed by port-forward name.
  declare -g -A target_map targetPort_map localPort_map original_localPort_map namespace_map type_map grpcui_port_map grpcui_pid_map swaggerui_port_map swaggerui_pid_map swagger_path_map api_path_map
  ports_list=($(yq e '.portForwards | keys | .[]' "$CONFIG_FILE" | sort)) 2>/dev/null
  if [ "${#ports_list[@]}" -eq 0 ]; then
    echo "Error: No portForwards entries found in $CONFIG_FILE"
    exit 1
  fi
  
  # Starting port for gRPC UI and Swagger UI interfaces
  grpcui_base_port=8080
  swaggerui_base_port=9080
  
  # First, collect all local ports to avoid conflicts
  declare -g -A used_ports
  for name in "${ports_list[@]}"; do
    # yq outputs keys unquoted; if keys have spaces or special chars, additional handling needed.
    # In our case, keys like "flyte-console" are simple strings.
    target_map["$name"]="$(yq e ".portForwards.[\"$name\"].target" "$CONFIG_FILE")"
    targetPort_map["$name"]="$(yq e ".portForwards.[\"$name\"].targetPort" "$CONFIG_FILE")"
    local_port="$(yq e ".portForwards.[\"$name\"].localPort" "$CONFIG_FILE")"
    localPort_map["$name"]="$local_port"
    original_localPort_map["$name"]="$local_port"  # Keep track of original port for reporting
    namespace_map["$name"]="$(yq e ".portForwards.[\"$name\"].namespace" "$CONFIG_FILE")"
    type_map["$name"]="$(yq e ".portForwards.[\"$name\"].type // \"\"" "$CONFIG_FILE")"
    swagger_path_map["$name"]="$(yq e ".portForwards.[\"$name\"].swaggerPath // \"configuration/swagger\"" "$CONFIG_FILE")"
    api_path_map["$name"]="$(yq e ".portForwards.[\"$name\"].apiPath // \"api\"" "$CONFIG_FILE")"
    
    # Track all local ports as used
    used_ports["$local_port"]="1"
    
    # Initialize grpcui_port_map and swaggerui_port_map with 0 (will be assigned later)
    grpcui_port_map["$name"]=0
    swaggerui_port_map["$name"]=0
    
    # Clear error logs for each port-forward on startup
    rm -f "/tmp/kpf_${name}.log" 2>/dev/null
  done
  
  # Now assign gRPC UI ports, ensuring no conflicts with local ports
  for name in "${ports_list[@]}"; do
    if [[ "${type_map[$name]}" == "rpc" && "$ENABLE_GRPCUI" == "true" ]]; then
      # Find the next available port that doesn't conflict with any local port
      while [[ -n "${used_ports[$grpcui_base_port]}" ]]; do
        ((grpcui_base_port++))
      done
      
      # Assign the non-conflicting port
      grpcui_port_map["$name"]=$grpcui_base_port
      # Mark this port as used
      used_ports["$grpcui_base_port"]="1"
      # Move to next port for next service
      ((grpcui_base_port++))
    fi
    
    # Assign Swagger UI ports for REST services
    if [[ "${type_map[$name]}" == "rest" && "$ENABLE_SWAGGERUI" == "true" ]]; then
      # Find the next available port that doesn't conflict with any used port
      while [[ -n "${used_ports[$swaggerui_base_port]}" ]]; do
        ((swaggerui_base_port++))
      done
      
      # Assign the non-conflicting port
      swaggerui_port_map["$name"]=$swaggerui_base_port
      # Mark this port as used
      used_ports["$swaggerui_base_port"]="1"
      # Move to next port for next service
      ((swaggerui_base_port++))
    fi
  done
  
  # Initialize other global variables
  declare -g -A pid_map start_time_map restart_count_map status_map raw_status_map
  declare -g -A service_cooldown_map
  declare -g -A service_no_kill_until_map
}

# Export variables for use in other modules
export CONFIG_FILE
export GREEN RED YELLOW BLUE RESET
export ENABLE_GRPCUI ENABLE_SWAGGERUI
export ports_list