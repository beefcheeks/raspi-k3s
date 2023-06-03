# Multus CNI plugin

## Overview

[Multus](https://github.com/k8snetworkplumbingwg/multus-cni) is a CNI plugin that allows attaching multiple network interfaces to pods. Multus acts as management layer for other CNI plugins and is invoked by annotating pod workloads. One of the many use cases for multus is issuing separately addressable host network IPs to individual containers by attaching an additional network interface that is a subinterface of the primary host network interfaces. 

This offers some advantages:
* Improved isolation/security by running non-system workloads not in host network mode
* Enables listening on the same 'host' port across multiple pods on the same node

The primary use case this solves is multicast listening and broadcasting. Many multicast protocols, such as DLNA, mDNS/bonjour, or matter, do not allow broadcasting across subnets, which means containers intended to listen to the host network must run in host network mode. While it is usually feasible to run pods in host network mode, undesirable collisions can occur, such as port host-level port conflicts.

## Prerequisites

* Vanilla flannel CNI (non-k3s flavor)
* CNI plugin binaries (required for multus to be useful)
* DHCP daemon (relays IP requests from containers to the host network gateway)

## Install flannel

Flannel is a layer 3 network fabric that is manages the Kubernetes pod IPv4 network. It also comes with its own CNI plugin which multus will leverage to assign pods internal IP addresses within Kubernetes.

### Reinstall k3s without flannel
The flannel configuration that comes with k3s is not compatible with multus, as its configuration is not surfaced in the host filesystem (under `/etc/cni/net.d/`). Therefore, it necessary to reinstall k3s with flannel disabled and install the vanilla flannel DaemonSet.

Reinstall k3s with flannel disabled:
```
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--flannel-backend=none" sh -s - --write-kubeconfig-mode 644
```

### Retrieve Kubernetes CIDR blocks
Before installing flannel, you must retrieve the CIDR blocks (IP ranges) used by the Kubernetes network. With k3s, the only reliable way I was able to retrieve them was with:
```
K8S_CIDRS=$(kubectl get po -l job-name=helm-install-traefik -n kube-system -o jsonpath='{.items[].spec.containers[].env[?(@.name=="NO_PROXY")].value}' | cut -d ',' -f3-)
echo $K8S_CIDRS
```

If you see more than one CIDR block (e.g. 10.42.0.0/16,10.43.0.0/16), this means there are separate pod and cluster networks. You can find out which one is the pod CIDR with:
```
POD_CIDR=$(kubectl get nodes -o jsonpath='{.items[0].spec.podCIDR}')
echo $POD_CIDR
```
Whichever larger CIDR block contains that smaller node CIDR block is the pod network CIDR block.

For context, flannel only manages the pod networking, not service or cluster networking, so flannel should only be allocating IPs from the pod CIDR block. However, multus uses the network defined in the flannel configuration to configure routing within containers, so if the cluster/service CIDR block is excluded entirely from flannel's configuration, service lookups will fail to route to the cluster DNS service (bad). To solve this, specify a larger CIDR block that includes both ranges, but also set a minimum or maximum subnet range flannel is allowed to allocate to kubernetes nodes. For example:
```
# Escaped quotes required for patching
FLANNEL_CONFIG='
{
  \"Network\": \"10.42.0.0/15\",
  \"SubnetMax\": \"10.42.253.0\",
  \"Backend\": {
    \"Type\": \"vxlan\"
  }
}'
```

### Configure and install flannel
Then, use these to configure flannel during installation with:
```
# Install vanilla flannel
curl -sL https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml | kubectl apply -f -

# Update flannel config to use correct network info
kubectl patch configmap/kube-flannel-cfg \
  -n kube-flannel \
  --type json \
  -p "[{\"op\":\"replace\",\"path\":\"/data/net-conf.json\",\"value\":\"$FLANNEL_CONFIG\"}]"

# Restart flannel pod to ensure changes take effect
kubectl delete po -n kube-flannel -l app=flannel
```

### Install CNI plugin binaries and start dhcp daemon

CNI plugin binaries must be present on the host in order for multus to configure additional network interfaces. You can find more information on the plugin binaries releases [here](https://github.com/containernetworking/plugins/releases/download)

For convenience, this directory contains a DaemonSet manifest that downloads and installs the CNI plugin binaries to the host node as part an initContainer on startup. Once started, the dhcp daemon relays DHCP requests from multus network interfaces to your host network gateway (e.g. router). You can install this DaemonSet with:
```
# Retrieves the architecture of the first returned Kuberetes node
ARCH=$(kubectl get nodes -o jsonpath="{.items[0]['metadata.labels.kubernetes\.io/arch']}")

# Retrieves the latest version of the CNI plugins releases
VERSION=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/containernetworking/plugins/releases/latest | cut -d '/' -f8)

# Creates a configmap specifying architecture and version for cni plugins
kubectl create configmap -n kube-system cni-plugins  \
  --from-literal=arch=${ARCH} \
  --from-literal=version=${VERSION}

kubectl apply -f dhcp-daemon.yaml
```

### Install Multus

To reduce the resource footprint (but lose some metrics), install the multus thin plugin with:
```
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml
```

### Configure Multus

In order to actually use multus, you must create a NetworkAttachmentDefinition that acts as the configuration for a particular network interface. The below configuration creates a network interface using the macvlan CNI plugin in dhcp mode. This enables the interface to retrieve an IP address from the host network by way of the dhcp daemon that was deployed earlier.
```
NET_ATTACH_NAME=macvlan-conf

cat <<EOF | kubectl create -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "eth0",
      "capabilities": {"mac": true},
      "ipam": {
        "type": "dhcp"
      }
    }
EOF
```
The `mac` capability is specified so pods can opt to use a consistent mac address instead a randomly generated one. For workloads with only one replica, this reduces unnecessary dhcp leases in the event of a CrashLoopBackOff and allows static IP addressing that makes custom DNS easier. See additional configuration options for [macvlan](https://www.cni.dev/plugins/current/main/macvlan/) and [dhcp](https://www.cni.dev/plugins/current/ipam/dhcp/).


### Test if multus works

Run a test pod to ensure multus works:
```
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: samplepod
  annotations:
    k8s.v1.cni.cncf.io/networks: macvlan-conf
spec:
  containers:
  - name: samplepod
    command: ["/bin/ash", "-c", "trap : TERM INT; sleep infinity & wait"]
    image: alpine
EOF
```

If the pod starts, you should be able to see the additional network interface inside the pod:
```
kubectl exec samplepod -- ip a
```
There should be 3 interfaces:
1. lo (loopback)
2. eth0 (pod network)
3. net1 (new multus macvlan network interface)

### Assigning a static mac address

The easiest way to get a static mac address is to just use the ranomized one that was just generated for the new interface on the sample pod created in a previous step. You can retrieve the mac address with:
```
MAC=$(kubectl get po samplepod -o jsonpath="{['metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status']}" | jq -r '.[1].mac')
echo $MAC
```

Be sure to clean up the sample pod once you have the mac address
```
kubectl delete po samplepod
```

To use this network interface and mac address on one of your workloads, you'll need annotate it. Also, you'll likely want to disable hostNetwork mode if you're using multus since it would be redundant.
```
RESOURCE_TYPE=StatefulSet
NAME=name
NAMESPACE=namespace

# Adds the pod annotation within the parent workload controller (e.g. StatefulSet) and sets hostNetwork to false
kubectl patch $RESOURCE_TYPE/$NAME -n $NAMESPACE -p '
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

To check if the patch is successful, look for the network status annotation value:
```
kubectl get po samplepod -o jsonpath="{['metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status']}" | jq
```

If all went well, you should see two network interface definitions, one with your mac address (net1 interface)!

### Caveats

There appears to be a bug in multus v4.0.2 (latest at the time of writing). Whenever the multus pod restarts, it will create errant nested delegate configuration entries inside `/etc/cni/net.d/00-multus.conf` on the host nodes. This causes pods using custom network interfaces to fail to start due to two interfaces attempting to use the same name (`net1`). See [this GitHub issue](https://github.com/k8snetworkplumbingwg/multus-cni/issues/1089#issuecomment-1550442393) for additional details.

To fix this, I added another initContainer to the multus DaemonSet that deletes this configuration file on the host every time a multus pod starts, which forces it to be recreated correctly. If you use a different location for your CNI configurations, make sure to edit both the `args` and `mountPath` fields.
```
kubectl patch daemonset -n kube-system kube-multus-ds --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers/-",
    "value": {
      "name": "delete-multus-conf-workaround",
      "image": "alpine",
      "command": ["rm"],
      "args": ["/host/etc/cni/net.d/00-multus.conf"],
      "securityContext": {
        "privileged": true
      },
      "volumeMounts": [
        {
          "name": "cni",
          "mountPath": "/host/etc/cni/net.d"
        }
      ]
    }
  }
]'
```

## References:
* [Multus GitHub repo](https://github.com/k8snetworkplumbingwg/multus-cni)
* [Multus DHCP daemon reference Deployment](https://github.com/k8snetworkplumbingwg/reference-deployment/blob/master/multus-dhcp/dhcp-daemonset.yml)
* [CNI plugins documentation](https://www.cni.dev/plugins/current/)
* [Flannel configuration](https://github.com/flannel-io/flannel/blob/master/Documentation/configuration.md)
* [Multus autconfig issue](https://github.com/k8snetworkplumbingwg/multus-cni/issues/1089#issuecomment-1550442393)
* [Similar setup instructions found afterwards](https://www.reddit.com/r/homelab/comments/ilz3ct/howto_set_up_k8s_or_k3s_so_pods_get_ip_from_lan/)
