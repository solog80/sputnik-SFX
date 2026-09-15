# Teradek Sputnik SFX (Optimized High-Performance Edition)

This repository provides an optimized Docker setup and performance tuning suite for **Teradek Sputnik**, the server-side debonding receiver component for **Teradek Bond** cellular video encoders.

---

## Performance Optimizations (Fixing Dropped Frames)

If you experience dropped frames or video stutter when bonding cellular connections, the cause is typically **Linux UDP kernel socket buffer overflows**, **cellular jitter window timeouts**, or **Docker NAT overhead**.

We have reverse-engineered Sputnik's networking layer and built custom tuning tools to resolve these issues.

### 1. Apply Host Kernel Tuning (Essential)
Before starting the container, run the included `tune-network.sh` script on your Linux host system to increase maximum UDP receive buffers from 212 KB to 64 MB:

```bash
chmod +x tune-network.sh
sudo ./tune-network.sh
```

### 2. Launch with Docker Compose (Recommended)
Use `docker-compose` to run Sputnik with `--net=host` mode, elevated process limits, and tuned container sysctls:

```bash
docker-compose up -d
```

### 3. Manual Docker Launch
If running without `docker-compose`:

```bash
docker run -d \
  --name sputnik \
  --net=host \
  --restart=always \
  --ulimit nofile=65536:65536 \
  --sysctl net.core.rmem_max=67108864 \
  --sysctl net.core.rmem_default=16777216 \
  --sysctl net.core.netdev_max_backlog=100000 \
  solog80/sputnik-sfx
```

---

## Ports & Services

When running with `--net=host`:
* **5111 UDP**: Primary Bond input port for bonded streams.
* **1957 TCP**: Sputnik Web Dashboard.
* **554 TCP**: RTSP Monitoring stream.
* **6379 TCP**: Internal Redis IPC.

---

## Documentation & Reverse Engineering

For detailed technical analysis of Sputnik's `bond_server` C++ binary architecture, socket mechanisms (`TransportUdp`, `CircularBuffer`, `AcknowledgmentUdpData`), and diagnostic commands (`nstat`, `netstat -su`), see:

* [REVERSE_ENGINEERING.md](REVERSE_ENGINEERING.md)
