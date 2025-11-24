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
    && rm -rf /var/lib/apt/lists/*

# Create data directory with proper permissions
RUN mkdir -p /data && chmod 777 /data

WORKDIR /data

# Copy the binary
COPY --from=builder /app/target/release/rsky-relay /usr/local/bin/rsky-relay

# Expose the relay port
EXPOSE 9000

# Set environment variables
ENV RUST_LOG=rsky_relay=info

# Run the relay
CMD ["rsky-relay"]
