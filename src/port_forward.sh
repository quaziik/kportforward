#!/usr/bin/env bash
# port_forward.sh - Port-forward management functions for kportforward

# Function to kill kubectl port-forward processes by service name and namespace
kill_port_forward_processes() {
  local name=$1
  local namespace=$2
  local target=$3
  local found=0
  local now=$(date +%s)
  
  # Check if we're in a no-kill grace period for this service
  local no_kill_until=${service_no_kill_until_map[$name]}
  if [ "$now" -lt "$no_kill_until" ]; then
    echo "  ↳ In grace period for $name, not killing processes until $(date -r $no_kill_until)"
    return 0
  fi
  
  # First try using stored PID
  local existing_pid=${pid_map[$name]}
  if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
    echo "  ↳ Stopping existing port-forward for $name (PID: $existing_pid)..."
    kill "$existing_pid" 2>/dev/null
    sleep 1
    # Force kill if still running
    if kill -0 "$existing_pid" 2>/dev/null; then
      kill -9 "$existing_pid" 2>/dev/null
    fi
    # Add to killed PIDs list
    add_pid_to_killed_list "$existing_pid"
    # Clear the stored PID since we're killing it
    pid_map["$name"]=""
    found=1
  fi
  
  # Construct a more specific search pattern for this service
  local local_port="${localPort_map[$name]}"
  local target_port="${targetPort_map[$name]}"
  local specific_pattern="${local_port}:${target_port}"
  
  # Find and kill any other kubectl port-forward processes for this service
  local ps_output
  ps_output=$(ps aux | grep "kubectl port-forward" | grep -v grep | grep "$specific_pattern")
  
  if [ -n "$ps_output" ]; then
    echo "  ↳ Found additional port-forward processes matching ${specific_pattern}..."
    while IFS= read -r line; do
      local pid=$(echo "$line" | awk '{print $2}')
      # Skip PIDs we've already killed or if it's our own tracked PID
      if [ -n "$pid" ] && [ "$pid" != "${pid_map[$name]}" ] && ! is_pid_in_killed_list "$pid"; then
        echo "  ↳ Killing process $pid..."
        kill "$pid" 2>/dev/null
        sleep 1
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
          kill -9 "$pid" 2>/dev/null
        fi
        # Add to killed PIDs list
        add_pid_to_killed_list "$pid"
        found=1
      fi
    done <<< "$ps_output"
  fi
  
  # Add a small cooldown period before starting new processes
  if [ "$found" -eq 1 ]; then
    echo "  ↳ Waiting for port-forward processes to fully terminate..."
    sleep 3
  fi
  
  return $found
}

# Function to start a port-forward process with error logging
start_port_forward() {
  local name=$1
  local target="${target_map[$name]}"
  local tport="${targetPort_map[$name]}"
  local lport="${localPort_map[$name]}"
  local original_lport="${original_localPort_map[$name]}"
  local ns="${namespace_map[$name]}"
  local type="${type_map[$name]}"
  local swagger_path="${swagger_path_map[$name]}"
  local api_path="${api_path_map[$name]}"
  
  # Kill any existing port-forward processes for this service
  kill_port_forward_processes "$name" "$ns" "$target"
  
  # Check if the port is already in use
  if check_port_in_use "$lport"; then
    echo "  ↳ Port $lport is already in use. Attempting to free it..."
    echo "Port $lport is already in use. Attempting to free it..." > "/tmp/kpf_${name}.log"
    
    # Try to free the port first
    if kill_process_on_port "$lport" "$name"; then
      echo "  ↳ Successfully freed port $lport"
    else
      # Find next available port if we can't free the current one
      local next_port=$(find_next_available_port "$lport")
      if [ "$next_port" != "$lport" ]; then
        echo "  ↳ Failed to kill process. Port $lport still in use. Using port $next_port instead."
        echo "Failed to kill process. Port $lport still in use. Using port $next_port instead." > "/tmp/kpf_${name}.log"
        # Update the port mapping
        localPort_map["$name"]=$next_port
        lport=$next_port
        # Mark this new port as used
        used_ports["$lport"]="1"
      else
        echo "  ↳ Failed to find an available port. Service will be blocked."
        echo "Failed to find an available port. Service will be blocked." > "/tmp/kpf_${name}.log"
        raw_status_map["$name"]="Blocked"
        status_map["$name"]="${RED}Blocked${RESET}"
        return 1
      fi
    fi
  fi
  
  # Show port-forward is starting
  if [ "$lport" != "$original_lport" ]; then
    echo "  ↳ Starting port-forward for $name on port $lport (originally configured as $original_lport)..."
  else
    echo "  ↳ Starting port-forward for $name..."
  fi
  
  # Clear previous log entries
  echo "Starting port-forward for $name on port $lport..." > "/tmp/kpf_${name}.log"
  
  # Capture more detailed error information by saving the command
  echo "Running: kubectl port-forward $target ${lport}:${tport} -n $ns" > "/tmp/kpf_${name}.log"
  
  # Set a grace period where we won't try to kill this port-forward 
  # (to avoid detecting our own process as "additional")
  now=$(date +%s)
  service_no_kill_until_map["$name"]=$(( now + 10 ))  # 10 second grace period
  
  # Redirect stderr to a dedicated log file
  kubectl port-forward "$target" "${lport}:${tport}" -n "$ns" >/dev/null 2>>"/tmp/kpf_${name}.log" &
  local new_pid=$!
  pid_map["$name"]=$new_pid                  # store process ID
  start_time_map["$name"]=$(date +%s)        # store start time (epoch seconds)
  
  echo "Started port-forward process with PID: $new_pid" >> "/tmp/kpf_${name}.log"
  
  # Wait a moment to check if the port-forward process started successfully
  sleep 2
  if ! kill -0 "${pid_map[$name]}" 2>/dev/null; then
    # Process died immediately
    echo "  ↳ Port-forward failed to start. Check logs for details."
    echo "Port-forward process died immediately after starting." >> "/tmp/kpf_${name}.log"
    # Check if the target service exists
    kubectl get "$target" -n "$ns" >/dev/null 2>>"/tmp/kpf_${name}.log" || {
      echo "Service $target not found in namespace $ns" >> "/tmp/kpf_${name}.log"
    }
    raw_status_map["$name"]="Broken"
    status_map["$name"]="${RED}Broken${RESET}"
    return 1
  fi
  
  # Start UI services (grpcui or swaggerui) if applicable
  if [[ "$type" == "rpc" && "$ENABLE_GRPCUI" == "true" && "${grpcui_port_map[$name]}" -gt 0 ]]; then
    start_grpcui "$name" "$lport"
  fi
  
  if [[ "$type" == "rest" && "$ENABLE_SWAGGERUI" == "true" && "${swaggerui_port_map[$name]}" -gt 0 ]]; then
    start_swaggerui "$name" "$lport" "$swagger_path" "$api_path"
  fi
  
  return 0
}