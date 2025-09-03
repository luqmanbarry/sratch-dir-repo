#!/usr/bin/env bash
set -euo pipefail

TARGETS_FILE="/config/targets.txt"
REPLICAS="${REPLICAS:-0}"   # default to 0 if not provided

# Validate REPLICAS is a non-negative integer
if ! [[ "${REPLICAS}" =~ ^[0-9]+$ ]]; then
  echo "[scaler] ERROR: REPLICAS must be a non-negative integer, got '${REPLICAS}'" >&2
  exit 2
fi

echo "[scaler] Starting scale job (oc patch, replicas=${REPLICAS})..."
if [[ ! -s "${TARGETS_FILE}" ]]; then
  echo "[scaler] ERROR: ${TARGETS_FILE} not found or empty."
  exit 2
fi

rc=0
while read -r name; do
  # Skip comments/blank lines
  [[ -z "${name:-}" || "${name:0:1}" == "#" ]] && continue

  echo "[scaler] Patching deployment ${name} to replicas=${REPLICAS}..."
  if ! oc patch deployment "${name}" --type=json \
      -p="[ {\"op\":\"replace\",\"path\":\"/spec/replicas\",\"value\":${REPLICAS}} ]"; then
    echo "[scaler] ERROR: failed to patch ${name}" >&2
    rc=1
    continue
  fi

  # Best-effort wait: if replicas==0, wait until 0; if >0, wait until at least 1 available
  if [[ "${REPLICAS}" == "0" ]]; then
    for i in {1..30}; do
      rep="$(oc get deploy "${name}" -o jsonpath='{.status.replicas}' 2>/dev/null || true)"
      rep="${rep:-0}"
      [[ "${rep}" == "0" ]] && { echo "[scaler] ${name} now at 0 replicas."; break; }
      sleep 2
    done
  else
    for i in {1..60}; do
      desired="$(oc get deploy "${name}" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
      avail="$(oc get deploy "${name}" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)"
      desired="${desired:-0}"; avail="${avail:-0}"
      echo "[scaler] ${name}: desired=${desired} available=${avail}"
      [[ "${avail}" -ge 1 ]] && { echo "[scaler] ${name} has >=1 available."; break; }
      sleep 2
    done
  fi
done < <(grep -vE '^\s*#' "${TARGETS_FILE}")

echo "[scaler] Done with exit code ${rc}."
exit "${rc}"