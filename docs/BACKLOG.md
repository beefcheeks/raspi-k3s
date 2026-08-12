# Backlog / Task Tracker

Living list of homelab work. Priority: **P0** now, **P1** soon, **P2** low/when-convenient.
Larger plans have their own docs: [`RESTRUCTURE.md`](./RESTRUCTURE.md),
[`UPGRADE-AUDIT.md`](./UPGRADE-AUDIT.md).

## In progress

### Tooling / access
- [x] **P0 — Set up MCP servers** so Claude can build against HA and read historic logs.
  - [x] `ha-mcp` (homeassistant-ai) → connected direct to the HA Pi's local MCP webhook
        (cluster-independent, survives degraded states).
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
- [x] **Repo restructure — dead-dir cleanup done.** Removed 7 disabled app dirs + 10 legacy
      top-level dirs + orphan namespaces/PVCs (homebridge, home-assistant, cloudflare-tunnel).
  - [ ] **Remaining:** rewrite `README.md` (still links deleted dirs); **staging teardown**
        (Group D: `config/stage.yaml`, `roots/stage.yaml`, `appsets/stage/`, per-app
        `overlays/stage/`). See `RESTRUCTURE.md`.
- [x] **Version upgrades — DONE (2026-08).** See `UPGRADE-AUDIT.md`. k3s `1.28 → 1.36`, then all the
      k8s-coupled bumps: cert-manager `1.21`, traefik chart `40.3.0` (v3.7.4), argocd `10.3.2` (**v3.5.0**).
  - [x] Pure-container warm-up bumps rolled out: adguard `v0.107.78`, cloudflare-ddns `1.17.0`
        (+ migrated DDNS `IP4_PROVIDER` ipify→cloudflare.trace). Verified Synced/Healthy.
  - [x] cert-manager `v1.16.1 → v1.21.1` — **done (2026-08)**; Synced/Healthy on k3s 1.36.
  - [x] traefik chart `33.0.0 → 40.3.0` (Traefik `v3.2 → v3.7.4`) — **done (2026-08)**, custom
        ArgoCD-managed chart; zero-downtime roll (RollingUpdate maxUnavailable=0, replicas 2).
  - [x] argocd `7.7.5 → 10.3.2` (v2.13.1 → **v3.5.0**) — **done (2026-08)**, zero-downtime self-upgrade.
        Two safety pins added: `application.resourceTrackingMethod: label` (v3 flips the default to
        annotation → would force mass re-adoption) and `global.networkPolicy.create: false` (chart 10
        defaults netpols on; the old chart created none). AVP CMP sidecar survived the major bump;
        all 11 apps re-rendered Synced/Healthy. **Follow-ups (optional):** migrate tracking to
        `annotation` and enable NetworkPolicies as separate, tested changes.
- [x] **k3s upgrade — DONE (2026-08): 1.28 → 1.36.3+k3s1**, one minor at a time (SQLite datastore
      → no etcd checkpoint; `--disable traefik` preserved throughout). Lesson: **pace hops on this
      Pi** — batching 4 back-to-back overloaded the SQLite datastore (16s kine writes, load ~13);
      settle pods *and* load back to baseline between each hop.
- [ ] **Traefik simplification** (unlocked by mosquitto removal — it was the *only* Gateway API user):
  - [ ] **Phase 2 (now):** slim the custom Traefik — drop the `mqtts:8883` entrypoint, the
        `kubernetesGateway` provider (`experimentalChannel`), and the hand-pinned experimental
        Gateway API CRDs. Leaves Traefik HTTP-only; also de-risks the Traefik 33→40 chart bump.
  - [~] **Phase 3 — bundled-Traefik cutover ATTEMPTED (2026-08) then ROLLED BACK.** Moved the app
        to a `HelmChartConfig` + middlewares manifest and removed `--disable traefik`. It failed for
        two reasons: (1) the bundled `traefik`/`traefik-crd` `HelmChart` CRs had been **stuck
        terminating since 2024-03-17** (leftover `wrangler.cattle.io/helm-controller` finalizer from
        the original disable) so k3s's install manifest was a no-op against them; (2) after clearing
        the finalizers, the bundled `traefik-crd` chart **could not adopt the existing CRDs** (custom
        chart applied them non-helm-owned; install uses `--force-conflicts=false`), so the `traefik`
        chart's `validate-install-crd` failed *"Required CRDs are missing."* Recovered by reverting to
        the custom chart (`92b2221`) and re-adding `--disable traefik` via
        `/etc/rancher/k3s/config.yaml`. **Cost: a multi-minute ingress outage.** Lesson: bundled
        cutover needs a planned window + pre-cleaned CRDs + traefik-crd-before-traefik ordering.
  - [x] **Chosen path instead of Phase 3: bumped the custom Traefik chart `33.0.0 → 40.3.0`**
        (2026-08). ArgoCD-managed, no k3s helm-controller / CRD-adoption dance — clean zero-downtime
        roll to `v3.7.4`, all apps Synced/Healthy. Bundled cutover shelved (see Phase 3 above).
        Note: chart 40 no longer bundles the Gateway API CRDs, so 5 empty `gateway.networking.k8s.io`
        CRDs now linger (untracked, 0 CRs) — trivial optional `kubectl delete crd` cleanup.
  - [ ] Remove the stale MQTT-hostname rewrite from AdGuard (`adguard-home` config) — batch with
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
- [x] 2026-08 — Slimmed Traefik to HTTP-only (dropped the Gateway API/mqtts machinery +
      experimental CRDs + `experimentalChannel`); closed public `8883`. De-risks the Traefik bump.
- [x] 2026-08 — Deleted dead app dirs, legacy pre-ArgoCD dirs, and orphan namespaces/PVCs.
      Cluster + repo now down to only live, in-use apps (10 + root).
- [x] 2026-08 — Repo tidy: removed staging scaffolding (Group D1), rewrote README, scrubbed real
      domains from the public docs, gitignored the router device-inventory CSV.
- [x] 2026-08 — AirGradient static IPs: reserved Back Open Air (`.62`), Landing ONE (`.136`), and
      the TV Room AiMesh node (`.3`); removed 3 stale container ghosts. Fixed `configure.sh` to
      `nvram commit` + reload dnsmasq so reservations actually persist/apply. (Router surveyed:
      ZenWiFi BQ16 Pro, stock FW 3.0.0.6 — feeds the P1 firmware item.)
