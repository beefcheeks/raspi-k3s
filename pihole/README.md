# Pi-hole

## Overview

[Pi-hole](https://github.com/pi-hole/pi-hole) can act as a DNS server, DHCP server, ad blocker/sinkhole. It's quite handy, especially if you want to allow for valid local https webhooks for things like iOS shortcuts. If possible, I would highly recommend giving your Pi a static IP from your router prior to following the instructions below.

## Raspian Preparation

Installing pi-hole on Raspian is substantially easier than on Ubuntu. First, you'll need to add some lines to your Pi's DHCP config.
```
sudo nano /etc/dhcpd.conf
```
```
# Append the following to the end of the file
interface eth0
static ip_address=<YOUR_PI_PRIVATE_IP_ADDRESS_HERE>/24
static routers=<YOUR_ROUTER_IP_HERE>
```
Save and exit, and then restart the pi
```
sudo reboot
```
## Ubuntu Preparation

Installing pi-hole on Ubuntu can be tricky, especially if you're already using ingress for things like homebridge webhooks. The other gotcha is that pi-hole requires port 53 to be open on the host machine, and by default, Ubuntu runs a local DNS server on that very same port.

### Disabling default DNS listener (Ubuntu only)

To allow pihole to run on port 53, disable the system DNS server running on port 53. First, edit `/etc/systemd/resolved.conf`. I use Cloudflare DNS (`1.1.1.1`).
```
[Resolve]
DNS=1.1.1.1
DNSStubListener=no
#FallbackDNS=
#Domains=
#LLMNR=no
#MulticastDNS=no
#DNSSEC=no
#DNSOverTLS=no
#Cache=no
#DNSStubListener=yes
#ReadEtcHosts=yes
```

Symlink the DNS config
```
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
```

To ensure the `ubuntu` hostname continues to resolve locally, edit `/etc/hosts` and append `ubuntu` to the `127.0.0.1` entry at the top.
```
127.0.0.1 localhost ubuntu
```

Restart/reload systemd-resolved
```
sudo systemctl reload-or-restart systemd-resolved
```

### Setting a static IP (Ubuntu Only)

Most routers allow specifying a static IP for a given connected device. If you haven't done so already, ensure you Raspberry Pi has a statically assigned IP on your router to ensure it does not need to use DHCP to assign an IP address dynamically. Once your static IP is ready to go, it may be a good idea to disconnect your pi's ethernet cable and plug it back in to force the assigning of the static IP you chose.

If you plan on specifying pi-hole as the default DNS server for DHCP devices using your router, you'll definitely need to ensure that the system hosting pi-hole doesn't attempt to use DHCP to get its IP address. To specify a static IP in Ubuntu 20.04, edit `/etc/netplan/01-netcfg.yaml`

Mine looks something like this:
```
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses: [<static ip>/24]
      gateway4: <router ip>
      nameservers:
        addresses: [<external dns server ip>]
```

where anything between `<` and `>` (inclusive) is replaced with the appropriate value. the `/24` at the end of the addresses entry represents the netmask. By default, most routers use `/24` (a.k.a `255.255.255.0`), but setups may vary depending on your router configuration. I'm assuming ethernet is the interface, but if not, you'll need to use an alternative configuration where `eth0` is replaced with the appropriate interface id.

To test if these changes are valid, run:
```
sudo netplan try
```

If the configuration is accepted (e.g. doesn't complain), then you can apply the configuration with:
```
sudo netplan apply
```

## Configuring Pi-hole

If you're using ingress and certificates for pihole, you'll need to configure the VIRTUAL_HOST in the pihole deployment as well as in the ingress.
```
NAMESPACE=pihole
PIHOLE_DNS_='1.1.1.1;1.0.0.1'
TEMPERATUREUNIT=f
TZ=America/Los_Angeles
VIRTUAL_HOST=my.domain.com
WEBPASSWORD=change-me

kubectl create configmap -n ${NAMESPACE} pihole \
  --from-literal=pihole_dns_=${PIHOLE_DNS_} \
  --from-literal=temperatureunit=${TEMPERATUREUNIT} \
  --from-literal=tz=${TZ} \
  --from-literal=virtual_host=${VIRTUAL_HOST}
kubectl create secret generic -n ${NAMESPACE} pihole-webpassword --from-literal=webpassword=${WEBPASSWORD}
```
## Configuring DHCP (optional):

If you want pihole to handle DHCP requests, create the following configmap:
```
NAMESPACE=pihole
DHCP_ACTIVE="true"
DHCP_ROUTER=10.0.0.1
DHCP_START=10.0.0.2
DHCP_END=10.0.0.254
# Must be set to "false" if using more than one pihole instance (e.g. high availability)
DHCP_RAPID_COMMIT="true"

kubectl create configmap -n ${NAMESPACE} dhcp \
  --from-literal=dhcp_active=${DHCP_ACTIVE} \
  --from-literal=dhcp_router=${DHCP_ROUTER} \
  --from-literal=dhcp_start=${DHCP_START} \
  --from-literal=dhcp_end=${DHCP_END} \
  --from-literal=dhcp_rapid_commit=${DHCP_RAPID_COMMIT}
```

To prevent returning the incorrect DHCP server IP, or to set static IP addresses ahead of time, or deny addresses to specific devices, modify the below variables as needed and run:
```
NAMESPACE=pihole
DNS_IP=10.0.0.10 # why this is needed: https://github.com/pi-hole/docker-pi-hole/issues/429
STATIC_ENTRIES="dhcp-host=00:ab:ad:c0:ff:ee,10.0.0.123,My_Hostname
dhcp-host=11:ab:ad:c0:ff:ee,10.0.0.234,My_Hostname2"
NO_IP="dhcp-host,22:ab:ad:c0:ff:ee,ignore
dhcp-host=33:ab:ad:c0:ff:ee,ignore"

kubectl create configmap -n ${NAMESPACE} dhcp-files \
  --from-literal=dns_config="dhcp-option=6,${DNS_IP}" \
  --from-literal=static_entries=${STATIC_ENTRIES} \
  --from-literal=no_ip=${NO_IP}
```

## Installing Pi-hole
Just run:
```
kubectl apply -n ${NAMESPACE} -f pihole.yml
```
Check status with:
```
kubectl get po -n pihole
```

## Running a DHCP relay

To make dhcp udp multicast lookups work with a pihole container that is not host networked, a dhcp relay is needed.
```
NAMESPACE=pihole
EXTERNAL_NIC="eth0"
KUBERNETES_NIC="cni0"
PIHOLE_DHCP_SERVICE_IP=$(kubectl get svc -n $NAMESPACE dhcp --no-headers | awk '{print $3}')

kubectl create configmap -n ${NAMESPACE} dhcp-relay \
  --from-literal=external_nic=${EXTERNAL_NIC} \
  --from-literal=kubernetes_nic=${KUBERNETES_NIC} \
  --from-literal=pihole_udp_service_ip=${PIHOLE_DHCP_SERVICE_IP}

kubectl apply -n $NAMESPACE -f dhcp-relay.yml
```

## Configuring a default DHCP server

At this point, if you only want select devices on your network to use pi-hole, you can configure them individually. However, if you wish for all devices on your network to use pi-hole for DNS by default, then you'll need to set the default DHCP server to be the static IP of your Raspberry Pi. Instructions will vary, and certain routers may not allow setting this, but googling the instructions for your router will likely tell you whether its possible and how to do it.

## References
* https://www.linuxuprising.com/2020/07/ubuntu-how-to-free-up-port-53-used-by.html
* https://linuxhandbook.com/sudo-unable-resolve-host/
* https://github.com/colin-mccarthy/k3s-pi-hole
* https://www.linux.com/topic/distributions/how-use-netplan-network-configuration-tool-linux/
* https://peppe8o.com/assign-static-ip-and-manage-networking-in-raspberry-pi-os-lite/
