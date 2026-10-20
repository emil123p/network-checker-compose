#!/bin/sh

trap 'exit 0' TERM INT

while true; do
    python /app/network_check.py "$CHECK_HOST" 2>&1 | tee -a /app/logs/wyniki.log
    sleep "${CHECK_INTERVAL:-30}"
done
