# Kubernetes Gateways

Kubernetes gateways are a new type of resource somewhat early in the development cycle (read: experimental). The primary reason for wanting to use a gateway is to have automatically renewed TLS certificates for non-http TLS endpoints. This is possible with traefik v2.6+ and cert-manager v1.7+.

# Installation instructions

1. Install the needed Kubernetes Custom Resource Definitions (CRDs) to enable the creation of gateway-based resources.
```
kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v0.5.0" | kubectl apply -f -
```

2. Enable traefik to interact with Kubernetes gateways:
```
# Apply required permissions for traefik
kubectl apply -f traefik-rbac.yml

# Patch traefik to enable kubernetes gateway options
kubectl patch deployment traefik -n kube-system --type json -p '[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--experimental.kubernetesgateway=true"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--providers.kubernetesgateway=true"}
]'

# (Optional) If you need cross-namespace capabilities for gateways, add this patch:
kubectl patch deployment traefik -n kube-system --type json -p '[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--providers.kubernetescrd.allowCrossNamespace=true"}
]'
```

3. If you want automatically renewed TLS certfificates via cert-manager/LetsEncrypt, you'll need to perform the following steps:

```
# Enable gateway capabilities for cert-manager
kubectl patch deployment cert-manager -n cert-manager --type json -p '[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--feature-gates=ExperimentalGatewayAPISupport=true"}
]'

# Or, if you're using helm, use:
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager \
  --set "extraArgs={--feature-gates=ExperimentalGatewayAPISupport=true}"
```

4. Create the GatewayClass resource needed to provision future gateways.
```
echo "apiVersion: gateway.networking.k8s.io/v1alpha2
kind: GatewayClass
metadata:
  name: traefik
spec:
  controllerName: traefik.io/gateway-controller" | kubectl apply -f -
```

References:
* https://www.jetstack.io/blog/cert-manager-gateway-api-traefik-guide/
* https://doc.traefik.io/traefik/reference/dynamic-configuration/kubernetes-gateway/
