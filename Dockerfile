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

ADDR_FLAG="$(pick_flag -addr --addr || true)"
PORT_FLAG="$(pick_flag -port --port || true)"
DNS_ADDR_FLAG="$(pick_flag -dns-addr --dns-addr || true)"
DNS_PORT_FLAG="$(pick_flag -dns-port --dns-port || true)"
WINDOW_FLAG="$(pick_flag -window-size --window-size || true)"
TIMEOUT_FLAG="$(pick_flag -timeout --timeout || true)"
SYSTEM_PROXY_FLAG="$(pick_flag -system-proxy --system-proxy || true)"
DOH_FLAG="$(pick_flag -enable-doh --enable-doh || true)"
DEBUG_FLAG="$(pick_flag -debug --debug || true)"
SILENT_FLAG="$(pick_flag -silent --silent || true)"
POLICY_AUTO_FLAG="$(pick_flag -policy-auto --policy-auto || true)"

set -- /usr/local/bin/spoofdpi
[ -n "$ADDR_FLAG" ] && [ -n "$ADDR" ] && set -- "$@" "$ADDR_FLAG" "$ADDR"
[ -n "$PORT_FLAG" ] && [ -n "$PORT" ] && set -- "$@" "$PORT_FLAG" "$PORT"
[ -n "$DNS_ADDR_FLAG" ] && [ -n "$DNS_ADDR" ] && set -- "$@" "$DNS_ADDR_FLAG" "$DNS_ADDR"
[ -n "$DNS_PORT_FLAG" ] && [ -n "$DNS_PORT" ] && set -- "$@" "$DNS_PORT_FLAG" "$DNS_PORT"
[ -n "$SYSTEM_PROXY_FLAG" ] && set -- "$@" "$SYSTEM_PROXY_FLAG=$SYSTEM_PROXY"

[ "$DOH" = "true" ] && [ -n "$DOH_FLAG" ] && set -- "$@" "$DOH_FLAG"
[ "$DEBUG" = "true" ] && [ -n "$DEBUG_FLAG" ] && set -- "$@" "$DEBUG_FLAG"
[ "$SILENT" = "true" ] && [ -n "$SILENT_FLAG" ] && set -- "$@" "$SILENT_FLAG"
[ "$POLICY_AUTO" = "true" ] && [ -n "$POLICY_AUTO_FLAG" ] && set -- "$@" "$POLICY_AUTO_FLAG"
[ -n "$WINDOW" ] && [ -n "$WINDOW_FLAG" ] && set -- "$@" "$WINDOW_FLAG" "$WINDOW"
[ -n "$TIMEOUT" ] && [ -n "$TIMEOUT_FLAG" ] && set -- "$@" "$TIMEOUT_FLAG" "$TIMEOUT"
[ -n "$EXTRA_ARGS" ] && set -- "$@" $EXTRA_ARGS

echo "Running command: $*"
exec su-exec "$USER_NAME" "$@"
EOS

RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
