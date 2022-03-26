## Cert Manager

If you ever need SSL URLs for any reason (looking at you iOS https shortcuts), cert-manager offers a kubernetes friendly way of obtaining free LetsEncrypt certificates. I use cert-manager to automatically renew SSL certificates that back my https kubernetes ingress endpoints.

## Prerequisites

You'll need edit access to the hosting domain in which you are attempting to register addresses (e.g. mydomain.com). I use Cloudflare for hosting my domain, but I've also included instructions for AWS Route53 as well.

## Installation

Given cert-manager supports arm64 out of the box, there aren't any special instructions to follow besides what is documented on [their website](https://cert-manager.io/v1.7-docs/installation/).

Install cert-manager using the following command
```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.2/cert-manager.yaml
```
Verify that all 3 cert-manager pods are running the cert-manager namespace:
```
kubectl get pod -n cert-manager
```

### Cloudflare

While I was using AWS Route53 previously, I'm not using Cloudflare as my DNS provider. I followed the steps below to get cert-manager working with Cloudflare.

First, provision a Cloudflare API token with read/write capability:
```
API_TOKEN=<my-api-token>
kubectl create secret generic -n cert-manager cloudflare-api-token-secret --from-literal=api-token=${API_TOKEN}

CLOUDFLARE_EMAIL=<cloudflare-email>
echo "apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        cloudflare:
          email: ${CLOUDFLARE_EMAIL}
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token" | kubectl apply -f -
```

For more information about cert-manager Cloudflare configuration, see [here](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)

That's it! Now you're ready to request certificates for your ingresses!

### AWS

Previously, I was using AWS Route53 as my hosting provider, but found Cloudflare was substantially cheaper. When I was using Route53, I followed [this guide](https://cert-manager.io/v0.14-docs/configuration/acme/dns01/route53/). Detailed steps below:

Create a new IAM access policy. Direct link [here](https://console.aws.amazon.com/iam/home?#/policies$new?step=edit)
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}
```

Create a user and attach the named policy to it. Be sure to allow programmatic access and copy the access and secret keys when you're done. Direct link [here](https://console.aws.amazon.com/iam/home?#/users$new?step=details)

Create a secret in the cert-manager namespace that allows access to your zone sudomain in route 53:
```
SECRET_ACCESS_KEY='<IAM user secret key>'
kubectl create secret generic -n cert-manager route53 --from-literal=secret-access-key=${SECRET_ACCESS_KEY}
```

Then, create a cluster issuer referencing that secret for the domain you wish to issue SSL certs for.
```
DNS_ZONE=<mydomain.org>
ACCESS_KEY_ID=<my access key id>

echo "apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - selector:
        dnsZones:
          - ${DNS_ZONE}
      dns01:
        route53:
          region: us-west-2
          accessKeyID: ${ACCESS_KEY_ID}
          secretAccessKeySecretRef:
            name: route53
            key: secret-access-key" | kubectl apply -f -
```

That's it! Now you're ready to request certificates for your ingresses!

## Caveats

Warning: be aware that LetsEncrypt rate limits the number of certificates you can request. Read up on rate limiting [here](https://letsencrypt.org/docs/rate-limits)

## References
* https://sysadmins.co.za/https-using-letsencrypt-and-traefik-with-k3s/
