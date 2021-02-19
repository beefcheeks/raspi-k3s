## Overview

Goal of this project is to act as a storage repository for various raspberry pi projects. At the moment, I'm running k3s on Ubuntu 20.04.2 on a single Raspberry Pi 4.

## Setup

### Prepare the SD card
1. Download the [64-bit Ubuntu 20.04 ARM image for Raspberry Pi](https://ubuntu.com/download/raspberry-pi)
2. Flash the image using `dd` or [BalenaEtcher](https://www.balena.io/etcher/)
3. Safely eject the SD-card, insert it into your network connected Pi (recommend ethernet), and turn it on

### Configure your pi
1. Find your pi local IP address (or just use your router GUI)
```
# Grab your pi IP address
IP_ADDRESS=$(arp -a | awk '/ubuntu/ {print $2}' | tr -d '()')
```
2. ssh into your pi and change the default password
```
ssh ubuntu@${IP_ADDRESS}
```
3. Copy your ssh key to your pi
```
ssh-copy-id ubuntu@${IP_ADDRESS}
```
4. Append the following text to the end of the existing first line in `/boot/firmware/cmdline.txt`
```
cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
```
This allows for limits to be enforced for containers (important)

5. Install the following hotfix to ensure Bluetooth works (hotfix for pi 4)
```
sudo apt update
sudo apt install pi-bluetooth
```
6. Reboot your pi for the changes to take effect:
```
sudo reboot
```

### Install k3s
1. In your workstation shell, install k3sup
```
curl -sLS https://get.k3sup.dev | sudo sh
```
2. Install k3s on your pi
```
k3sup install --ip ${IP_ADDRESS} --user ubuntu --k3s-channel stable
```

### Configure your workstation
1. Install kubernetes-cli, kubectx, and k9s (if not already installed)
```
brew install kubernetes-cli kubectx k9s
```
2. Save the rancher kubeconfig to your local workstation, but replace localhost with the pi private IP address, and the default name values with your own name (to prevent collisions):
```
PI_NAME=homepi4
ssh ubuntu@10.0.0.20 "sudo cat /etc/rancher/k3s/k3s.yaml" | sed -e "s/127.0.0.1/${IP_ADDRESS}/; s/: default/: ${PI_NAME}/" > ~/.kube/k3s-config
```
3. Back up and replace your existing kubeconfig with the merged kubeconfig with the k3s cluster config
```
cp ~/.kube/config ~/.kube/config.bak && KUBECONFIG=~/.kube/config:~/.kube/k3s-config kubectl config view --flatten > /tmp/config && mv /tmp/config ~/.kube/config
```
4. Switch to your pi k3s context
```
kubectl config use-context ${PI_CONTEXT}
```
5. Confirm you can see pods running with no errors:
```
kubectl get po --all-namespaces
```
6. (Optional) Delete the kubeconfig backup:
```
rm ~/.kube/k3s-config
```

## Homebridge

### Overview

Homebridge is a useful tool for converting existing smart devices into homekit compatible ones. You can learn more [here](https://homebridge.io). Running it in a container helps isolate it from other applications and their dependences running on your pi.

### No Bluetooth (probably most people)

Running homebridge inside of container is pretty easy, so long as you don't need Bluetooth access. Without Bluetooth, all you have to do is remove the entire `scripts` element/object from the `volumeMounts` array and apply it. If you want to get extra fancy, you can set the ID values in the env vars section to 1000 instead of 0 so you don't run homebridge as root. Then, simply apply the modified yaml file:
```
kubectl apply -f homebridge.yml
```

### Need Bluetooth (me)

If you have the unfortunate need for Bluetooth like me, don't make any of the aforementioned changes and perform the following steps instead:
1. Disable automatic Bluetooth daemon startup on your pi to prevent interference with the homebridge container
```
ssh ubuntu@${IP_ADDRESS}
sudo systemctl disable bluetooth.service
```
2. Exit the ssh session and apply the homebridge yaml file
```
kubectl apply -f homebridge.yml
```

### Checking on the status of homebridge

You should be able to open the following URL:
```
open http://${IP_ADDRESS}:8581
```
And log in with the default username and password (admin/admin). Be sure to change this after you log in!

Any installed plugins and settings should be persisted to the /homebridge directory stored on the homebridge PVC

## References

* [k3s on 64-bit Ubuntu for Raspberry Pi blog post](https://blog.alexellis.io/falco-at-the-edge-arm64/)
* [Docker Homebridge](https://github.com/oznu/docker-homebridge)
* [Using Bluetooth in a Docker container](https://stackoverflow.com/a/64126744)
* [Switchbot BLE homebridge plugin](https://github.com/OpenWonderLabs/homebridge-switchbot-ble)
