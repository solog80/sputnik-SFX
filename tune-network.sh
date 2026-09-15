#!/bin/bash
# Network & Kernel Socket Tuning Script for Teradek Sputnik / Bond Server
# Prevents dropped frames caused by UDP socket buffer overflows & cellular jitter

set -e

echo "=== Teradek Sputnik Network Tuning Script ==="

# Apply sysctl parameters to the host system
sudo sysctl -w net.core.rmem_max=67108864
sudo sysctl -w net.core.wmem_max=67108864
sudo sysctl -w net.core.rmem_default=16777216
sudo sysctl -w net.core.wmem_default=16777216
sudo sysctl -w net.core.netdev_max_backlog=100000
sudo sysctl -w net.ipv4.udp_rmem_min=16384
sudo sysctl -w net.ipv4.udp_wmem_min=16384

# Persist settings in /etc/sysctl.d/99-sputnik-bonding.conf if directory exists
if [ -d "/etc/sysctl.d" ]; then
    cat << 'EOF' | sudo tee /etc/sysctl.d/99-sputnik-bonding.conf > /dev/null
# Teradek Sputnik UDP Bonding Optimization
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.netdev_max_backlog = 100000
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
EOF
    echo "Tuning configuration saved to /etc/sysctl.d/99-sputnik-bonding.conf"
fi

echo "=== Network Tuning Complete ==="
