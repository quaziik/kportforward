#!/usr/bin/env bash
# display.sh - Terminal display functions for kportforward

# Helper: Pads a string that may include ANSI color codes.
# It computes the visible length (by stripping escape sequences)
# and appends spaces so that the visible width equals the given width.
pad_colored_field() {
  local colored="$1"
  local width="$2"
  # Use printf "%b" to interpret escape sequences, then strip them
  local visible
  visible=$(printf "%b" "$colored" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g')
  local visible_len=${#visible}
  local pad_count=$(( width - visible_len ))
  local padding=""
  for (( i=0; i < pad_count; i++ )); do
    padding+=" "
  done
  printf "%b%s" "$colored" "$padding"
}

# Helper: Pads a field that may or may not contain color codes.
pad_field() {
  local field="$1"
  local width="$2"
  if [[ "$field" =~ $'\033' ]]; then
    pad_colored_field "$field" "$width"
  else
    printf "%-${width}s" "$field"
  fi
}

# Function to prepare the display data for all services
prepare_display_data() {
  # Header names
  header_name="NAME"
  header_ui="UI URL"
  header_status="STATUS"
  header_local="LOCAL"
  header_target="TARGET"
  header_type="TYPE"
  header_uptime="UPTIME"
  header_restarts="RESTARTS"
  header_error="LAST ERROR"

  # Initialize max widths with header lengths
  max_name=${#header_name}
  max_ui=${#header_ui}
  max_status=${#header_status}
  max_local=${#header_local}
  max_target=${#header_target}
  max_type=${#header_type}
  max_uptime=${#header_uptime}
  max_restarts=${#header_restarts}
  max_error=${#header_error}

  # Build an array of row data for dynamic measurement
  declare -g -A row_data
  for name in "${ports_list[@]}"; do
    # Calculate values
    row_name="$name"
    row_status="${raw_status_map[$name]}"
    # Make sure Blocked status gets the correct color in the status column
    if [ "${raw_status_map[$name]}" = "Blocked" ]; then
        status_map["$name"]="${RED}Blocked${RESET}"
    fi
    
    # Show both current and original port if they differ
    current_port="${localPort_map[$name]}"
    original_port="${original_localPort_map[$name]}"
    if [ "$current_port" != "$original_port" ]; then
      row_local="$current_port (orig: $original_port)"
    else
      row_local="$current_port"
    fi
    
    row_target="${targetPort_map[$name]}"
    row_type="${type_map[$name]}"
    now=$(date +%s)
    start_time=${start_time_map[$name]:-$now}  # Default to now if not set
    uptime_secs=$(( now - start_time ))
    row_uptime=$(format_uptime "$uptime_secs")
    row_restarts="${restart_count_map[$name]}"
    if [ "${raw_status_map[$name]}" = "Broken" ] || [ "${raw_status_map[$name]}" = "Reset" ] || [ "${raw_status_map[$name]}" = "Blocked" ] || [ "${raw_status_map[$name]}" = "Cooldown" ]; then
      row_error=$(tail -n 1 "/tmp/kpf_${name}.log" 2>/dev/null)
      row_error="${row_error:0:30}"
    else
      row_error=""
    fi

    # Prepare UI URL 
    ui_info=""
    if [[ "$ENABLE_GRPCUI" == "true" && "${type_map[$name]}" == "rpc" && "${grpcui_port_map[$name]}" -gt 0 ]]; then
      # Check if the grpcui process is running
      grpcui_pid=${grpcui_pid_map[$name]}
      if [ -n "$grpcui_pid" ] && kill -0 "$grpcui_pid" 2>/dev/null; then
        ui_info="${BLUE}http://localhost:${grpcui_port_map[$name]}${RESET}"
      else
        # Try to get error info from the log file
        grpcui_log_file="/tmp/kpf_grpcui_${name}.log"
        if [ -f "$grpcui_log_file" ]; then
          last_error=$(tail -n 1 "$grpcui_log_file" 2>/dev/null)
          if [ -n "$last_error" ]; then
            ui_info="${YELLOW}gRPC UI: not running${RESET}"
          else
            ui_info="${YELLOW}gRPC UI: not running${RESET}"
          fi
        else
          ui_info="${YELLOW}gRPC UI: not running${RESET}"
        fi
      fi
    elif [[ "$ENABLE_SWAGGERUI" == "true" && "${type_map[$name]}" == "rest" && "${swaggerui_port_map[$name]}" -gt 0 ]]; then
      # Check if the Swagger UI docker container is running
      docker_container=$(docker ps --filter "publish=${swaggerui_port_map[$name]}" -q)
      if [ -n "$docker_container" ]; then
        ui_info="${BLUE}http://localhost:${swaggerui_port_map[$name]}${RESET}"
      else
        ui_info="${YELLOW}Swagger UI: not running${RESET}"
      fi
    elif [[ "${type_map[$name]}" == "web" ]]; then
      # Add URL for web APIs
      ui_info="${BLUE}http://localhost:${current_port}${RESET}"
    fi
    
    # Store data in an associative array for this row
    row_data["$name,name"]="$row_name"
    row_data["$name,ui"]="$ui_info"
    row_data["$name,status"]="$row_status"
    row_data["$name,local"]="$row_local"
    row_data["$name,target"]="$row_target"
    row_data["$name,type"]="$row_type"
    row_data["$name,uptime"]="$row_uptime"
    row_data["$name,restarts"]="$row_restarts"
    row_data["$name,error"]="$row_error"

    # Calculate visible length for colored strings (remove ANSI escape sequences)
    visible_ui=""
    if [ -n "$ui_info" ]; then
      visible_ui=$(printf "%b" "$ui_info" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g')
    fi
    
    # Update max widths
    [ ${#row_name} -gt $max_name ] && max_name=${#row_name}
    [ ${#visible_ui} -gt $max_ui ] && max_ui=${#visible_ui}
    [ ${#row_status} -gt $max_status ] && max_status=${#row_status}
    [ ${#row_local} -gt $max_local ] && max_local=${#row_local}
    [ ${#row_target} -gt $max_target ] && max_target=${#row_target}
    [ ${#row_type} -gt $max_type ] && max_type=${#row_type}
    [ ${#row_uptime} -gt $max_uptime ] && max_uptime=${#row_uptime}
    [ ${#row_restarts} -gt $max_restarts ] && max_restarts=${#row_restarts}
    [ ${#row_error} -gt $max_error ] && max_error=${#row_error}
  done
}

# Function to display the status table
display_status_table() {
  local current_context="$1"
  # Prepare data
  prepare_display_data
  
  # Construct the format string using the max widths
  fmt_header="%-${max_name}s  %-${max_ui}s  %-${max_status}s  %-${max_local}s  %-${max_target}s  %-${max_type}s  %-${max_uptime}s  %-${max_error}s\n"
  fmt_row="%-${max_name}s  %-${max_ui}s  %-${max_status}s  %-${max_local}s  %-${max_target}s  %-${max_type}s  %-${max_uptime}s  %-${max_error}s\n"

  # Reset cursor to start position and clear the screen to ensure clean redraw
  tput cup 0 0
  
  # Add plenty of whitespace to ensure entire line is cleared
  padding="                                                                                           "
  echo -e "Current Kubernetes Context: ${GREEN}${current_context}${RESET}${padding}"
  
  # Display which UI options are enabled
  if [[ "$ENABLE_GRPCUI" == "true" && "$ENABLE_SWAGGERUI" == "true" ]]; then
    echo -e "UI Options: ${GREEN}gRPC UI${RESET} and ${GREEN}Swagger UI${RESET} enabled${padding}"
  elif [[ "$ENABLE_GRPCUI" == "true" ]]; then
    echo -e "UI Options: ${GREEN}gRPC UI${RESET} enabled${padding}"
  elif [[ "$ENABLE_SWAGGERUI" == "true" ]]; then
    echo -e "UI Options: ${GREEN}Swagger UI${RESET} enabled${padding}"
  fi
  
  # If UI options are enabled, add a note about clicking URLs
  if [[ "$ENABLE_GRPCUI" == "true" || "$ENABLE_SWAGGERUI" == "true" ]]; then
    echo -e "${YELLOW}Note: CMD+Click or CTRL+Click to open UI URLs in your browser${RESET}${padding}"
  fi
  
  # Add empty line with padding to clear any residual text
  echo "${padding}"

  # Print header and separator
  printf "$fmt_header" "$header_name" "$header_ui" "$header_status" "$header_local" "$header_target" "$header_type" "$header_uptime" "$header_error"
  total_width=$(( max_name + max_ui + max_status + max_local + max_target + max_type + max_uptime + max_error + 16 ))
  printf '%*s\n' "$total_width" '' | tr ' ' -

  # Print each row using dynamic widths. For the status column, print the colored version.
  for name in "${ports_list[@]}"; do
    now=$(date +%s)
    start_time=${start_time_map[$name]}
    uptime_secs=$(( now - start_time ))
    uptime_str=$(format_uptime "$uptime_secs")
    row_restarts="${restart_count_map[$name]}"
    if [[ "${raw_status_map[$name]}" = "Broken" || "${raw_status_map[$name]}" = "Reset" || "${raw_status_map[$name]}" = "Blocked" || "${raw_status_map[$name]}" = "Cooldown" ]]; then
      row_error=$(tail -n 1 "/tmp/kpf_${name}.log" 2>/dev/null)
      row_error="${row_error:0:80}"
    else
      row_error=$(printf "%-80s" "")
    fi
    
    # Show both current and original port if they differ
    current_port="${localPort_map[$name]}"
    original_port="${original_localPort_map[$name]}"
    if [ "$current_port" != "$original_port" ]; then
      row_local="$current_port (orig: $original_port)"
    else
      row_local="$current_port"
    fi
    
    # Prepare UI field with current data
    row_ui=""
    if [[ "$ENABLE_GRPCUI" == "true" && "${type_map[$name]}" == "rpc" && "${grpcui_port_map[$name]}" -gt 0 ]]; then
      # Check if the grpcui process is running
      grpcui_pid=${grpcui_pid_map[$name]}
      if [ -n "$grpcui_pid" ] && kill -0 "$grpcui_pid" 2>/dev/null; then
        row_ui="${BLUE}http://localhost:${grpcui_port_map[$name]}${RESET}"
        
        # Verify we can actually connect to the UI port
        if ! nc -z localhost "${grpcui_port_map[$name]}" 2>/dev/null; then
          row_ui="${YELLOW}port not responding${RESET}"
          
          # Try restarting automatically during display
          retry_grpcui "$name" > /dev/null 2>&1
        fi
      else
        # Check log file for errors
        grpcui_log_file="/tmp/kpf_grpcui_${name}.log"
        if [ -f "$grpcui_log_file" ] && grep -q "failed" "$grpcui_log_file"; then
          row_ui="${RED}failed to start${RESET}"
        else
          row_ui="${YELLOW}not running${RESET}"
        fi
        
        # Try restarting automatically during display
        retry_grpcui "$name" > /dev/null 2>&1
      fi
    elif [[ "$ENABLE_SWAGGERUI" == "true" && "${type_map[$name]}" == "rest" && "${swaggerui_port_map[$name]}" -gt 0 ]]; then
      # Check if the Swagger UI docker container is running
      docker_container=$(docker ps --filter "publish=${swaggerui_port_map[$name]}" -q)
      if [ -n "$docker_container" ]; then
        row_ui="${BLUE}http://localhost:${swaggerui_port_map[$name]}${RESET}"
      else
        row_ui="${YELLOW}not running${RESET}"
        
        # Try restarting automatically during display
        retry_swaggerui "$name" > /dev/null 2>&1
      fi
    elif [[ "${type_map[$name]}" == "rpc" ]]; then
      row_ui="--"
    elif [[ "${type_map[$name]}" == "web" ]]; then
      # Add URL for web APIs
      row_ui="${BLUE}http://localhost:${current_port}${RESET}"
    fi
    
    # Pad each field. For colored fields, use pad_field to handle ANSI codes.
    row_name_field=$(printf "%-${max_name}s" "${row_data["$name,name"]}")
    row_ui_field=$(pad_field "$row_ui" "$max_ui")
    row_status_field=$(pad_field "${status_map[$name]}" "$max_status")
    row_local_field=$(printf "%-${max_local}s" "$row_local")
    row_target_field=$(printf "%-${max_target}s" "${row_data["$name,target"]}")
    row_type_field=$(printf "%-${max_type}s" "${row_data["$name,type"]}")
    row_uptime_field=$(printf "%-${max_uptime}s" "${row_data["$name,uptime"]}")
    row_error_field=$(printf "%-${max_error}s" "$row_error")

    printf "%s  %s  %s  %s  %s  %s  %s  %s\n" \
      "$row_name_field" "$row_ui_field" "$row_status_field" "$row_local_field" "$row_target_field" "$row_type_field" "$row_uptime_field" "$row_error_field"
  done

  # Clear from cursor to end-of-screen to remove any remnants from a longer previous output
  tput ed
}