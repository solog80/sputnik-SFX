#!/bin/bash
# Teradek Sputnik Optimized Startup Script

echo "=== Starting Optimized Teradek Sputnik ==="

# Set process priorities if permissions allow
if command -v renice >/dev/null 2>&1; then
    renice -n -10 -p $$ 2>/dev/null || true
fi

# Ensure data directories exist
mkdir -p /data/conf /var/log

# Start Sputnik service
service sputnik start

sleep 2

# Check if sputnik process is running and elevate its priority
SPUTNIK_PID=$(pgrep bond_server || true)
if [ -n "$SPUTNIK_PID" ]; then
    echo "Elevating Sputnik bond_server (PID $SPUTNIK_PID) priority..."
    renice -n -15 -p $SPUTNIK_PID 2>/dev/null || true
fi

echo "Sputnik operational. Monitoring logs..."
exec tail -f /var/log/sputnik.log
