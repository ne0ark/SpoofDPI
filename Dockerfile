FROM alpine:latest

# Set the working directory to /root
WORKDIR /root

# Install required packages
RUN apk add --update --no-cache curl bash

# Download and run the install script for SpoofDPI
RUN curl -fsSL https://raw.githubusercontent.com/xvzc/SpoofDPI/main/install.sh -o install.sh && \
    chmod +x install.sh && \
    ./install.sh linux-amd64 && \
    rm -f install.sh

# Add SpoofDPI to PATH
ENV PATH="$PATH:/root/.spoofdpi/bin"

# Set default values for environment variables (can be overridden at runtime)
ENV ADDR="0.0.0.0"
ENV DNS="8.8.8.8"
ENV DEBUG="false"
ENV DOH="false"

# Create an entrypoint script to handle conditional arguments
RUN echo '#!/bin/sh' > /root/entrypoint.sh && \
    echo 'VER="/root/.spoofdpi/bin/spoofdpi -v"' >> /root/entrypoint.sh && \
    echo 'CMD="/root/.spoofdpi/bin/spoofdpi -addr $ADDR -dns-addr $DNS"' >> /root/entrypoint.sh && \
    echo '[ "$DOH" = "true" ] && CMD="$CMD -enable-doh"' >> /root/entrypoint.sh && \
    echo '[ "$DEBUG" = "true" ] && CMD="$CMD -debug"' >> /root/entrypoint.sh && \
    echo 'echo "Running command: $VER"' >> /root/entrypoint.sh && \
    echo 'echo "Running command: $CMD"' >> /root/entrypoint.sh && \
    echo '$VER' >> /root/entrypoint.sh && \
    echo 'exec $CMD' >> /root/entrypoint.sh && \
    chmod +x /root/entrypoint.sh

ENTRYPOINT ["/root/entrypoint.sh"]

# Use the binary directly without specifying the full path, since it's now in PATH
# ENTRYPOINT ["/bin/sh", "-c", "/root/.spoofdpi/bin/spoofdpi -addr ${ADDR} -dns-addr ${DNS} -debug ${DEBUG} -enable-doh ${DOH}"]
# CMD ["tail", "-f", "/dev/null"]
