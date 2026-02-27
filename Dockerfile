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
ENV LISTEN_ADDR="0.0.0.0:8080"
ENV DNS_ADDR="8.8.8.8"
ENV DNS_PORT="53"
ENV DNS_QTYPE="all"
ENV LOG_LEVEL="WARN"
ENV WINDOW=""
ENV TIMEOUT=""
ENV SYSTEM_PROXY="false"
ENV SILENT="false"
ENV POLICY_AUTO="true"
ENV EXTRA_ARGS=""

RUN cat > /entrypoint.sh <<'EOS'
#!/bin/sh
set -e

ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone

GROUP_NAME="$(awk -F: -v gid="$PGID" '$3 == gid { print $1; exit }' /etc/group)"
if [ -z "$GROUP_NAME" ]; then
  GROUP_NAME="app"
  addgroup -g "$PGID" -S "$GROUP_NAME"
fi

USER_NAME="$(awk -F: -v uid="$PUID" '$3 == uid { print $1; exit }' /etc/passwd)"
if [ -z "$USER_NAME" ]; then
  USER_NAME="app"
  if grep -q "^${USER_NAME}:" /etc/passwd; then
    USER_NAME="spoofdpi"
  fi
  adduser -u "$PUID" -S -D -H -G "$GROUP_NAME" "$USER_NAME"
fi

/usr/local/bin/spoofdpi -v
HELP_TEXT="$(/usr/local/bin/spoofdpi -h 2>&1 || true)"

pick_flag() {
  for candidate in "$@"; do
    if printf ' %s ' "$HELP_TEXT" | tr '\n' ' ' | grep -q -- " $candidate "; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

LISTEN_ADDR_FLAG="$(pick_flag -listen-addr --listen-addr || true)"
DNS_ADDR_FLAG="$(pick_flag -dns-addr --dns-addr || true)"
DNS_PORT_FLAG="$(pick_flag -dns-port --dns-port || true)"
DNS_QTYPE_FLAG="$(pick_flag -dns-qtype --dns-qtype || true)"
DNS_ADDR_VALUE="$DNS_ADDR"
if [ -n "$DNS_ADDR_FLAG" ] && [ -z "$DNS_PORT_FLAG" ] && [ -n "$DNS_PORT" ]; then
  DNS_ADDR_VALUE="${DNS_ADDR}:${DNS_PORT}"
fi
WINDOW_FLAG="$(pick_flag -window-size --window-size || true)"
TIMEOUT_FLAG="$(pick_flag -timeout --timeout || true)"
SYSTEM_PROXY_FLAG="$(pick_flag -system-proxy --system-proxy || true)"
SILENT_FLAG="$(pick_flag -silent --silent || true)"
POLICY_AUTO_FLAG="$(pick_flag -policy-auto --policy-auto || true)"
LOG_LEVEL_FLAG="$(pick_flag -log-level --log-level || true)"

set -- /usr/local/bin/spoofdpi
[ -n "$LISTEN_ADDR_FLAG" ] && [ -n "$LISTEN_ADDR" ] && set -- "$@" "$LISTEN_ADDR_FLAG" "$LISTEN_ADDR"
[ -n "$DNS_ADDR_FLAG" ] && [ -n "$DNS_ADDR_VALUE" ] && set -- "$@" "$DNS_ADDR_FLAG" "$DNS_ADDR_VALUE"
[ -n "$DNS_PORT_FLAG" ] && [ -n "$DNS_PORT" ] && set -- "$@" "$DNS_PORT_FLAG" "$DNS_PORT"
[ -n "$DNS_QTYPE_FLAG" ] && [ -n "$DNS_QTYPE" ] && set -- "$@" "$DNS_QTYPE_FLAG" "$DNS_QTYPE"
[ -n "$SYSTEM_PROXY_FLAG" ] && set -- "$@" "$SYSTEM_PROXY_FLAG=$SYSTEM_PROXY"

[ "$SILENT" = "true" ] && [ -n "$SILENT_FLAG" ] && set -- "$@" "$SILENT_FLAG"
[ "$POLICY_AUTO" = "true" ] && [ -n "$POLICY_AUTO_FLAG" ] && set -- "$@" "$POLICY_AUTO_FLAG"
[ -n "$LOG_LEVEL" ] && [ -n "$LOG_LEVEL_FLAG" ] && set -- "$@" "$LOG_LEVEL_FLAG" "$LOG_LEVEL"
[ -n "$WINDOW" ] && [ -n "$WINDOW_FLAG" ] && set -- "$@" "$WINDOW_FLAG" "$WINDOW"
[ -n "$TIMEOUT" ] && [ -n "$TIMEOUT_FLAG" ] && set -- "$@" "$TIMEOUT_FLAG" "$TIMEOUT"
[ -n "$EXTRA_ARGS" ] && set -- "$@" $EXTRA_ARGS

echo "Running command: $*"
exec su-exec "$USER_NAME" "$@"
EOS

RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
