#!/usr/bin/env bash
# utils.sh - Utility functions for kportforward

# File to track PIDs we've already killed to avoid detecting them again
PF_KILLED_PIDS_FILE="/tmp/kpf_killed_pids.txt"
touch "$PF_KILLED_PIDS_FILE"

# Function to check if a PID is in our killed PIDs list
is_pid_in_killed_list() {
  local check_pid=$1
  grep -q "^$check_pid$" "$PF_KILLED_PIDS_FILE" 2>/dev/null
  return $?
}

# Function to add a PID to our killed PIDs list
add_pid_to_killed_list() {
  local pid=$1
  echo "$pid" >> "$PF_KILLED_PIDS_FILE"
  # Keep the file manageable by removing old entries (keep last 100)
  if [ "$(wc -l < "$PF_KILLED_PIDS_FILE")" -gt 100 ]; then
    tail -n 100 "$PF_KILLED_PIDS_FILE" > "${PF_KILLED_PIDS_FILE}.tmp"
    mv "${PF_KILLED_PIDS_FILE}.tmp" "$PF_KILLED_PIDS_FILE"
  fi
}

# Function to check if a port is already in use
check_port_in_use() {
  local port=$1
  if command -v lsof &>/dev/null; then
    lsof -i :"$port" &>/dev/null
    return $?
  elif command -v nc &>/dev/null; then
    nc -z localhost "$port" &>/dev/null
    return $?
  else
    # Fallback method using /dev/tcp if lsof and nc are not available
    (echo >/dev/tcp/localhost/"$port") &>/dev/null
    return $?
  fi
}

# Function to kill process using a specific port
kill_process_on_port() {
  local port=$1
  local name=$2
  local pid
  
  if command -v lsof &>/dev/null; then
    pid=$(lsof -t -i :"$port" 2>/dev/null)
    if [ -n "$pid" ]; then
      echo "Killing process $pid using port $port" > "/tmp/kpf_${name}.log"
      kill "$pid" 2>/dev/null
      sleep 1
      # Force kill if still running
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null
        echo "Force killed process $pid using port $port" > "/tmp/kpf_${name}.log"
      else
        echo "Successfully killed process $pid using port $port" > "/tmp/kpf_${name}.log"
      fi
      return 0
    fi
  fi
  return 1
}

# Function to find next available port
find_next_available_port() {
  local port=$1
  local base_port=$port
  
  # Keep incrementing the port number until we find an available one
  while check_port_in_use "$port"; do
    ((port++))
  done
  
  # Return the available port
  echo $port
}

# Function to format seconds as human-readable time (Hh Mm Ss)
format_uptime() {
  local total_secs=$1
  if (( total_secs < 60 )); then
    printf "%ds" "$total_secs"
  elif (( total_secs < 3600 )); then
    printf "%dm%02ds" $(( total_secs/60 )) $(( total_secs%60 ))
  else
    local hours=$(( total_secs/3600 ))
    local mins=$(( (total_secs%3600)/60 ))
    local secs=$(( total_secs%60 ))
    if (( hours < 24 )); then
      printf "%dh%02dm%02ds" "$hours" "$mins" "$secs"
    else
      local days=$(( total_secs/86400 ))
      hours=$(( hours % 24 ))
      printf "%dd%02dh%02dm" "$days" "$hours" "$mins"
    fi
  fi
}

# Handle terminal resize event
handle_resize() {
  # Force a redraw by clearing the screen completely
  clear
  # Reset terminal state
  tput cup 0 0
  tput civis  # hide cursor again after resize
}

# Cleanup function to be called on exit
cleanup() {
  echo -e "\nStopping all port-forwards..."
  # Disable the grace period during cleanup
  for name in "${ports_list[@]}"; do
    service_no_kill_until_map["$name"]=0
  done
  
  for name in "${ports_list[@]}"; do
    local target="${target_map[$name]}"
    local ns="${namespace_map[$name]}"
    
    # Use the more reliable port-forward killing function
    kill_port_forward_processes "$name" "$ns" "$target"
    
    # Kill grpcui process if it exists
    grpcui_pid=${grpcui_pid_map[$name]}
    if [ -n "$grpcui_pid" ] && kill -0 "$grpcui_pid" 2>/dev/null; then
      kill "$grpcui_pid" 2>/dev/null
    fi
    
    # Kill any Swagger UI docker containers
    if [[ "$ENABLE_SWAGGERUI" == "true" && "${type_map[$name]}" == "rest" && "${swaggerui_port_map[$name]}" -gt 0 ]]; then
      # Find and kill any docker container using this port
      docker_container=$(docker ps --filter "publish=${swaggerui_port_map[$name]}" -q)
      if [ -n "$docker_container" ]; then
        docker rm -f "$docker_container" >/dev/null 2>&1
      fi
    fi
  done
  
  # Clean up temporary files
  rm -f "$PF_KILLED_PIDS_FILE" 2>/dev/null
  rm -f /tmp/kpf_grpcui_*.log 2>/dev/null
  
  tput cnorm  # restore cursor
  exit 0
}