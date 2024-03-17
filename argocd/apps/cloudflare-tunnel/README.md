## Cloudflare Tunnel

Mitigates the need for port-forwarding on your router by creating a cloudflare tunnel instead.

# Secrets
During the tunnel creation flow in the cloudflare web portal you will be prompted with client install instructions. Select the Docker instructions and copy the full value of the token within the docker CLI command. Reformat this token to be compatible with the cloudflare-tunnel helm chart with the following script:
```
TOKEN=<token>
JSON_CREDS=$(printf $TOKEN | base64 -d | jq -c '.["AccountTag"] = .a | .["TunnelID"] = .t | .["TunnelSecret"] = .s | del(.a, .t, .s)')
```
The value of `JSON_CREDS` is used in a Kubernetes secret as the value of the `credentials.json` key. I configure the cloudflare-tunnel helm chart to point to the `cloudflare-tunnel` Kubernetes secret.
