#!/usr/bin/env bash
# ui_handlers.sh - gRPC UI and Swagger UI management for kportforward

# Function to start the gRPC UI for a service
start_grpcui() {
  local name=$1
  local lport=$2
  
  # Wait a moment for the port-forward to establish
  sleep 2
  echo "  ↳ Checking if port-forward is established..."
  
  # Create a dedicated log file for gRPC UI issues
  local grpcui_log_file="/tmp/kpf_grpcui_${name}.log"
  
  # Verify the port-forward is actually working before starting grpcui
  if nc -z localhost "$lport" 2>/dev/null; then
    echo "  ↳ Starting gRPC UI on port ${grpcui_port_map[$name]} for $name..."
    
    # Kill any existing grpcui process for this service
    local existing_grpcui_pid=${grpcui_pid_map[$name]}
    if [ -n "$existing_grpcui_pid" ] && kill -0 "$existing_grpcui_pid" 2>/dev/null; then
      kill "$existing_grpcui_pid" 2>/dev/null
      sleep 1
    fi
    
    # Make sure the gRPC UI port is free
    if nc -z localhost "${grpcui_port_map[$name]}" 2>/dev/null; then
      echo "  ↳ Port ${grpcui_port_map[$name]} is already in use, attempting to free it..." 
      echo "Port ${grpcui_port_map[$name]} is already in use, attempting to free it..." > "$grpcui_log_file"
      
      pid_using_port=$(lsof -t -i:${grpcui_port_map[$name]} 2>/dev/null)
      if [ -n "$pid_using_port" ]; then
        kill "$pid_using_port" 2>/dev/null
        sleep 1
      fi
      
      # Check again after trying to free it
      if nc -z localhost "${grpcui_port_map[$name]}" 2>/dev/null; then
        echo "  ↳ Port ${grpcui_port_map[$name]} is still in use, gRPC UI for $name will not be started"
        echo "Port ${grpcui_port_map[$name]} is still in use, gRPC UI for $name will not be started" > "$grpcui_log_file"
        return 1  # Return with error
      fi
    fi
    
    # Start grpcui with better error handling
    echo "Running: grpcui -port ${grpcui_port_map[$name]} -plaintext localhost:${lport}" > "$grpcui_log_file"
    
    # Use a timeout to prevent hanging in case of issues
    # Use 'timeout' if available, otherwise just run directly
    if command -v timeout &>/dev/null; then
      timeout 5s grpcui -port "${grpcui_port_map[$name]}" -plaintext "localhost:${lport}" > "$grpcui_log_file" 2>&1 &
    else
      grpcui -port "${grpcui_port_map[$name]}" -plaintext "localhost:${lport}" > "$grpcui_log_file" 2>&1 &
    fi
    
    local new_grpcui_pid=$!
    grpcui_pid_map["$name"]=$new_grpcui_pid
    
    # Wait to see if it stays running
    sleep 2
    if ! kill -0 "$new_grpcui_pid" 2>/dev/null; then
      echo "  ↳ gRPC UI process failed to start for $name, check log at $grpcui_log_file"
      echo "gRPC UI process failed to start or terminated immediately" >> "$grpcui_log_file"
      return 1
    else
      echo "  ↳ gRPC UI started on http://localhost:${grpcui_port_map[$name]}"
      echo "gRPC UI started successfully on http://localhost:${grpcui_port_map[$name]}" >> "$grpcui_log_file"
      return 0
    fi
  else
    echo "  ↳ Port-forward not ready for $name, gRPC UI not started"
    echo "Port-forward for $name not established (port $lport not responding), cannot start gRPC UI" > "$grpcui_log_file"
    return 1
  fi
}

# Function to start the Swagger UI for a service
start_swaggerui() {
  local name=$1
  local lport=$2
  local swagger_path=$3
  local api_path=$4
  
  # Wait a moment for the port-forward to establish
  sleep 1
  echo "  ↳ Checking if port-forward is established..."
  
  # Verify the port-forward is actually working before starting Swagger UI
  if nc -z localhost "$lport" 2>/dev/null; then
    echo "  ↳ Starting Swagger UI on port ${swaggerui_port_map[$name]} for $name..."
    
    # Kill any existing Swagger UI container for this service
    local docker_container=$(docker ps --filter "publish=${swaggerui_port_map[$name]}" -q)
    if [ -n "$docker_container" ]; then
      docker rm -f "$docker_container" >/dev/null 2>&1
    fi
    
    # Start docker container for Swagger UI
    docker run --rm -d -p ${swaggerui_port_map[$name]}:8080 \
      -e URL=http://localhost:${lport}/${api_path}/${swagger_path} \
      swaggerapi/swagger-ui >/dev/null 2>&1
    
    echo "  ↳ Swagger UI started on http://localhost:${swaggerui_port_map[$name]}"
    return 0
  else
    echo "  ↳ Port-forward not ready, Swagger UI not started"
    return 1
  fi
}

