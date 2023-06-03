# Asus Router Manager

## Overview

Asus Router Manager is a container that uses ssh to manage custom clients and static IP assignments. Since using the point and click interface is tedious when adding dozens of entries, this script uses ssh to access your router and runs nvram commands based on the CSV of static clients that is provided.

For many networked IoT devices, using static IP addresses improves network stability and reliability. Static IP addresses should not be necessary, but unfortunately, your mileage may vary depending on the IoT devices you have on your network.

## Setup

1. Create a namespace for Asus Router Manager.
```
NAMESPACE=my-namespace
kubectl create ns $NAMESPACE
```

2. Create a ConfigMap of static clients (comma separated) in the form of `mac_address,ip_address,hostname`

cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: static-clients
data:
  static-clients: |
    AB:CD:EF:01:23:45,1.2.3.4,My_Hostname
    CD:EF:AB:23:45:01,1.2.3.5,My_Other_Hostname
EOF
```

3. Generate the ssh key needed access your router from the container
```
ssh-keygen -t ed25519 -C "asus-router-manager" -f id_rsa
```

4. Copy your new ssh public key to your clipboard
```
pbcopy < id_rsa.pub
```

5. Log in to your Asus router and go to Administration -> System. Enable ssh if you haven't already and paste your public ssh key on a separate line in the Authorized Keys field. Also set and make note of the port that ssh is running on.


6. Create a Kubernetes Secret containing your key
```
kubectl create secret generic ssh-key \
  -n $NAMESPACE \
  --from-file=id_rsa=./id_rsa
```

7. Remove the generated keys from your local workstation now that they are configured in Kubernetes and your Asus router.
```
rm id_rsa id_rsa.pub
```

8. Create the ConfigMap with the appropriate values
```
ROUTER_IP='10.0.0.1'
ROUTER_SSH_PORT='2222'
ROUTER_USER=admin

cat <<EOF | kubectl create -n $NAMESPACE -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssh-config
data:
  router-ip: "$ROUTER_IP"
  router-ssh-port: "$ROUTER_SSH_PORT"
  router-user: "$ROUTER_USER"
EOF
```

1. Apply the Kubernetes manifest:
```
kubectl apply -n $NAMESPACE -f asus-router.yaml
```

## Caveats

### Multus

This application is configured as a StatefulSet since I use [multus](../multus/README.md) to configure containers with a static IP and mac address directly on my host network. Also, there is no need for high availability with a Deployment for this application since it's essentially a glorified CronJob that runs whenever the ConfigMap static-clients value changes.

However, since most folks are probably not using multus, I've left the default as `hostNetwork: true`, so if you are _not_ using multus, it should work out of the box.

If you are using multus, you'll need to additionally run something like:
```
MAC=ab:cd:ef:01:23:45
NET_ATTACH_NAME=macvlan-conf

kubectl patch sts asus-router-manager -n $NAMESPACE -p '
  {
    "spec": {
        "template": {
            "metadata": {
                "annotations": {
                    "k8s.v1.cni.cncf.io/networks":"[{\"name\":\"'${NET_ATTACH_NAME}'\",\"namespace\":\"default\",\"mac\":\"'${MAC}'\"}]"
                }
            },
            "spec": {
              "hostNetwork": false
            }
        }
    }
}'
```

## References

* [SNB Forums - Add Static Lease via CLI](https://www.snbforums.com/threads/add-dhcp-static-leases-from-cli.55502/)