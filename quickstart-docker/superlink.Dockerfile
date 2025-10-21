FROM flwr/superlink:1.22.0

# Set working directory
WORKDIR /app

# Create directories for certificates
RUN mkdir -p /app/certificates/ca /app/certificates/server

# Expose secure gRPC ports
# 9092 - Fleet API (SuperNode connections)
# 9093 - Other services (SuperExec, etc.)
EXPOSE 9092 9093

# Health check - check if SuperLink is running
# Note: grpc_health_probe may not be available in the base image
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD pgrep -f flower-superlink > /dev/null || exit 1

# Use default flower-superlink entrypoint
# SSL arguments will be passed via docker-compose command
ENTRYPOINT ["flower-superlink"]
