# Overview

The purpose of this README is to provide a guide on how to install Ubuntu + k3s on a Raspberry Pi. However, please note that I have now deprecated this in favor of Raspian, since they have now released stable versions of their 64 bit OS. You can find that guide [here](??)

# Installation instructions

## Prepare the SD card
1. Download the [64-bit Ubuntu 20.04 ARM image for Raspberry Pi](https://ubuntu.com/download/raspberry-pi)
2. Flash the image using `dd` or [BalenaEtcher](https://www.balena.io/etcher/)
3. Safely eject the SD-card, insert it into your network connected Pi (recommend ethernet), and turn it on

## Configure your pi
1. Find your pi local IP address (would recommend using your router GUI)
```
# List all IP addresses on your network:
arp -a
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

## Install k3s
1. In your workstation shell, install k3sup
```
curl -sLS https://get.k3sup.dev | sudo sh
```
2. Install k3s on your pi
```
k3sup install --ip ${IP_ADDRESS} --user ubuntu --k3s-channel stable
```

## Configure your workstation
1. Install helm, kubernetes-cli, kubectx, and k9s (if not already installed)
```
brew install helm kubernetes-cli kubectx k9s
```
2. Save the rancher kubeconfig to your local workstation, but replace localhost with the pi private IP address, and the default name values with your own name (to prevent collisions):
```
PI_NAME=homepi4
ssh ubuntu@${IP_ADDRESS} "sudo cat /etc/rancher/k3s/k3s.yaml" | sed -e "s/127.0.0.1/${IP_ADDRESS}/; s/: default/: ${PI_NAME}/" > ~/.kube/k3s-config
```
3. Back up and replace your existing kubeconfig with the merged kubeconfig with the k3s cluster config
```
cp ~/.kube/config ~/.kube/config.bak && KUBECONFIG=~/.kube/config:~/.kube/k3s-config kubectl config view --flatten > /tmp/config && mv /tmp/config ~/.kube/config
```
4. Switch to your pi k3s context
```
kubectl config use-context ${PI_NAME}
```
5. Confirm you can see pods running with no errors:
```
kubectl get po --all-namespaces
```
6. (Optional) Delete the kubeconfig backup:
```
rm ~/.kube/k3s-config
```

## References

* [k3s on 64-bit Ubuntu for Raspberry Pi blog post](https://blog.alexellis.io/falco-at-the-edge-arm64/)