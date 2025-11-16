# Hardening Results & Runbook

This document tracks measurable hardening changes and provides a repeatable runbook suitable for contractor engagements.

## Before/After Metrics
- Database exposure: 0.0.0.0 -> localhost-only
- Privileged containers: tbd -> target 0
- Containers running as root: tbd -> target minimal
- Read-only rootfs enabled: tbd -> target maximal
- Publicly bound ports reduced: tbd -> target minimal

## How to Generate Evidence
```bash
# Read-only audits (safe on Unraid)
./scripts/hardening-audit.sh
./scripts/scan-all-containers.sh

# Review outputs
findings/hardening-audit.csv
findings/hardening-audit.md
findings/vulnerability-summary.csv
findings/vulnerability-summary.md
```

## Recommended Controls
- Bind sensitive services to localhost or internal networks only
- Set non-root user for containers that support it
- Remove `privileged: true` and drop unneeded capabilities
- Enable `read_only: true` and write-specific volumes
- Segment services across dedicated Docker networks

## Implementation Notes
- Apply changes incrementally; validate service health after each change
- For stateful services (DB), plan short maintenance windows
- Keep original compose/run params for quick rollback

## Portfolio Tips
- Capture before/after command outputs
- Include CSV/MD artifacts in `findings/`
- Summarize impact in executive terms (risk reduced, blast radius narrowed)

