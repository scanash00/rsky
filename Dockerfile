# syntax=docker/dockerfile:1

FROM rust:1.85-bookworm AS builder

WORKDIR /app

# Copy workspace files
COPY Cargo.toml Cargo.lock ./
COPY rsky-relay ./rsky-relay
COPY rsky-common ./rsky-common
COPY rsky-identity ./rsky-identity
COPY rsky-crypto ./rsky-crypto

# Build the relay
RUN cargo build --release --package rsky-relay

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Create data directory with proper permissions
RUN mkdir -p /data && chmod 777 /data

# Create initialization script
RUN echo '#!/bin/sh\n\
sqlite3 /data/plc_directory.db "CREATE TABLE IF NOT EXISTS plc_operations (cid TEXT, did TEXT, created_at TEXT, nullified INTEGER, operation BLOB); CREATE TABLE IF NOT EXISTS plc_keys (did TEXT PRIMARY KEY, pds_endpoint TEXT, pds_key TEXT, labeler_endpoint TEXT, labeler_key TEXT); CREATE TABLE IF NOT EXISTS plc_labelers (did TEXT PRIMARY KEY, labeler_endpoint TEXT);"\n\
exec rsky-relay --no-plc-export' > /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /data

# Copy the binary
COPY --from=builder /app/target/release/rsky-relay /usr/local/bin/rsky-relay

# Expose the relay port
EXPOSE 9000

# Set environment variables
ENV RUST_LOG=rsky_relay=info

# Run the relay with initialization
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
