FROM golang:alpine AS builder
WORKDIR /go
RUN go install -ldflags '-w -s -extldflags "-static"' -tags timetzdata github.com/xvzc/SpoofDPI/cmd/spoofdpi@latest

# Second stage: Use a minimal Alpine image
FROM alpine:latest

# Install ca-certificates in the final image
RUN apk add --update --no-cach ca-certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Copy the compiled SpoofDPI binary from the builder stage
COPY --from=builder /go/bin/spoofdpi /usr/local/bin/spoofdpi

# Set default environment variables (can be overridden at runtime)
ENV ADDR="0.0.0.0"
ENV DNS="8.8.8.8"
ENV DEBUG="false"
ENV DOH="true"
ENV WINDOW=""
ENV TIMEOUT=""

# Create an entrypoint script to handle conditional arguments
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo 'VER="/usr/local/bin/spoofdpi -v"' >> /entrypoint.sh && \
    echo 'CMD="/usr/local/bin/spoofdpi -dns-addr $DNS"' >> /entrypoint.sh && \
    echo '[ "$DOH" = "true" ] && CMD="$CMD -enable-doh"' >> /entrypoint.sh && \
    echo '[ "$DEBUG" = "true" ] && CMD="$CMD -debug"' >> /entrypoint.sh && \
    echo '[ ! -z "$WINDOW" ] && CMD="$CMD -window-size $WINDOW"' >> /entrypoint.sh && \
    echo '[ ! -z "$TIMEOUT" ] && CMD="$CMD -timeout $TIMEOUT"' >> /entrypoint.sh && \
    echo 'echo "Running command: $CMD"' >> /entrypoint.sh && \
    echo '$VER' >> /entrypoint.sh && \
    echo 'exec $CMD' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Set the entrypoint to use the custom script
ENTRYPOINT ["/entrypoint.sh"]
