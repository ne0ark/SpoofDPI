FROM alpine:latest
RUN apk add --no-cache curl bash
RUN curl -fsSL https://raw.githubusercontent.com/xvzc/SpoofDPI/main/install.sh | bash -s linux-amd64
CMD [ "/bin/sh" "-c" "/root/.spoof-dpi/bin/spoof-dpi -addr ${ADDR} -dns-addr ${DNS} -debug ${DEBUG}"]
