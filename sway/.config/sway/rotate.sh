#!/bin/bash

# Direction is now the first argument
DIR=$1

# Get the JSON object for the currently focused output
OUTPUT_JSON=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused == true)')

# Extract name and current transform state
OUTPUT=$(echo "$OUTPUT_JSON" | jq -r '.name')
CURRENT=$(echo "$OUTPUT_JSON" | jq -r '.transform')

# Default to normal if no transform is currently applied
if [ -z "$CURRENT" ] || [ "$CURRENT" = "null" ]; then
    CURRENT="normal"
fi

# Determine the next absolute rotation (Sway's '90' is geometrically counter-clockwise)
if [ "$DIR" = "cw" ]; then
    case $CURRENT in
        "normal") NEXT="270" ;; 
        "270") NEXT="180" ;;
        "180") NEXT="90" ;;
        "90") NEXT="normal" ;;
    esac
elif [ "$DIR" = "ccw" ]; then
    case $CURRENT in
        "normal") NEXT="90" ;;
        "90") NEXT="180" ;;
        "180") NEXT="270" ;;
        "270") NEXT="normal" ;;
    esac
fi

# Apply the new rotation to the focused output
swaymsg output "$OUTPUT" transform "$NEXT"