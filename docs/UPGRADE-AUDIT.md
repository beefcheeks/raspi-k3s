# Version Audit & Upgrade Runbook (audit only — no upgrades applied)

Snapshot date: 2026-08. Priorities per owner: **k3s + container images first**, Pi OS
deferred (an in-place `apt update && apt full-upgrade` is fine for now). Willing to switch
image org/provider when the newer one is better-supported.

## Summary table

| Component | Running | Latest (2026-08) | Gap | Priority |
|---|---|---|---|---|
| **k3s** | `v1.28.7+k3s1` | `v1.36.2+k3s1` | 8 minors; **1.28 is EOL** | **High** |
| Pi OS | Debian 11 bullseye | Debian 12 bookworm / 13 trixie | 1–2 majors | Low (defer) |
| Argo CD (chart) | `7.7.5` (app `v2.13.1`) | chart `10.3.0` (app **v3.x**) | major, **v2→v3** | High |
| Traefik (chart, vendored) | `33.0.0` (app `v3.2.0`) | chart `40.3.0`/`41.0.0` (app `v3.7.4`) | 7+ chart majors, same major v3 | Medium |
| cert-manager | `v1.16.1` | `v1.21.1` | 5 minors | Medium |
| AdGuard Home | `v0.107.54` | `v0.107.78` (stable) | patch/minor | Low |
| Mosquitto | `2.0.18` | `2.0.x` latest (2.1.2 exists) | patch (or new 2.1) | Low |
| 1Password Connect / operator | `1.7.3` / `1.8.1` | verify latest | unknown | Low |
| cloudflare-ddns (favonia) | `1.15.0` | `1.17.0` | 2 minors | Low |
| logdna-agent | `3.9.1` | `stable` tag (still `logdna` org) | minor | Low |
| logdna-rsyslog | `latest` (**untagged!**) | your own beta project | pin a digest | Low |
| coredns / metrics-server / local-path / klipper-lb | bundled | ships with k3s | upgraded *by* k3s | — |

> The last row upgrades automatically when k3s upgrades — don't bump them independently.

---

## k3s upgrade (do this first)

**Why:** 1.28 is end-of-life (no security patches). **How:** respect the Kubernetes version
skew policy — **no skipping minor versions.**

Path: `1.28 → 1.29 → 1.30 → 1.31 → 1.32 → 1.33 → 1.34 → 1.35 → 1.36`

**Two hard checkpoints:**
1. **etcd 3.5 → 3.6 (introduced in k3s v1.34+):** there is *no safe path* unless you first
   run **etcd ≥ 3.5.26**, which ships in the **Jan-2025 k3s v1.32** releases. So: **stop at
   v1.32, let it settle, then continue past 1.34.** Skipping this can corrupt cluster data.
2. **k3s-bundled Traefik v2→v3 at v1.32:** **N/A for us** — k3s runs with `--disable traefik`
   and Traefik is managed by Argo CD. This cluster is unaffected by that change.

**Per-minor procedure (single node):**
```bash
# 0. BACK UP FIRST (k3s uses embedded etcd/sqlite; snapshot both the datastore and the SD/SSD)
sudo k3s etcd-snapshot save        # if using etcd; otherwise back up /var/lib/rancher/k3s
sudo cp -a /etc/rancher/k3s /root/k3s-config-backup

# 1. Upgrade one minor at a time (re-run the installer pinned to the next minor)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik" \
  INSTALL_K3S_VERSION="v1.29.X+k3s1" sh -

# 2. Verify before the next hop
kubectl get nodes            # Ready, new version
kubectl get pods -A          # all Running/Completed
kubectl get applications -n argocd   # all Synced/Healthy
```
Keep `--disable traefik` on **every** re-install or k3s will re-enable bundled Traefik and
collide with the Argo CD one. Pause between minors to confirm Argo CD apps stay healthy.

Consider the [system-upgrade-controller](https://docs.k3s.io/upgrades/automated) for
hands-off minor hops, but on a single node the manual loop above is fine and more legible.

## Container images (via GitOps — bump in repo, let Argo CD sync)

Order by risk, lowest first:

1. **cloudflare-ddns** `1.15.0 → 1.17.0` — patch statefulset image tag. Trivial.
2. **cert-manager** `v1.16.1 → v1.21.1` — bump chart/image; check CRD upgrade notes per
    minor (Gateway API additions in 1.20). Low-risk, well-behaved upgrades.
3. **AdGuard Home** `v0.107.54 → v0.107.78` — stay on the `0.107` **stable** line; avoid the
    `0.108.x` betas.
4. **Mosquitto** `2.0.18 → latest 2.0.x`. `2.1.x` is a new minor — only jump if you want its
    features; 2.0.x is the conservative pin.
5. **1Password Connect/operator** — verify current latest, then bump `values.yaml` in
    `argocd/apps/onepassword`.
6. **Traefik** vendored chart `33.0.0 → 40.x/41.x` (app `v3.2.0 → v3.7.4`). Same major (v3),
    but **7+ chart majors** — read the chart CHANGELOG for values-schema breaks (this chart
    is vendored under `argocd/apps/traefik/charts/`, which is git-ignored, so re-vendor or
    switch to a remote chart ref in `kustomization.yaml`). Do this **after** k3s is stable,
    since Traefik is the ingress path for everything.
7. **Argo CD** chart `7.7.5 → 10.3.0` (app **v2.13.1 → v3.x**). This is the touchiest — a
    **major app upgrade (v2→v3)** and a self-managed component (it upgrades itself via the
    `argocd` app, wave 2). Read the v3 upgrade/breaking-change notes, upgrade **last**, and
    have the `kubectl kustomize --enable-helm argocd/bootstrap | kubectl apply -f -`
    break-glass path ready in case self-sync wedges.

## logdna-rsyslog / logdna-agent (decide, low urgency)

- LogDNA is now **Mezmo**; the agent image is still published as `logdna/logdna-agent` with
  Mezmo branding rolling in gradually. Use the `stable` tag or a pinned recent version.
- `logdna-rsyslog:latest` is **untagged** — pin it to a specific tag/digest for
  reproducibility (it's your own beta project; 12 commits, `logdna` org).
- No forced migration today. Revisit if you consolidate on a different log backend (see the
  Mezmo MCP note — you may want to keep Mezmo in the loop for historic-log queries).

## Pi OS (deferred)

- Current: Debian 11 **bullseye** (oldstable; approaching EOL). Options:
  - **Now:** `sudo apt update && sudo apt full-upgrade` within bullseye for current patches.
  - **Later:** reimage to a current Raspberry Pi OS (bookworm) on fresh SSD/SD and restore —
    cleaner and less risky than an in-place `bullseye → bookworm` dist-upgrade on a 4-year-old
    install. Do this as its own project with a full backup and the k3s snapshot in hand.

---

## Sources

- k3s releases / upgrade path — https://docs.k3s.io/upgrades and https://github.com/k3s-io/k3s/releases
- Argo CD Helm chart — https://artifacthub.io/packages/helm/argo/argo-cd
- Traefik Helm chart — https://github.com/traefik/traefik-helm-chart/releases
- cert-manager — https://artifacthub.io/packages/helm/cert-manager/cert-manager
- AdGuard Home — https://github.com/AdguardTeam/AdGuardHome/releases
- Mosquitto — https://github.com/eclipse-mosquitto/mosquitto/releases
- cloudflare-ddns — https://github.com/favonia/cloudflare-ddns/releases
- logdna-agent-v2 — https://github.com/logdna/logdna-agent-v2
