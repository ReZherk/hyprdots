#!/bin/bash
STATE_FILE="/tmp/super-hold"
THRESHOLD_MS=2000

if [ "$1" = "down" ]; then
    date +%s%N > "$STATE_FILE"
elif [ "$1" = "up" ]; then
    if [ -f "$STATE_FILE" ]; then
        START=$(cat "$STATE_FILE")
        NOW=$(date +%s%N)
        ELAPSED=$(( (NOW - START) / 1000000 ))
        rm -f "$STATE_FILE"
        if [ "$ELAPSED" -ge "$THRESHOLD_MS" ]; then
            hyprctl dispatch global quickshell:overview
        fi
    fi
fi
