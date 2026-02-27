# SpoofDPI Docker Variables (Unraid)

This page documents the Docker environment variables you can change when running SpoofDPI on Unraid.

> These are default values from the current `Dockerfile`. In Unraid, set them in the container template to override defaults.

## Unraid/runtime variables

| Variable | Default | Description |
|---|---:|---|
| `PUID` | `99` | User ID the process runs as inside the container. Set this to match your Unraid user/permissions model. |
| `PGID` | `100` | Group ID the process runs as inside the container. Set this to match your Unraid group/permissions model. |
| `TZ` | `UTC` | Timezone used in the container (e.g. `America/New_York`). |

## SpoofDPI variables

| Variable | Default | Description |
|---|---:|---|
| `LISTEN_ADDR` | `0.0.0.0:8080` | Listen address and port SpoofDPI binds to. |
| `DNS_ADDR` | `8.8.8.8` | DNS server address. |
| `DNS_PORT` | `53` | DNS server port. |
| `DNS_QTYPE` | `all` | DNS query type behavior (`all`, etc., per SpoofDPI support). |
| `LOG_LEVEL` | *(empty)* | Optional log filters passed via `--log-level` / `-log-level` when supported. You can provide one or multiple levels as supported by your SpoofDPI version (commonly: `text,error,warn,system,array,login`). |
| `SYSTEM_PROXY` | `false` | Controls system proxy behavior when the flag is available. |
| `SILENT` | `false` | Reduce startup/banner output where supported. |
| `POLICY_AUTO` | `true` | Enable automatic policy behavior where supported (`policy-auto`). |
| `WINDOW` | *(empty)* | Optional TLS fragmentation window size. |
| `TIMEOUT` | *(empty)* | Optional timeout value (milliseconds where applicable). |
| `EXTRA_ARGS` | *(empty)* | Extra raw CLI args appended at the end (advanced use). |

## Notes

- The entrypoint checks which SpoofDPI flags are available at runtime and only applies supported flags.
- If the binary does not expose a separate `dns-port` flag, the container combines `DNS_ADDR` + `DNS_PORT` into `host:port` for `dns-addr` automatically.
- In Unraid, all values above are overrideable through the container template/environment section.
- Use `EXTRA_ARGS` for additional or version-specific SpoofDPI flags (for example newer debug/DoH options from current docs).
- Log-level syntax/available level names can differ by SpoofDPI version; if needed, pass an exact docs example directly with `EXTRA_ARGS` (for example `EXTRA_ARGS="--log-level warn"`).

## Example Unraid template values

- `PUID=99`
- `PGID=100`
- `TZ=America/Chicago`
- `LISTEN_ADDR=0.0.0.0:8080`
- `DNS_ADDR=1.1.1.1`
- `DNS_PORT=53`
- `DNS_QTYPE=all`
- `LOG_LEVEL=warn`
- `LOG_LEVEL=error,warn,system`
- `LOG_LEVEL=text,error,warn,system,array,login`
- `SYSTEM_PROXY=false`
- `POLICY_AUTO=true`

