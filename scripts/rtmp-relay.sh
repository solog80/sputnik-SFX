#!/bin/bash

# Script to forward Sputnik streams to multiple RTMP destinations

# Define your RTMP destinations here
RTMP_DESTINATIONS=(
    "rtmp://destination_1/live/stream"
    "rtmp://destination_2/live/stream"
    "rtmp://destination_3/live/stream"
)

# Function to forward stream
forward_stream() {
    local stream_url="
"
    for destination in "${RTMP_DESTINATIONS[@]}"; do
        stream_url="${stream_url} -f "${destination}"
    done
    # Start the relay using FFmpeg
    ffmpeg -i input_stream_url ${stream_url}
}

# Start the stream forwarding
forward_stream
