FROM flwr/superexec:1.22.0

WORKDIR /app

# Create directory for certificates and outputs
RUN mkdir -p /app/certificates/ca /app/outputs

# Copy and install project dependencies
COPY pyproject.toml .
RUN sed -i 's/.*flwr\[simulation\].*//' pyproject.toml \
   && python -m pip install -U --no-cache-dir .

# Set environment variables for CA certificate trust
# These ensure Python's SSL library trusts the mounted CA certificate
ENV SSL_CERT_FILE=/app/certificates/ca/ca.crt \
    REQUESTS_CA_BUNDLE=/app/certificates/ca/ca.crt \
    PYTHONUNBUFFERED=1

# Health check - verify SuperExec process is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=2 \
    CMD pgrep -f flower-superexec > /dev/null || exit 1

ENTRYPOINT ["flower-superexec"]
