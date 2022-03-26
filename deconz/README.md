# Deconz

[Deconz](https://github.com/deconz-community/deconz-docker) is software used to control [ZigBee](https://en.wikipedia.org/wiki/Zigbee) networks. Since ZigBee requires specific hardware, I use the [ConBee II USB gateway](https://phoscon.de/en/conbee2), which works great across a variety of devices and platforms.

Once your USB stick is plugged in, configure your settings and apply the podspec with the following commands:
```
NAMESPACE=deconz
TZ=America/Los-Angeles
DECONZ_UPNP='0'
DECONZ_VNC_MODE='1'
DECONZ_VNC_PASSWORD=<vnc password>

kubectl create ns deconz
kubectl create configmap -n ${NAMESPACE} deconz \
  --from-literal=deconz_upnp=${DECONZ_UPNP} \
  --from-literal=deconz_vnc_mode=${DECONZ_VNC_MODE} \
  --from-literal=tz=${TZ}
kubectl create secret generic -n ${NAMESPACE} deconz-vnc --from-literal=deconz_vnc_password=${DECONZ_VNC_PASSWORD}

kubectl apply -n ${NAMSPACE} -f deconz.yml
```

## References
* https://github.com/deconz-community/deconz-docker
* https://en.wikipedia.org/wiki/Zigbee
* https://phoscon.de/en/conbee2
