#!/usr/bin/env bash

set -euo pipefail

# Purpose: Inventory security-relevant Docker settings for running containers and
# produce:
# - A CSV report (findings/hardening-audit.csv)
# - A Markdown report with suggested remediations (findings/hardening-audit.md)
#
# Safe for Unraid: Read-only; does not change containers.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/findings"
CSV_FILE="$OUT_DIR/hardening-audit.csv"
MD_FILE="$OUT_DIR/hardening-audit.md"

mkdir -p "$OUT_DIR"

mapfile -t CONTAINERS < <(docker ps --format '{{.ID}} {{.Image}} {{.Names}}')

if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
  echo "No running containers detected. Exiting." >&2
  exit 0
fi

echo "container_id,container_name,image,privileged,run_as_user,cap_add,read_only_rootfs,exposed_ports,host_port_bindings,network_mode" > "$CSV_FILE"

cat > "$MD_FILE" <<'EOF'
# Hardening Audit

Read-only inventory of Docker container security posture.

Key risk indicators:
- privileged = true
- run_as_user empty or root
- cap_add includes powerful capabilities (e.g., NET_ADMIN, SYS_ADMIN)
- read_only_rootfs = false
- host port bindings to 0.0.0.0 for sensitive services

| Container | Image | Privileged | User | CapAdd | RO RootFS | Ports | Bindings | NetMode |
|-----------|-------|------------|------|--------|-----------|-------|----------|---------|
EOF

for line in "${CONTAINERS[@]}"; do
  cid="${line%% *}"; rest="${line#* }"
  image="${rest%% *}"; name="${rest#* }"

  inspect=$(docker inspect "$cid")

  # Use jq if available, otherwise fall back to minimal parsing
  if command -v jq >/dev/null 2>&1; then
    privileged=$(jq -r '.[0].HostConfig.Privileged' <<<"$inspect")
    run_as_user=$(jq -r '.[0].Config.User // ""' <<<"$inspect")
    cap_add=$(jq -r '.[0].HostConfig.CapAdd // [] | join(";")' <<<"$inspect")
    readonly_root=$(jq -r '.[0].HostConfig.ReadonlyRootfs' <<<"$inspect")
    ports=$(jq -r '.[0].NetworkSettings.Ports | keys[]? // empty' <<<"$inspect" | paste -sd ';' - || true)
    bindings=$(jq -r '.[0].HostConfig.PortBindings | to_entries[]? | "\(.key)->\(.value[]?.HostIp):\(.value[]?.HostPort)"' <<<"$inspect" | paste -sd ';' - || true)
    net_mode=$(jq -r '.[0].HostConfig.NetworkMode // ""' <<<"$inspect")
  else
    privileged="unknown"
    run_as_user=""
    cap_add=""
    readonly_root="unknown"
    ports=""
    bindings=""
    net_mode=""
  fi

  echo "$cid,$name,$image,$privileged,${run_as_user:-},${cap_add:-},$readonly_root,${ports:-},${bindings:-},${net_mode:-}" >> "$CSV_FILE"
  echo "| $name | $image | $privileged | ${run_as_user:-} | ${cap_add:-} | $readonly_root | ${ports:-} | ${bindings:-} | ${net_mode:-} |" >> "$MD_FILE"
done

cat >> "$MD_FILE" <<'EOF'

## Suggested Remediations

- Set non-root user for applicable containers (e.g., `user: 1000:1000`).
- Disable privileged mode; add only minimal `cap_add` if strictly required.
- Enable read-only root filesystem when possible (`read_only: true`).
- Bind sensitive services to localhost or scoped networks; avoid 0.0.0.0.
- Segment containers into dedicated Docker networks per trust zone.
EOF

echo "CSV: $CSV_FILE"
echo "Markdown: $MD_FILE"



