# Bootstrapping

In order to use Argo CD and some of its applications effectively, some initial bootstrapping is required.

## 1Password

I use 1Password to manage my secrets, including through Argo CD. To do so, you'll need to create the required configuration in 1Password, as well as apply the credentials as secrets to your Kubernetes cluster.

Configure 1Password and generate credentials
```
op vault create HomeLab
op connect server create homelab --vaults HomeLab # creates 1password-credentials.json file in your working directory
TOKEN=$(op connect token create homelab --server homelab --vault HomeLab)
```

Apply credentials as Kubernetes secrets
```
NAMESPACE=onepassword
JSON_FILEPATH='./1password-credentials.json'
kubectl create namespace $NAMESPACE
kubectl create secret generic op-credentials -n $NAMESPACE --from-literal=1password-credentials.json=$(cat $JSON_FILEPATH | base64)
kubectl create secret generic onepassword-token -n $NAMESPACE --from-literal=token=$TOKEN
```

With those secrets in place, once ArgoCD is fully configured, it will install 1Password connect and its corresponding operator.

## Argo CD

[Argo CD](https://argo-cd.readthedocs.io) is a continuous deployment tool designed for Kubernetes.

Install CLI (macOS)
```
brew install argocd
```

Bootstrap Argo CD into Kubernetes and apply initial project and applicationset configurations
```
kubectl kustomize --enable-helm argocd/config | kubectl apply -f -
```

Wait for pods to finish starting and then check clusters
```
# Namespace needs to be argocd for cluster check to work
kubectl config set-context --current --namespace=argocd
argocd cluster list
```

Add relevant git repo (this one)
```
argocd repo add --name homelab https://github.com/beefcheeks/raspi-k3s
```

## References
- https://developer.1password.com/docs/connect/get-started/?method=1password-cli#step-1
- https://github.com/kubernetes-sigs/kustomize/issues/4658