# CLAUDE.md

Guidance for working in this repository. Read this first.

## What this is

A **single-node** Raspberry Pi 4 homelab running a [k3s](https://k3s.io) Kubernetes
cluster, managed entirely via **GitOps with Argo CD**. The repo is the source of truth;
Argo CD continuously reconciles the cluster to match `main`.

- **Node:** `raspberrypi` (10.0.0.10), control-plane+master, single node.
- **kubectl context:** `homepi4` (already configured on this machine).
- **k3s is installed with `--disable traefik`** — Traefik is managed by Argo CD instead
  (we need features the bundled chart doesn't expose). Don't assume k3s-bundled Traefik.
- There is **no staging environment** anymore. Only `prod` is live. (Staging scaffolding
  still exists in the tree — see "Known drift" below — but nothing deploys it.)

## Architecture: how deployment works

Everything flows through one Argo CD `ApplicationSet` (`homelab`):

1. `argocd/roots/prod.yaml` — the root Application, points Argo CD at `argocd/appsets/prod`.
2. `argocd/appsets/prod/appset.yaml` — the `homelab` ApplicationSet. A **git-file +
   list matrix generator** that reads `argocd/config/prod.yaml`.
3. **`argocd/config/prod.yaml` is the enabled-apps manifest.** Only apps listed here are
   deployed. Each entry sets `app`, `namespace`, sync `wave`, and optional `directory`
   (defaults to `/overlays/prod`), `syncOptions`, `manualSync`, `prune`, `selfHeal`.
4. Each app's manifests live under `argocd/apps/<app>/` and are rendered with Kustomize
   (Helm enabled). Apps use either a flat layout (`directory: "/"`) or a
   `base/` + `overlays/prod/` layout (the default).

**Sync waves** (RollingSync, ordered): `0` onepassword → `1` asus-router, cert-manager,
logdna-agent, traefik → `2` argocd → `3` adguard-home, argocd-ingress, cloudflare-ddns,
ha-ingress, mosquitto.

> An app directory existing under `argocd/apps/` does **not** mean it's deployed. Check
> `argocd/config/prod.yaml`. Several app dirs are defined but disabled (dead weight).

### Currently enabled apps (must match the live cluster)

`onepassword · asus-router · cert-manager · logdna-agent · traefik · argocd ·
adguard-home · argocd-ingress · cloudflare-ddns · ha-ingress · mosquitto`

To **enable/disable an app**, edit `argocd/config/prod.yaml` — do not `kubectl apply`
manifests directly.

## Home Assistant (lives on a SEPARATE Pi)

Home Assistant and its companions (Matter server, OpenThread Border Router, add-ons) were
migrated **off this cluster** onto a dedicated Pi, managed via Home Assistant's own
add-on / HACS ecosystem — **not** this repo. This cluster only provides two pieces of glue:

- **`ha-ingress`** — TLS termination + reverse proxy for HA. A selector-less `Service`
  plus a manually-managed `Endpoints` object pointing at the HA Pi's IP, fronted by a
  Traefik `Ingress` with cert-manager (Let's Encrypt) certs for the internal and external
  hostnames. This is why HA depends on the cluster: **the cluster does HA's SSL.**
- **`mosquitto`** — MQTT broker that HA (and Zigbee/Matter stacks on the HA Pi) connect to.

The `argocd/apps/{home-assistant,matter-server,openthread-border-router,mock-supervisor}`
directories are **legacy** in-cluster definitions from before the migration and are not
deployed. Treat them as stale.

## Secrets

Secrets come from **1Password** via **argocd-vault-plugin**. Manifests reference vault
paths with the `avp.kubernetes.io/path: "vaults/homelab/items/<item>"` annotation and use
`<placeholder>` tokens (e.g. `<home-assistant>`, `<ip-address-home-assistant>`) that AVP
substitutes at render time. The `onepassword` app (Connect + operator, wave 0) and
`OnePasswordItem` CRs handle in-cluster secret sync. **Never commit real secret values**;
add a placeholder + vault path instead.

## DNS & networking

- **Internal:** `staatz.co` — resolves only on the LAN via **AdGuard Home** (`adguard-home`).
- **External:** `therexhouse.com` — public, dynamic IP kept current by `cloudflare-ddns`.
- Ingress/LoadBalancer via Traefik + k3s servicelb (`svclb-*` daemonsets).

## Conventions

- **GitOps only.** Change the repo and let Argo CD sync. Don't hand-edit live resources
  except for genuine break-glass debugging (and reconcile the repo after).
- **Vendored Helm charts** (`argocd/apps/*/charts/**`, `argocd/appsets/*/charts/**`) are
  git-ignored (`**/charts/**`) and pulled/rendered at sync time. Don't hand-edit them; bump
  the chart version in the app's `kustomization.yaml`/`values.yaml` instead.
- **Commit style:** Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`).
- **Kustomize with Helm:** render locally with `kubectl kustomize --enable-helm <path>`.
- Match existing manifest style; keep changes surgical and traceable to the request.

## Access surfaces (for Claude)

- **Cluster:** `kubectl` against the `homepi4` context (read/apply). Prefer read-only
  inspection; make changes via git, not `kubectl apply`.
- **Repo:** this directory.
- **Home Assistant:** connected via MCP (the official HA Assist-pipeline server —
  `Home_Assistant_MCP__*` tools). Good for reading state / controlling devices. For
  building automations/dashboards/traces, a more capable HA MCP can be added (see repo
  discussion).

## Known drift / cleanup backlog

See `docs/RESTRUCTURE.md` and `docs/UPGRADE-AUDIT.md` for the full inventory. In short:

- Legacy pre-Argo-CD top-level dirs (`deconz/ gateway/ hyperion/ pihole/ homebridge/
  multus/ logdna/ cert-manager/ cloudflare-ddns/ asus-router/`) are superseded by `argocd/`.
- Disabled app dirs under `argocd/apps/` (HA stack, homebridge, multus, longhorn).
- Orphaned empty namespaces (`homebridge`, `home-assistant`, `cloudflare-tunnel`) and
  stale PVCs left over from the HA migration.
- Staging scaffolding (`config/stage.yaml`, `roots/stage.yaml`, `appsets/stage/`,
  per-app `overlays/stage/`) with no environment behind it.
- Versions behind (k3s 1.28 is EOL; see the upgrade audit).
