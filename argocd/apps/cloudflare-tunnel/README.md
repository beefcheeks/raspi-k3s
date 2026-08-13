# cloudflare-tunnel

Exposes Home Assistant externally **without a router port-forward**. The `cloudflared` daemon makes an
**outbound-only** connection to Cloudflare; inbound requests for `ha.therexhouse.com` ride that
tunnel to HA. Removes the `443 → Pi` WAN forward and hides the home IP.

> Modernized replacement for the old `cloudflare-tunnel` app (removed in `c690167`): that used
> the now-deprecated helm chart + reformatted `credentials.json`. This uses the current
> **token** model (a single `TUNNEL_TOKEN`), so the Deployment is trivial and routing lives in
> the Cloudflare dashboard.

## One-time setup (do before enabling the app)

1. **Cloudflare Zero Trust → Networks → Tunnels → Create a tunnel** (type: *Cloudflared*), name
   e.g. `homelab`.
2. Add a **Public Hostname**: `ha.therexhouse.com` → **Service**. Pick a target:
   - **Simple:** `http://10.0.0.9:8123` (HA directly). Requires HA to trust the cluster pod
     network as a proxy — in HA `configuration.yaml`:
     ```yaml
     http:
       use_x_forwarded_for: true
       trusted_proxies:
         - 10.42.0.0/16   # k3s pod network (cloudflared pod)
     ```
   - **Consistent with today:** point at the cluster's `ha-ingress` Traefik service (keeps the
     existing proxy chain; HA already trusts Traefik). Needs Host header `ha.therexhouse.com` +
     `noTLSVerify` for the internal cert.
   - **Do NOT** attach a Cloudflare **Access** policy (that adds the login interstitial that
     breaks the Withings OAuth callback). If you later want Access on the HA login, add a
     **Bypass** rule for `/auth/*`, the OAuth callback path, and `/api/webhook/*`.
3. Copy the tunnel **token** (from the "run" command Cloudflare shows) into 1Password:
   vault `homelab`, item **`cloudflare-tunnel`**, field **`token`**.
4. **Enable the app:** add to `argocd/config/prod.yaml` (wave `3`, namespace `cloudflare-tunnel`).
   ArgoCD deploys it; the `OnePasswordItem` syncs the token to the `cloudflare-tunnel` secret.

## Cutover / rollback

- Once the tunnel shows **healthy** and `https://ha.therexhouse.com` loads through it (test the
  Withings OAuth round-trip + companion-app WebSocket): point the `ha.therexhouse.com` DNS record
  at the tunnel (`<id>.cfargotunnel.com` CNAME — the dashboard offers to do this), then **remove
  the `443 → 10.0.0.10` port-forward** on the router (and optionally the `8443` remote-admin).
- `cloudflare-ddns` stays; the `ha.therexhouse.com` record just becomes a tunnel CNAME instead of
  an A record.
- **Rollback:** re-add the port-forward and repoint DNS to the WAN IP; remove this app from
  `config/prod.yaml`.

## Notes
- Free plan: 100 MB per-request upload cap (fine for HA UI/OAuth; matters only for big
  backups/media through the tunnel).
- Routing config lives in the Cloudflare dashboard (token model). To keep ingress rules in git
  instead, switch to a `config.yaml` ConfigMap + `credentials.json` secret and
  `tunnel --config ... run` — ask if you'd prefer that GitOps-pure variant.
