# First stage: Build the binary using Go
FROM golang:alpine AS builder

# Set the working directory inside the container
WORKDIR /go

# Install the SpoofDPI binary with static linking
RUN go install -ldflags '-w -s -extldflags "-static"' -tags timetzdata github.com/xvzc/SpoofDPI/cmd/spoofdpi@latest

# Second stage: Copy the compiled binary to a minimal image
FROM scratch

# Copy necessary files from the builder stage
COPY --from=builder /go/bin/spoofdpi /spoofdpi
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Set default environment variables (can be overridden at runtime)
ENV ADDR="0.0.0.0"
ENV DNS="8.8.8.8"
ENV DEBUG="false"
ENV DOH="false"

# Create an entrypoint script that constructs the command dynamically
COPY --from=builder /bin/sh /bin/sh # Ensure /bin/sh is available on scratch

COPY /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Create the entrypoint script
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
