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
RUN ls -l /root/.spoofdpi/bin/

# Set default values for environment variables (can be overridden at runtime)
ENV ADDR="0.0.0.0"
ENV DNS="8.8.8.8"
ENV DEBUG="false"

# Use the binary directly without specifying the full path, since it's now in PATH
# ENTRYPOINT ["/bin/sh", "-c", "spoof-dpi -addr ${ADDR} -dns-addr ${DNS} -debug ${DEBUG}"]
CMD ["tail", "-f", "/dev/null"]
