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
- [x] **MQTT `protocol_5_migration` — resolved by moving MQTT off-cluster.** Chased the failure
      to a stale broker name (`mosquitto.mosquitto`) + split-horizon DNS; rather than keep patching,
      HA now runs a **local Mosquitto add-on** (`core-mosquitto`, protocol 5). k3s `mosquitto` app
      retired (see Done). Verify the repair badge clears on HA's next re-eval/restart.

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
- [ ] **Version upgrades** — see `UPGRADE-AUDIT.md`. **k3s 1.28→ is next and must come first:**
      cert-manager/argocd/traefik bumps are gated on it (cert-manager 1.21 needs k8s 1.33+).
  - [x] Pure-container warm-up bumps rolled out: adguard `v0.107.78`, cloudflare-ddns `1.17.0`
        (+ migrated DDNS `IP4_PROVIDER` ipify→cloudflare.trace). Verified Synced/Healthy.
  - [ ] cert-manager `v1.16.1 → v1.21.1` — **deferred, gated on k3s ≥1.33.**
  - [ ] Verify argocd 10.x / traefik 40.x min-k8s before bumping (likely also k3s-gated).
- [ ] **k3s upgrade** — step 1.28→1.32 (etcd 3.5.26 checkpoint), then →1.36. Needs etcd
      snapshot + SD/SSD backup first. See `UPGRADE-AUDIT.md` runbook.
- [ ] **Traefik simplification** (unlocked by mosquitto removal — it was the *only* Gateway API user):
  - [ ] **Phase 2 (now):** slim the custom Traefik — drop the `mqtts:8883` entrypoint, the
        `kubernetesGateway` provider (`experimentalChannel`), and the hand-pinned experimental
        Gateway API CRDs. Leaves Traefik HTTP-only; also de-risks the Traefik 33→40 chart bump.
  - [ ] **Phase 3 (with k3s upgrade):** evaluate collapsing custom Traefik → k3s **bundled**
        Traefik (v3 at k3s 1.32+). Move `externalTrafficPolicy: Local`, `replicas: 2`, and the
        `ip-allow-list`/`https-redirect` middlewares to a `HelmChartConfig` + middlewares manifest;
        remove `--disable traefik` from the k3s server args. Riskier (ingress-path cutover).
  - [ ] Remove the stale `mq.staatz.co` rewrite from AdGuard (`adguard-home` config) — batch with
        a Traefik restart to avoid an extra DNS blip.

## Done
- [x] 2026-08 — Initial codebase-vs-cluster audit; wrote `CLAUDE.md`, `RESTRUCTURE.md`,
      `UPGRADE-AUDIT.md`.
- [x] 2026-08 — Connected MCPs (ha-mcp, mezmo) + scoped `op` access; verified all live.
- [x] 2026-08 — Retired the dormant `stage` git branch (local + `origin/stage`).
- [x] 2026-08 — Rolled out warm-up image bumps (adguard, cloudflare-ddns) via GitOps and
      verified the rollout on-cluster.
- [x] 2026-08 — Migrated MQTT off-cluster: HA now uses a local Mosquitto add-on broker; removed
      the k3s `mosquitto` app (statefulset + Gateway + TCPRoute + cert) via GitOps.
