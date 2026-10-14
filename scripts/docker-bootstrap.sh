#!/usr/bin/env bash
# Idempotent post-start helpers for the official splunk/splunk image.
# Invoked by compose after the container is healthy, or manually:
#   docker compose exec -u root splunk /sbin/soc-splunk-bootstrap.sh
set -euo pipefail

SPLUNK_HOME="${SPLUNK_HOME:-/opt/splunk}"
SPLUNK_BIN="${SPLUNK_HOME}/bin/splunk"
LOCAL_SYSTEM="${SPLUNK_HOME}/etc/system/local"
DEFAULTS_SRC="${SOC_DEFAULTS_SRC:-/tmp/soc-defaults}"

if [[ ! -x "$SPLUNK_BIN" ]]; then
  echo "error: splunk binary not found at $SPLUNK_BIN" >&2
  exit 1
fi

mkdir -p "$LOCAL_SYSTEM"

# Merge / refresh local web.conf defaults (root_endpoint + upload size + proxy).
if [[ -f "${DEFAULTS_SRC}/web.conf" ]]; then
  cp -f "${DEFAULTS_SRC}/web.conf" "${LOCAL_SYSTEM}/web.conf"
  chown splunk:splunk "${LOCAL_SYSTEM}/web.conf" 2>/dev/null || true
  echo "installed ${LOCAL_SYSTEM}/web.conf"
fi

# Ensure HEC stanza exists (token still comes from env / UI).
if [[ -f "${DEFAULTS_SRC}/inputs.conf" && ! -f "${LOCAL_SYSTEM}/inputs.conf" ]]; then
  cp -f "${DEFAULTS_SRC}/inputs.conf" "${LOCAL_SYSTEM}/inputs.conf"
  chown splunk:splunk "${LOCAL_SYSTEM}/inputs.conf" 2>/dev/null || true
  echo "installed ${LOCAL_SYSTEM}/inputs.conf"
fi

# Apply official license files if mounted.
shopt -s nullglob
for lic in /licenses/*.lic; do
  echo "adding license: $lic"
  "$SPLUNK_BIN" add licenses "$lic" -auth "admin:${SPLUNK_PASSWORD:?SPLUNK_PASSWORD required}" || true
done
shopt -u nullglob

echo "bootstrap done. Restart splunkweb if web.conf changed:"
echo "  $SPLUNK_BIN restart splunkweb -auth admin:****"
