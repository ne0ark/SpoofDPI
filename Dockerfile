FROM golang:alpine AS builder
WORKDIR /go
RUN go install -ldflags '-w -s -extldflags "-static"' -tags timetzdata github.com/xvzc/SpoofDPI/cmd/spoofdpi@latest

FROM alpine:latest

RUN apk add --update --no-cache ca-certificates su-exec tzdata
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /go/bin/spoofdpi /usr/local/bin/spoofdpi

# Unraid-friendly runtime defaults (all can be overridden from template/env vars)
ENV PUID="99"
ENV PGID="100"
ENV TZ="UTC"

# SpoofDPI runtime defaults
ENV ADDR="0.0.0.0"
ENV PORT="8080"
ENV DNS_ADDR="8.8.8.8"
ENV DNS_PORT="53"
ENV DEBUG="false"
ENV DOH="true"
ENV WINDOW=""
ENV TIMEOUT=""
ENV SYSTEM_PROXY="false"
ENV SILENT="false"
ENV POLICY_AUTO="false"
ENV EXTRA_ARGS=""

RUN cat > /entrypoint.sh <<'EOS'
#!/bin/sh
set -e

ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone

if ! grep -q "^app:" /etc/group; then
  addgroup -g "$PGID" -S app
fi
if ! grep -q "^app:" /etc/passwd; then
  adduser -u "$PUID" -S -D -H -G app app
fi

/usr/local/bin/spoofdpi -v

set -- /usr/local/bin/spoofdpi \
  --addr "$ADDR" \
  --port "$PORT" \
  --dns-addr "$DNS_ADDR" \
  --dns-port "$DNS_PORT" \
  --system-proxy="$SYSTEM_PROXY"

[ "$DOH" = "true" ] && set -- "$@" --enable-doh
[ "$DEBUG" = "true" ] && set -- "$@" --debug
[ "$SILENT" = "true" ] && set -- "$@" --silent
[ "$POLICY_AUTO" = "true" ] && set -- "$@" --policy-auto
[ -n "$WINDOW" ] && set -- "$@" --window-size "$WINDOW"
[ -n "$TIMEOUT" ] && set -- "$@" --timeout "$TIMEOUT"
[ -n "$EXTRA_ARGS" ] && set -- "$@" $EXTRA_ARGS

echo "Running command: $*"
exec su-exec app "$@"
EOS

RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
