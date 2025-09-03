#!/usr/bin/env bash
set -euo pipefail

TARGETS_FILE="/config/targets.txt"

echo "[scaler] Starting scale-down job"
if [[ ! -s "${TARGETS_FILE}" ]]; then
  echo "[scaler] ERROR: ${TARGETS_FILE} not found or empty."
  exit 2
fi

rc=0
while read -r name; do
  # Skip comments/blank lines
  [[ -z "${name:-}" || "${name:0:1}" == "#" ]] && continue

  echo "[scaler] Patching deployment ${name} to replicas=0..."
  if ! oc patch deployment "${name}" --type=json \
      -p='[{"op":"replace","path":"/spec/replicas","value":0}]'; then
    echo "[scaler] ERROR: failed to patch ${name}" >&2
    rc=1
    continue
  fi

  # Best-effort wait until it actually reaches 0 replicas
  for i in {1..30}; do
    replicas="$(oc get deploy "${name}" -o jsonpath='{.status.replicas}' 2>/dev/null || true)"
    replicas="${replicas:-0}"
    if [[ "${replicas}" == "0" ]]; then
      echo "[scaler] ${name} is now at 0 replicas."
      break
    fi
    sleep 2
  done
done < <(grep -vE '^\s*#' "${TARGETS_FILE}")

echo "[scaler] Done with exit code ${rc}."
exit "${rc}"
