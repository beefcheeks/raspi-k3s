# Homebridge

## Overview

Homebridge is a useful tool for converting existing smart devices into homekit compatible ones. You can learn more [here](https://homebridge.io). Running it in a container helps isolate it from other applications and their dependences running on your pi.

## Bluetooth

By default, this container runs with access to bluetooth as some of the homebridge plugins I use require it. If you are using Ubuntu only (NOT Raspian), prior to installing homebridge, be sure disable the bluetooth service on your pi host so it does not conflict with the one running inside the container:
```
ssh ubuntu@${IP_ADDRESS} "sudo systemctl stop bluetooth && sudo systemctl disable bluetooth"
```

## External ingress

If you want to access your homebridge instance outside of your home or trigger webhooks from external services, you'll almost certainly want to set up https (see [cert-manager SSL hosting via LetsEncrypt](../cert-manager/README.md)) as well as basic authentication to prevent unauthorized access. For basic auth, you'll need to generate a secret that will be used by the external ingress in the homebridge helm chart.
```
FILENAME=basic-auth
NAMESPACE=homebridge
SECRET_NAME=ingress-basic-auth
USERNAME=username
htpasswd -c ./${FILENAME} ${USERNAME}
# Enter password into prompt
kubectl create secret generic ${SECRET_NAME} --from-file ${FILENAME} --namespace=${NAMESPACE}
```

If you are using k3s version 1.22, it will ship with traefik v2, which requires a different method for handling basic authentication. In addition to the secret mentioned above, you'll also need to create a Middleware to handle basic auth:
```
echo "apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: ingress-basic-auth
  namespace: homebridge
spec:
  basicAuth:
    secret: ingress-basic-auth" | kc apply -f-
```

If you want to set up dynamic DNS and you use cloudflare, see the cloudflare ddns setup instructions [here](../cloudflare-ddns/README.md)

## The helm way

[Helm](https://helm.sh) has some neat templating options that let you customize a deployment without having to edit the podspecs directly. First, edit `homebridge/values.yaml` to your liking. In particular, be sure to set these values:
```
feature:
  bluetooth: true
  ingress: true
  externalIngress: false
```
If you don't know what any of the above options mean, you probably don't need them. Set those values to `false`.

Once you're happy with `values.yaml`, install homebridge with:
```
NAME=homebridge
NAMESPACE=homebridge
kubectl create ns ${NAMESPACE}
helm install -n ${NAMESPACE} -f homebridge/values.yaml ${NAME} ./homebridge
```

## The old fashioned kubectl way

Instead of using helm and editing `values.yaml`, open `homebridge.yml` and edit the podspec directly.

If you wish to run without Bluetooth and you didn't install via helm, make the following modifications to homebridge.yaml:
  * Remove the entire `startup` element/object from the `volumeMounts` and `volumes` arrays
  * Remove the entire `bluetooth` element/object from the `volumeMounts` and `volumes` arrays
  * (Optional) Remove the entire homebridge ConfigMap yaml document as it is unnecessary, although has no material impact

Once you are finished making your modifications (if any) apply the homebridge yaml file:
```
kubectl apply -f homebridge.yml
```

## Checking the status of homebridge

You should be able to open the following URL:
```
open http://${IP_ADDRESS}:8581
```
And log in with the default username and password (admin/admin). Be sure to change this after you log in!

Any installed plugins and settings should be persisted to the /homebridge directory stored on the homebridge PVC.

## References
* [Docker Homebridge](https://github.com/oznu/docker-homebridge)
* [Using Bluetooth in a Docker container](https://stackoverflow.com/a/64126744)
* [Switchbot homebridge plugin](https://github.com/OpenWonderLabs/homebridge-switchbot)
* [Ingress Basic Auth](https://stackoverflow.com/questions/50130797/kubernetes-basic-authentication-with-traefik)
* [Cloudflare DDNS](https://github.com/oznu/docker-cloudflare-ddns)

# Adding homebridge webhooks

If you want to control virtual homekit devices using http webhooks, look no further than the [homebridge http- ebhooks npm module](https://www.npmjs.com/package/homebridge-http-webhooks). To use the webhook, you'll need to create an ingress that references a service and port that the plugin runs on inside the homebridge container.

## The service

Create or edit the existing homebridge service and add the http-webhook port.
```
apiVersion: v1
kind: Service
metadata:
  name: homebridge
  namespace: homebridge
spec:
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: 8581
    - name: http-webhook
      port: 8080
      protocol: TCP
      targetPort: 51828
  selector:
    app: homebridge
```

## The ingress

If you are using ingress

```
DNS_ZONE=<example.com>

echo "apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: homebridge
  namespace: homebridge
  annotations:
    kubernetes.io/ingress.class: traefik
    cert-manager.io/cluster-issuer: letsencrypt-prod
    # Needed for basic auth with traefik v2+ only:
    traefik.ingress.kubernetes.io/router.middlewares: homebridge-ingress-basic-auth@kubernetescrd
spec:
  tls:
  - secretName: homebridge
    hosts:
    - hb.${DNS_ZONE}
  rules:
  - host: hb.${DNS_ZONE}
    http:
      paths:
      - path: /webhook
        pathType: Prefix
        backend:
          service:
            name: homebridge
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: homebridge
            port:
              number: 80" | kubectl apply -f -
```
## Caveats

Warning: be aware that LetsEncrypt rate limits the number of certificates you can request. Read up on rate limiting [here](https://letsencrypt.org/docs/rate-limits)

## References
* https://sysadmins.co.za/https-using-letsencrypt-and-traefik-with-k3s/
* https://www.npmjs.com/package/homebridge-http-webhooks
* https://faun.pub/securing-access-to-traefik-v2-dashboard-on-kubernetes-using-basic-authentication-b9535063f6e8
* https://stackoverflow.com/questions/71398933/how-to-strip-the-path-prefix-in-kubernetes-traefik-ingress
* https://stackoverflow.com/a/69915469
