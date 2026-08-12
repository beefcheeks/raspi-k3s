# Repository Restructuring Plan (review before executing)

Status: **mostly EXECUTED (2026-08).** Groups A–E and the staging teardown (Group D1) are done —
dead app dirs, legacy top-level dirs, orphan namespaces/PVCs, and staging scaffolding are all
removed; the in-cluster mosquitto broker was retired and Traefik slimmed to HTTP-only. See
`BACKLOG.md` for the current state. The remaining item is the untracked asus-router WIP (Group A).
This doc is kept as the historical record of the plan; the sections below describe what *was* done.

The cleanup was grouped by blast radius. Each group was independent.

---

## Group A — Zero-risk cruft (safe now)

- [ ] Delete `ha-scripts.yaml` (0 bytes, empty stray file at repo root).
- [ ] Resolve untracked WIP under `argocd/apps/asus-router/`:
      `resources/ingress.yaml`, `resources/service.yaml`, `files/static-clients.csv` are
      **not referenced** by `asus-router/kustomization.yaml` — an abandoned attempt to
      expose the asus-router manager via ingress. Either wire them in (add to `resources:`
      / `configMapGenerator`) or delete them. Note `static-clients.csv` is chmod 600 and
      looks like it holds client MAC data — decide whether it belongs in git at all
      (probably `.gitignore` it or move to 1Password).

## Group B — Delete legacy pre-Argo-CD top-level dirs (low risk)

These are the original manual-manifest era, fully superseded by `argocd/`. None are wired
into GitOps. Removing them only touches docs/manifests, not the cluster.

- [ ] `deconz/` — never migrated to Argo CD; deCONZ not running.
- [ ] `hyperion/` — never migrated; not running.
- [ ] `pihole/` — replaced by `adguard-home`.
- [ ] `gateway/` — removed (see git history `c690167`).
- [ ] `homebridge/` — removed (`d9fdc5b`).
- [ ] `multus/` — top-level legacy copy (Argo CD copy also disabled, see Group C).
- [ ] `logdna/` — superseded by `argocd/apps/logdna-agent`.
- [ ] `cert-manager/` — superseded by `argocd/apps/cert-manager`.
- [ ] `cloudflare-ddns/` — superseded by `argocd/apps/cloudflare-ddns`.
- [ ] `asus-router/` — superseded by `argocd/apps/asus-router`.
- [ ] Rewrite `README.md` — it still documents the pre-Argo-CD world and links all the dirs
      above. Point it at the Argo CD bootstrap flow (`argocd/README.md`) and CLAUDE.md.
- [ ] Decide on `ubuntu/` — keep only if you still want the Ubuntu install path; otherwise
      drop and keep `raspian/` as the canonical OS guide (refresh it for a current OS image).

## Group C — Delete disabled Argo CD app definitions (low risk, but confirm each)

Defined under `argocd/apps/` but **not** in `argocd/config/prod.yaml`, so not deployed.
Deleting them changes nothing live.

- [ ] `argocd/apps/home-assistant/` — migrated to separate Pi.
- [ ] `argocd/apps/matter-server/` — migrated (HA add-on now).
- [ ] `argocd/apps/openthread-border-router/` — migrated (HA add-on now).
- [ ] `argocd/apps/mock-supervisor/` — only existed to mock the supervisor API for the
      in-cluster OTBR add-on experiment; obsolete post-migration.
- [ ] `argocd/apps/homebridge/` — removed product.
- [ ] `argocd/apps/multus/` — macvlan CNI existed only for HA host-style networking; not
      needed now that HA is off-cluster.
- [ ] `argocd/apps/longhorn/` — never deployed; single node uses `local-path`. Keep only if
      you plan multi-node/replicated storage later.

## Group D — Retire staging (medium risk — touches every app)

There is no staging environment. Staging is a **two-branch setup**, not just directories:
`main` → prod (the live `homelab` appset tracks `revision: main`); `stage` → staging
(`roots/stage.yaml` + `appsets/stage/` track `revision: stage`, `/overlays/stage` defaults).

**Safety confirmed (2026-08):** nothing live reconciles from `stage` — the cluster has only the
prod `homelab` ApplicationSet and a single `root` app; no stage root/appset was ever applied.
The `stage` branch holds no unique work — its one distinct commit duplicates a fix already on
`main`, and `main` is strictly ahead. Deleting it loses nothing.

This is the biggest simplification and the most churn. Two options — **pick one**:

**Option D1 — Strip staging, keep base/overlay layout:**
- [x] **Retired the `stage` git branch** (2026-08) — deleted local + `origin/stage` after
      confirming all 12 live Applications + root + the `homelab` appset track `main` @ HEAD
      and nothing references `stage`. NOTE: `roots/stage.yaml` and `appsets/stage/appset.yaml`
      now reference a deleted branch (`revision: stage`) — harmless (never applied), but delete
      them next.
- [ ] Delete `argocd/config/stage.yaml`, `argocd/roots/stage.yaml`, `argocd/appsets/stage/`.
- [ ] Delete every `argocd/apps/*/overlays/stage/` and stage-only patches.
- [ ] Keep `base/` + `overlays/prod/` per app (cheap insurance if staging ever returns).
- [ ] Delete the leftover `*-stage` items in the 1Password `HomeLab` vault:
      `adguard-login-stage`, `argocd-secret-stage`, `ingress-stage`, `mosquitto-users-stage`,
      `multus-mac-stage` (confirmed present via `op item list`).
- [ ] Also obsolete post-HA-migration (delete with Group C `multus`): 1Password items
      `multus-mac`, `multus-dns-route`.

**Option D2 — Flatten to single environment (most aggressive):**
- [ ] Everything in D1, **plus** collapse each app's `base/` + `overlays/prod/` into one
      flat dir, and drop the `directory` defaulting logic in the appset/config.
- [ ] Simpler to read, but a bigger, riskier diff and harder to reintroduce environments.

> Recommendation: **D1 first.** It removes the dead weight without a risky flatten. Revisit
> D2 only if the base/overlay indirection is actively annoying.

## Group E — Prune orphaned live resources (touches the cluster — do last, with care)

Left behind by the HA migration and removed apps. Back up any data you might want first.

- [ ] `homebridge` namespace + PVC `homebridge` (2Gi) — empty, no workloads.
- [ ] `home-assistant` namespace + PVCs `home-assistant` (2Gi), `matter-server`,
      `openthread-border-router` — old HA data. **Export/back up before deleting** if there's
      anything you didn't migrate.
- [ ] `cloudflare-tunnel` namespace — empty (app removed in `c690167`).
- [ ] Confirm no lingering `helm-install-traefik*` completed jobs matter (they're inert).

---

## Suggested order

1. Group A (now).
2. Group B + C together (one "chore: remove legacy manifests" PR).
3. Group D1 (one "refactor: drop staging" PR).
4. Group E (separate, deliberate, after backups) — this is the only group that mutates the
   cluster, so keep it isolated and reversible.
