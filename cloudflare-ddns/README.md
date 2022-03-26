# Cloudflare Dynamic DNS

If you want to set up dynamic DNS and you use cloudflare, you can run [cloudflare-ddns](https://github.com/oznu/docker-cloudflare-ddns). Create an access token with the correct permissions as specified in their GitHub README. To install, run:
```
NAMESPACE=cloudflare-ddns
ZONE=mydomain.com
SUBDOMAIN=mysubdomain
TOKEN=your-token

kubectl create ns ${NAMESPACE}
kubectl create configmap -n ${NAMESPACE} cloudflare-ddns --from-literal=zone=${ZONE} --from-literal=subdomain=${SUBDOMAIN}
kubectl create secret generic -n ${NAMESPACE} cloudflare-ddns --from-literal=apikey=${TOKEN}

kubectl apply -n ${NAMESPACE} -f cloudflare-ddns.yml
```