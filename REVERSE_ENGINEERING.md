# Reverse Engineering & Performance Guide: Teradek Sputnik & Bond

## Executive Overview
When using a **Teradek Bond** device (cellular bonding transmitter) with **Teradek Sputnik** (server-side proxy and debonding receiver), dropped frames are primarily caused by **kernel-level UDP socket buffer overflows**, **cellular jitter window expiration**, and **Docker bridge NAT overhead**.

This document breaks down the internal architecture of Teradek Sputnik, explains the exact mechanisms leading to dropped frames, and provides step-by-step software and OS optimizations to achieve zero-frame-loss performance.

---

## 1. Sputnik Internal Architecture & Bonding Protocol

Reverse engineering of the `bond_server` binary (compiled C++ daemon utilizing `libev`, `libconfig`, `redis`, and `ffmpeg`) reveals the following components:

### Core Modules
* **`TransportUdpServer` & `TransportUdp`**: Listens on UDP port `5111` for incoming bonded packet streams from multiple interfaces (3G/4G/5G modems, Ethernet, Wi-Fi).
* **`AcknowledgmentUdpData` & `TransportUdpSendPacket`**: Handles ARQ (Automatic Repeat Request / ACK messages) sent back to the Teradek Bond device to request packet retransmissions.
* **`CircularBuffer` & `FrameSet`**: Re-assembles out-of-order UDP payloads arriving from different carrier paths into coherent H.264/AAC video/audio frames.
* **`calculateReleaseTimeMs` & `timeToExpirationMs`**: Evaluates packet release timing against a jitter window. If out-of-order packets arrive later than the frame release cutoff, they are marked as expired and dropped.

---

## 2. Root Causes of Dropped Frames

### Root Cause 1: Kernel UDP Buffer Underrun / Overflow (OS Level)
* **Default Setting**: Standard Linux kernels allocate ~212 KB (`net.core.rmem_max = 212992`) for UDP receive buffers.
* **Problem**: Multi-modem cellular bonding sends bursty UDP streams across 4+ carrier links. When network jitter occurs, packets arrive in bursts. A 212 KB buffer fills in **milliseconds** during high bitrate (5–15 Mbps) video streams, causing the OS kernel to drop UDP packets **before Sputnik's `recvfrom()` call can process them**.

### Root Cause 2: Cellular Latency Variance & Jitter Window Expiration
* Cellular modems across different networks (e.g. AT&T vs Verizon vs T-Mobile) have varying round-trip times (RTT).
* If carrier A has 40ms latency and carrier B spikes to 300ms, Sputnik's default jitter buffer (`timeToExpirationMs`) considers Carrier B's packets "expired" and drops them to maintain real-time playback speed.

### Root Cause 3: Docker Bridge NAT Overhead & MTU Mismatch
* Default Docker container setups use bridge networking (`-p 5111:5111/udp`), which routes UDP traffic through `iptables` NAT.
* Mobile networks frequently use an MTU of 1420 to 1460 bytes. Standard Ethernet 1500 MTU bridge interfaces cause IP packet fragmentation. If a single UDP fragment is dropped, the entire packet is lost.

---

## 3. Recommended Software Improvements & Tuning

### A. Host & Container Kernel Sysctl Tuning
Run the included `./tune-network.sh` script or apply the following kernel parameters on your host OS and Docker container:

```bash
# Set 64MB Maximum UDP Socket Receive & Send Buffers
sysctl -w net.core.rmem_max=67108864
sysctl -w net.core.wmem_max=67108864

# Set 16MB Default UDP Buffers
sysctl -w net.core.rmem_default=16777216
sysctl -w net.core.wmem_default=16777216

# Increase Network Backlog Queue Length
sysctl -w net.core.netdev_max_backlog=100000

# Set Minimum UDP Memory Boundaries
sysctl -w net.ipv4.udp_rmem_min=16384
sysctl -w net.ipv4.udp_wmem_min=16384
```

### B. Use Host Networking (`--net=host`)
Avoid Docker bridge NAT overhead and MTU issues by deploying with `--net=host`:
```bash
docker run -d --name sputnik --net=host --restart=always patrickz/sputnik
```
Or use the included `docker-compose.yml`:
```bash
docker-compose up -d
```

### C. Elevate Process Scheduling Priority
Elevate `bond_server` priority to prevent CPU starvation under high load:
```bash
renice -n -15 -p $(pgrep bond_server)
```

### D. Teradek Bond Hardware Settings Adjustments
In the Teradek Bond device web dashboard:
1. **Increase Buffer Length / Delay**: Increase buffer length from `Auto` / `500ms` to `1500ms` - `3000ms` if streaming over poor cellular coverage.
2. **Enable Adaptive Redundancy / ARQ**: Ensure Automatic Repeat Request (ARQ) retry limit is enabled.
3. **Set Target Bitrate**: Avoid setting a fixed bitrate higher than 70% of total aggregated upload throughput.

---

## 4. Diagnostics & Verification

To verify if dropped frames are occurring at the OS network layer vs Sputnik internal layer, run:

```bash
# Check OS UDP Buffer Drops (RcvbufErrors / SndbufErrors)
nstat -az | grep -i udp

# Or check socket statistics
netstat -s -u | grep "packet receive errors"
```

If `RcvbufErrors` or `packet receive errors` are incrementing, your kernel buffer (`rmem_max`) needs to be increased further using `tune-network.sh`.
