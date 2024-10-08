FROM alpine:latest
RUN apk add --no-cache curl bash
RUN curl -fsSL https://raw.githubusercontent.com/xvzc/SpoofDPI/main/install.sh | bash -s linux-amd64
# Set default values for environment variables (these can be overridden at runtime)
ENV ADDR="0.0.0.0"
ENV DNS="8.8.8.8"
ENV DEBUG="false"
ENTRYPOINT ["/bin/sh", "-c", "/root/.spoof-dpi/bin/spoof-dpi -addr ${ADDR} -dns-addr ${DNS} -debug ${DEBUG}"]
