#!/bin/sh
echo "=========================================================="
echo "[Production Service] Starting payment gateway worker..."
echo "[Production Service] Environment: Production EU-West"
echo "=========================================================="
while true; do
    echo "[$(date)] Service healthy. Waiting for queue messages..."
    sleep 30
done
