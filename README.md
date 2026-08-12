# raspi-k3s

A **single-node Raspberry Pi 4 homelab** running a [k3s](https://k3s.io) Kubernetes cluster,
managed entirely via **GitOps with [Argo CD](https://argo-cd.readthedocs.io)**. This repo is the
source of truth — Argo CD continuously reconciles the cluster to match `main`.

## Start here

- **[CLAUDE.md](CLAUDE.md)** — how the repo and cluster fit together: the GitOps architecture, the
  enabled-apps mechanism, sync waves, secrets, and conventions. **Read this first.**
- **[argocd/README.md](argocd/README.md)** — bootstrapping k3s + 1Password + Argo CD from scratch.
- **[docs/](docs/)** — [`BACKLOG.md`](docs/BACKLOG.md) (task tracker),
  [`UPGRADE-AUDIT.md`](docs/UPGRADE-AUDIT.md) (version status + upgrade runbook),
  [`RESTRUCTURE.md`](docs/RESTRUCTURE.md) (cleanup plan).

## What's running

Everything deploys through one Argo CD `ApplicationSet` that reads
[`argocd/config/prod.yaml`](argocd/config/prod.yaml) — the enabled-apps manifest. An app directory
existing under `argocd/apps/` does **not** mean it's deployed; that file is the source of truth.
Currently live:

`onepassword · asus-router · cert-manager · logdna-agent · traefik · argocd ·
adguard-home · argocd-ingress · cloudflare-ddns · ha-ingress`

Home Assistant runs on a **separate Pi** (managed via its own add-on / HACS ecosystem, not this
repo); this cluster only provides its TLS-terminating ingress (`ha-ingress`). See CLAUDE.md.

## OS install guides

- **[Raspberry Pi OS + k3s](raspian/README.md)** (recommended)
- **[Ubuntu + k3s](ubuntu/README.md)**
