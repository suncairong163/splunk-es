#!/usr/bin/env bash
# Seed Enterprise Security apps from the .spl baked into the image.
set -euo pipefail

SPLUNK_HOME="${SPLUNK_HOME:-/opt/splunk}"
ES_SPL="${ES_SPL:-/opt/splunk-packages/splunk-enterprise-security_830.spl}"
MARKER="${SPLUNK_HOME}/etc/.soc_es830_seeded"
APPS_DIR="${SPLUNK_HOME}/etc/apps"
DEFAULTS_SRC="${SOC_DEFAULTS_SRC:-/tmp/soc-defaults}"
ROOT_ENDPOINT="${SPLUNK_ROOT_ENDPOINT:-/}"

log() { echo "[seed-es] $*"; }

if [[ -f "$MARKER" ]]; then
  log "already seeded — skip"
  exit 0
fi

if [[ ! -f "$ES_SPL" ]]; then
  log "WARN: ES package missing at $ES_SPL — skip seed"
  exit 0
fi

mkdir -p "$APPS_DIR" "${SPLUNK_HOME}/etc/system/local"

log "extracting $(basename "$ES_SPL") → $APPS_DIR (may take several minutes)"
tar -xf "$ES_SPL" -C "$APPS_DIR"

mkdir -p "${SPLUNK_HOME}/etc/system/local"
cat > "${SPLUNK_HOME}/etc/system/local/web.conf" <<EOF
[settings]
root_endpoint = ${ROOT_ENDPOINT}
tools.proxy.on = True
max_upload_size = 1024
EOF
log "wrote web.conf root_endpoint=${ROOT_ENDPOINT}"

if [[ -f "${DEFAULTS_SRC}/inputs.conf" && ! -f "${SPLUNK_HOME}/etc/system/local/inputs.conf" ]]; then
  cp -f "${DEFAULTS_SRC}/inputs.conf" "${SPLUNK_HOME}/etc/system/local/inputs.conf"
fi

touch "$MARKER"
chown -R splunk:splunk "$APPS_DIR" "$MARKER" \
  "${SPLUNK_HOME}/etc/system/local" 2>/dev/null || true

log "Enterprise Security apps seeded."
