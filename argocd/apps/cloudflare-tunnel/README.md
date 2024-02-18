## Cloudflare Tunnel

Mitigates the need for port-forwarding on your router by creating a cloudflare tunnel instead.

# Secrets
Take the token value output in the Tunnel creation web flow and base64 decode it:
```
TOKEN=<my-token>
credentials.json=$(printf $TOKEN | base64 -d)
echo $credentials.json
```
