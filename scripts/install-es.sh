#!/bin/sh
# Install ES into the running Enterprise container via `docker exec`.
# Compose service: splunk-enterprise-security (needs docker.sock).
set -eu

ES_SPL="${ES_SPL:-/packages/splunk-enterprise-security_830.spl}"
MARKER_DIR="${MARKER_DIR:-/es-state}"
MARKER="${MARKER_DIR}/.soc_es830_installed"
CONTAINER="${SPLUNK_CONTAINER:-splunk-enterprise}"
AUTH_USER="${SPLUNK_USER:-admin}"
AUTH_PASS="${SPLUNK_PASSWORD:?SPLUNK_PASSWORD is required}"
REMOTE_SPL="/tmp/splunk-enterprise-security_830.spl"

log() { echo "[es-install] $*"; }

mkdir -p "$MARKER_DIR"

if [ -f "$MARKER" ]; then
  log "already installed (marker $MARKER) — exit 0"
  exit 0
fi

if [ ! -f "$ES_SPL" ]; then
  log "ERROR: package not found: $ES_SPL"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  log "ERROR: docker CLI not found in this container"
  exit 1
fi

log "waiting for container $CONTAINER ..."
i=1
while [ "$i" -le 90 ]; do
  if docker exec "$CONTAINER" true >/dev/null 2>&1; then
    if docker exec "$CONTAINER" curl -fsS http://127.0.0.1:8000/ >/dev/null 2>&1 \
      || docker exec "$CONTAINER" curl -fsS http://127.0.0.1:8000/soc-splunk/ >/dev/null 2>&1; then
      log "Enterprise Web ready (attempt $i)"
      break
    fi
  fi
  if [ "$i" -eq 90 ]; then
    log "ERROR: Enterprise not ready"
    exit 1
  fi
  i=$((i + 1))
  sleep 10
done

log "copying ES package into $CONTAINER ..."
docker cp "$ES_SPL" "${CONTAINER}:${REMOTE_SPL}"

log "ensuring max_upload_size=1024 ..."
docker exec "$CONTAINER" bash -lc '
  mkdir -p /opt/splunk/etc/system/local
  if [ -f /tmp/soc-defaults/web.conf ]; then
    cp -f /tmp/soc-defaults/web.conf /opt/splunk/etc/system/local/web.conf
  else
    grep -q max_upload_size /opt/splunk/etc/system/local/web.conf 2>/dev/null || \
      printf "\n[settings]\nmax_upload_size = 1024\n" >> /opt/splunk/etc/system/local/web.conf
  fi
  chown splunk:splunk /opt/splunk/etc/system/local/web.conf 2>/dev/null || true
'

log "running: splunk install app ..."
docker exec -e SPLUNK_PASSWORD="$AUTH_PASS" "$CONTAINER" \
  /opt/splunk/bin/splunk install app "$REMOTE_SPL" \
  -auth "${AUTH_USER}:${AUTH_PASS}" -update 1

docker exec "$CONTAINER" rm -f "$REMOTE_SPL" || true
touch "$MARKER"
log "Enterprise Security installed."
log "Complete setup in Web: Apps → SplunkEnterpriseSecuritySuite → Set up"
log "If prompted: docker compose restart splunk"
