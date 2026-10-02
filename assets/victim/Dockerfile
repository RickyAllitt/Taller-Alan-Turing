FROM alpine:3.19

# Install tools required for CI/CD operations, container inspection, and breakout simulation
RUN apk update && \
    apk add --no-cache \
        docker-cli \
        bash \
        curl \
        procps \
        coreutils \
        binutils

# Create application directory
WORKDIR /app

# Copy pipeline daemon script
COPY pipeline_runner.sh /app/pipeline_runner.sh
RUN chmod 755 /app/pipeline_runner.sh

# Create non-root user and group (UID 10001) for hardening challenge
RUN addgroup -g 10001 -S cicdgroup && \
    adduser -u 10001 -S cicduser -G cicdgroup

# Inject production deployment secret into PID 1 process memory at runtime
# This simulates an entrypoint wrapper that injects pipeline credentials directly to PID 1
ENTRYPOINT ["/bin/sh", "-c", "DEPLOY_PRODUCTION_KEY='FLAG{supply_chain_credential_leaked_proc_2026}' exec /app/pipeline_runner.sh"]
