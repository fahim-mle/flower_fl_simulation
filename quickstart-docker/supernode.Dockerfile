FROM flwr/supernode:1.22.0

# Set working directory
WORKDIR /app

# Create directories for certificates and data
RUN mkdir -p /app/certificates/ca /app/data /app/.cache

# Health check - verify SuperNode process is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f flower-supernode > /dev/null || exit 1

# Use default flower-supernode entrypoint
# All arguments (including TLS certificates) will be passed via docker-compose command
ENTRYPOINT ["flower-supernode"]
