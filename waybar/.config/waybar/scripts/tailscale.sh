#!/bin/bash

STATE_FILE="/tmp/waybar_tailscale_state"
CONNECTING_DURATION=2  # seconds to show transition states

# ========================================================
# CONFIGURATION: Set your preferred exit node here!
# Replace with the Tailscale IP or Hostname of your exit node
EXIT_NODE_NAME="pve-1" 
# ========================================================

get_tailscale_status() {
    local status_json
    if status_json=$(tailscale status --json 2>/dev/null); then
        local backend_state=$(echo "$status_json" | jq -r '.BackendState // "NoState"')
        # Check if the ExitNodeStatus object exists
        local has_exit_node=$(echo "$status_json" | jq -r 'if .ExitNodeStatus != null then "true" else "false" end')
        
        case "$backend_state" in
            "Running")
                if [[ "$has_exit_node" == "true" ]]; then
                    echo "exit-node"
                else
                    echo "connected"
                fi
                ;;
            "Stopped"|"NoState"|"NeedsLogin")
                echo "stopped"
                ;;
            *)
                echo "stopped"
                ;;
        esac
    else
        echo "stopped"
    fi
}

get_tooltip() {
    local status_json
    if ! status_json=$(tailscale status --json 2>/dev/null); then
        echo ""
        return
    fi
    
    local backend_state=$(echo "$status_json" | jq -r '.BackendState // "NoState"')
    if [[ "$backend_state" != "Running" ]]; then
        echo ""
        return
    fi
    
    local hostname=$(echo "$status_json" | jq -r '.Self.HostName // "Unknown"')
    local tooltip="<b>Hostname: <span foreground='#87CEEB'>$hostname</span></b>\n"
    
    # Add exit node status to the tooltip
    local has_exit_node=$(echo "$status_json" | jq -r 'if .ExitNodeStatus != null then "true" else "false" end')
    if [[ "$has_exit_node" == "true" ]]; then
        tooltip+="\n<b>Routing:</b> <span foreground='#00ff00'>Using Exit Node 󰄬</span>\n"
    else
        tooltip+="\n<b>Routing:</b> Standard\n"
    fi

    tooltip+="\nPeers:\n"
    
    local peers=$(echo "$status_json" | jq -r '.Peer // {} | to_entries[] | "\(.value.HostName):\(.value.Online)"' | sort)
    
    if [[ -n "$peers" ]]; then
        while IFS=: read -r peer_name peer_online; do
            if [[ "$peer_online" == "true" ]]; then
                tooltip+="\n<span foreground='#00ff00'>●</span> $peer_name"
            else
                tooltip+="\n<span foreground='#666666'>●</span> <span foreground='#888888'>$peer_name</span>"
            fi
        done <<< "$peers"
    else
        tooltip+="\n<i><span foreground='#888888'>No peers</span></i>"
    fi
    
    echo "$tooltip"
}

show_status() {
    local status=$(get_tailscale_status)
    local text=""
    local alt="$status"
    local tooltip=""
    
    case $status in
        "exit-node")
            tooltip=$(get_tooltip)
            ;;
        "connected")
            tooltip=$(get_tooltip)
            ;;
        "stopped")
            tooltip="Tailscale is turned off"
            ;;
    esac
    
    if [[ -n "$tooltip" ]]; then
        echo "{\"text\":\"$text\",\"class\":\"$status\",\"alt\":\"$alt\",\"tooltip\":\"$tooltip\"}"
    else
        echo "{\"text\":\"$text\",\"class\":\"$status\",\"alt\":\"$alt\"}"
    fi
}

show_connecting() {
    echo "{\"text\":\"\",\"class\":\"connecting\",\"alt\":\"connecting\",\"tooltip\":\"Connecting...\"}"
}

show_disconnecting() {
    echo "{\"text\":\"\",\"class\":\"disconnecting\",\"alt\":\"disconnecting\",\"tooltip\":\"Disconnecting...\"}"
}

is_in_transition() {
    if [[ -f "$STATE_FILE" ]]; then
        local state_info=$(cat "$STATE_FILE")
        local state_time=$(echo "$state_info" | cut -d: -f1)
        local current_time=$(date +%s)
        
        if (( current_time - state_time < CONNECTING_DURATION )); then
            return 0  
        else
            rm -f "$STATE_FILE"
            return 1  
        fi
    fi
    return 1  
}

case "$1" in
    --status)
        if is_in_transition; then
            state_info=$(cat "$STATE_FILE")
            state_action=$(echo "$state_info" | cut -d: -f2)
            
            if [[ "$state_action" == "connecting" ]]; then
                show_connecting
                exit 0
            elif [[ "$state_action" == "disconnecting" ]]; then
                show_disconnecting
                exit 0
            fi
        fi
        show_status
        ;;
        
    --toggle)
        if is_in_transition; then
            exit 0
        fi
        
        current_status=$(get_tailscale_status)
        if [[ "$current_status" == "connected" || "$current_status" == "exit-node" ]]; then
            tailscale down
            show_status
        else
            echo "$(date +%s):connecting" > "$STATE_FILE"
            tailscale up
            show_connecting
        fi
        ;;
        
    --toggle-exit-node)
        current_status=$(get_tailscale_status)
        if [[ "$current_status" == "stopped" ]]; then
            # Do nothing if Tailscale isn't connected yet
            exit 0
        elif [[ "$current_status" == "exit-node" ]]; then
            # Turn exit node off
            tailscale set --exit-node=""
            show_status
        else
            # Turn exit node on
            tailscale set --exit-node="$EXIT_NODE_NAME" --exit-node-allow-lan-access=true
            show_status
        fi
        ;;
        
    *)
        echo "Usage: $0 {--status|--toggle|--toggle-exit-node}"
        exit 1
        ;;
esac