# Function to retry gRPC UI startup if it's not running
retry_grpcui() {
  local name=$1
  local lport="${localPort_map[$name]}"
  local type="${type_map[$name]}"
  
  # Only retry if this is an RPC service, grpcui is enabled, and the grpcui_port_map has a valid port
  if [[ "$type" == "rpc" && "$ENABLE_GRPCUI" == "true" && "${grpcui_port_map[$name]}" -gt 0 ]]; then
    local grpcui_log_file="/tmp/kpf_grpcui_${name}.log"
    grpcui_pid=${grpcui_pid_map[$name]}
    
    # Check if there's no grpcui process or if it's not running
    local need_restart=false
    if [ -z "$grpcui_pid" ]; then
      need_restart=true
      echo "No gRPC UI process found for $name" > "$grpcui_log_file"
    elif ! kill -0 "$grpcui_pid" 2>/dev/null; then
      need_restart=true
      echo "gRPC UI process for $name (PID: $grpcui_pid) is not running" > "$grpcui_log_file"
    fi
    
    if [ "$need_restart" = true ]; then
      # Verify the port-forward is actually working before starting grpcui
      if nc -z localhost "$lport" 2>/dev/null; then
        echo "Attempting to start gRPC UI for $name on port ${grpcui_port_map[$name]}..." >> "$grpcui_log_file"
        
        # Make sure the gRPC UI port is free
        if nc -z localhost "${grpcui_port_map[$name]}" 2>/dev/null; then
          echo "Port ${grpcui_port_map[$name]} is already in use, attempting to free it..." >> "$grpcui_log_file"
          pid_using_port=$(lsof -t -i:${grpcui_port_map[$name]} 2>/dev/null)
          if [ -n "$pid_using_port" ]; then
            kill "$pid_using_port" 2>/dev/null
            sleep 1
          fi
          
          # Check again after trying to free it
          if nc -z localhost "${grpcui_port_map[$name]}" 2>/dev/null; then
            echo "Port ${grpcui_port_map[$name]} is still in use, gRPC UI for $name will not be started" >> "$grpcui_log_file"
            return 1
          fi
        fi
        
        # Start grpcui with output capturing for debugging
        echo "Running: grpcui -port ${grpcui_port_map[$name]} -plaintext localhost:${lport}" >> "$grpcui_log_file"
        grpcui -port "${grpcui_port_map[$name]}" -plaintext "localhost:${lport}" > "$grpcui_log_file" 2>&1 &
        local new_grpcui_pid=$!
        grpcui_pid_map["$name"]=$new_grpcui_pid
        
        # Wait to see if it stays running
        sleep 2
        if ! kill -0 "$new_grpcui_pid" 2>/dev/null; then
          echo "gRPC UI process failed to start or terminated immediately" >> "$grpcui_log_file"
          # If there's any error output, include it in the log
          if [ -s "$grpcui_log_file" ]; then
            echo "Error output from gRPC UI startup:" >> "$grpcui_log_file"
          else
            echo "No error output captured from gRPC UI startup" >> "$grpcui_log_file"
          fi
          return 1
        else
          echo "gRPC UI started successfully on http://localhost:${grpcui_port_map[$name]}" >> "$grpcui_log_file"
          return 0
        fi
      else
        echo "Port-forward for $name not established (port $lport not responding), cannot start gRPC UI" >> "$grpcui_log_file"
        return 1
      fi
    fi
  fi
  return 0
}

# Function to retry Swagger UI startup if it's not running
retry_swaggerui() {
  local name=$1
  local lport="${localPort_map[$name]}"
  local type="${type_map[$name]}"
  local api_path="${api_path_map[$name]}"
  local swagger_path="${swagger_path_map[$name]}"
  
  # Only retry if this is a REST service, swaggerui is enabled, and the swaggerui container isn't running
  if [[ "$type" == "rest" && "$ENABLE_SWAGGERUI" == "true" && "${swaggerui_port_map[$name]}" -gt 0 ]]; then
    # Check if there's a docker container running for this port
    docker_container=$(docker ps --filter "publish=${swaggerui_port_map[$name]}" -q)
    if [ -z "$docker_container" ]; then
      # Don't log during monitoring, only during initial startup
      if [[ "${raw_status_map[$name]}" == "Broken" ]]; then
        echo "Restarting Swagger UI for $name..." > "/tmp/kpf_${name}.log"
      fi
      
      # Verify the port-forward is actually working before starting Swagger UI
      if nc -z localhost "$lport" 2>/dev/null; then
        # Start docker container for Swagger UI
        docker run --rm -d -p ${swaggerui_port_map[$name]}:8080 \
          -e URL=http://localhost:${lport}/${api_path}/${swagger_path} \
          swaggerapi/swagger-ui >/dev/null 2>&1
        
        if [[ "${raw_status_map[$name]}" == "Broken" ]]; then
          echo "Swagger UI restarted for $name on http://localhost:${swaggerui_port_map[$name]}" > "/tmp/kpf_${name}.log"
        fi
        return 0
      fi
      return 1
    fi
  fi
  return 0
}