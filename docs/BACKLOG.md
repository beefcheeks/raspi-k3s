# Backlog / Task Tracker

Living list of homelab work. Priority: **P0** now, **P1** soon, **P2** low/when-convenient.
Larger plans have their own docs: [`RESTRUCTURE.md`](./RESTRUCTURE.md),
[`UPGRADE-AUDIT.md`](./UPGRADE-AUDIT.md).

## In progress

### Tooling / access
- [x] **P0 — Set up MCP servers** so Claude can build against HA and read historic logs.
  - [x] `ha-mcp` (homeassistant-ai) → connected direct to HA Pi at
        `http://10.0.0.9:8123/api/webhook/mcp_…` (cluster-independent, survives degraded states).
  - [x] `mezmo-mcp` (remote) → connected at `https://mcp.mezmo.com/mcp`.
  - [x] Restarted + smoke-tested: Mezmo (~20k lines/hr flowing; classic ingestion, no v3
        pipelines) and ha-mcp (985 entities, HA 2026.8.0) both healthy.
- [x] **P1 — 1Password CLI (`op`) access** for Claude — read-only `HomeLab` service-account
      token, scoped to that vault only (verified: sees no other vaults; work session untouched).
      Token lives in this session's scratchpad, injected per-command, never in shell profile.

### Home Assistant glue (this cluster)
- [ ] **P1 — MQTT `protocol_5_migration`.** HA is flagging a Repair on the MQTT integration:
      Mosquitto must migrate to MQTT protocol 5. HA says it **breaks in HA 2027.1.0**. Mosquitto
      is our app (`argocd/apps/mosquitto`), so plan the broker/client config migration before
      that HA release. (Surfaced via ha-mcp overview repairs.)

### Asus router (creds in 1Password `HomeLab` vault: `router-ssh-key`, `router-ssh-config`, `router-dns`)
- [ ] **P1 — Firmware stuck / "red" status.** Router UI shows red and won't flash to the next
      firmware version. Investigate why (bad partition? unsupported jump? Merlin vs stock?
      storage full?) and get it to a clean upgradeable state.
- [ ] **P2 — Settings audit.** Full review of router config (firewall, port forwards, DHCP
      reservations / the `static-clients.csv`, DNS pointing at AdGuard, WireGuard/OpenVPN,
      AiProtection, guest nets, UPnP). Cross-check against what `asus-router-manager` expects.

### Dashboards
- [ ] **P2 — Kitchen iPad Mini dashboard.** Build a wall/kitchen HA dashboard tuned for the
      iPad Mini (kiosk-friendly, big touch targets, likely a custom Lovelace view or a
      dashboard tool). Depends on `ha-mcp` being connected for authoring.

## Planned (see linked docs)
- [ ] **Repo restructure** — legacy dir cleanup + staging teardown. See `RESTRUCTURE.md`.
- [ ] **Version upgrades** — k3s off EOL 1.28, then container images. See `UPGRADE-AUDIT.md`.
- [ ] Sequencing: finish tooling/MCP/state accounting **first**, then plan the actual
      updates/migration.

## Done
- [x] 2026-08 — Initial codebase-vs-cluster audit; wrote `CLAUDE.md`, `RESTRUCTURE.md`,
      `UPGRADE-AUDIT.md`.
