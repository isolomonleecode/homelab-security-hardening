#!/usr/bin/env bash

set -euo pipefail

# Purpose: Scan all running Docker containers' images with Trivy and produce
# - Raw per-image text reports under findings/vulnerability-reports/
# - A consolidated CSV summary (findings/vulnerability-summary.csv)
# - A consolidated Markdown summary (findings/vulnerability-summary.md)
#
# Safe for Unraid: Read-only operations; does not change containers.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/findings/vulnerability-reports"
CSV_SUMMARY="$REPO_ROOT/findings/vulnerability-summary.csv"
MD_SUMMARY="$REPO_ROOT/findings/vulnerability-summary.md"

mkdir -p "$OUT_DIR"

if ! command -v trivy >/dev/null 2>&1; then
  echo "[ERROR] trivy not found. Install Trivy on the host first." >&2
  echo "       https://aquasecurity.github.io/trivy/" >&2
  exit 1
fi

echo "Enumerating running containers..."
mapfile -t CONTAINERS < <(docker ps --format '{{.ID}} {{.Image}} {{.Names}}')

if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
  echo "No running containers detected. Exiting." >&2
  exit 0
fi

# CSV header
echo "container_id,container_name,image,total_critical,total_high,total_medium,total_low,scan_status" > "$CSV_SUMMARY"

cat > "$MD_SUMMARY" <<'EOF'
# Vulnerability Summary

This report summarizes Trivy scans for all running containers.

Note: Counts reflect OS and library vulnerabilities discovered by Trivy at scan time.

| Container | Image | CRITICAL | HIGH | MEDIUM | LOW | Status |
|-----------|-------|----------|------|--------|-----|--------|
EOF

scan_one() {
  local cid="$1"; shift
  local image="$1"; shift
  local name="$1"; shift

  # Normalize filename
  local safe_name
  safe_name="${name//\//_}"
  local report_txt="$OUT_DIR/${safe_name}.txt"

  echo "Scanning $name ($image)..."
  # Raw text report for portfolio evidence
  if ! trivy image --quiet --format table "$image" > "$report_txt" 2>/dev/null; then
    echo "$cid,$name,$image,0,0,0,0,scan_failed" >> "$CSV_SUMMARY"
    echo "| $name | $image | 0 | 0 | 0 | 0 | scan_failed |" >> "$MD_SUMMARY"
    return
  fi

  # Extract counts using Trivy JSON for accuracy
  local json
  if ! json=$(trivy image --quiet --format json "$image" 2>/dev/null); then
    echo "$cid,$name,$image,0,0,0,0,json_failed" >> "$CSV_SUMMARY"
    echo "| $name | $image | 0 | 0 | 0 | 0 | json_failed |" >> "$MD_SUMMARY"
    return
  fi

  # Parse severity totals from JSON using jq if available; fallback to 0s
  local crit=0 high=0 med=0 low=0
  if command -v jq >/dev/null 2>&1; then
    crit=$(jq -r '[.Results[]? | .Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' <<<"$json" 2>/dev/null || echo 0)
    high=$(jq -r '[.Results[]? | .Vulnerabilities[]? | select(.Severity=="HIGH")] | length' <<<"$json" 2>/dev/null || echo 0)
    med=$(jq -r '[.Results[]? | .Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' <<<"$json" 2>/dev/null || echo 0)
    low=$(jq -r '[.Results[]? | .Vulnerabilities[]? | select(.Severity=="LOW")] | length' <<<"$json" 2>/dev/null || echo 0)
  fi

  echo "$cid,$name,$image,$crit,$high,$med,$low,ok" >> "$CSV_SUMMARY"
  echo "| $name | $image | $crit | $high | $med | $low | ok |" >> "$MD_SUMMARY"
}

for line in "${CONTAINERS[@]}"; do
  cid="${line%% *}"; rest="${line#* }"
  image="${rest%% *}"; name="${rest#* }"
  scan_one "$cid" "$image" "$name"
done

echo "\nDetailed raw reports are in: $OUT_DIR"
echo "CSV summary: $CSV_SUMMARY"
echo "Markdown summary: $MD_SUMMARY"



