# First stage: Build the binary using Go
FROM golang:alpine AS builder

# Install certificates and update the package repository
RUN apk add --no-cache ca-certificates

# Set the working directory inside the container
WORKDIR /go

# Install the SpoofDPI binary with static linking
RUN go install -ldflags '-w -s -extldflags "-static"' -tags timetzdata github.com/xvzc/SpoofDPI/cmd/spoofdpi@latest

# Second stage: Copy the compiled binary to a minimal image
FROM scratch

# Copy the necessary SSL certificates from the builder stage
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Copy the compiled SpoofDPI binary from the builder stage
COPY --from=builder /go/bin/spoofdpi /spoofdpi

# Set default environment variables (can be overridden at runtime)
ENV ADDR="0.0.0.0"
ENV DNS="8.8.8.8"
ENV DEBUG="false"
ENV DOH="false"

# Copy the shell for executing the entrypoint script (since scratch has no shell by default)
COPY --from=builder /bin/sh /bin/sh

# Create an entrypoint script to handle conditional arguments
COPY <<EOF /entrypoint.sh
#!/bin/sh
CMD="/spoofdpi -addr $ADDR -dns-addr $DNS"
[ "$DOH" = "true" ] && CMD="\$CMD -enable-doh"
[ "$DEBUG" = "true" ] && CMD="\$CMD -debug"
echo "Running command: \$CMD"
exec \$CMD
EOF

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Set the entrypoint to use the custom script
ENTRYPOINT ["/entrypoint.sh"]
