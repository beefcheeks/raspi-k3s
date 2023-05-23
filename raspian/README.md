# Overview

The purpose of this README is to provide a guide on how to install Raspian with k3s on a Raspberry Pi. I currently run Raspian Buster Lite 64-bit on a single Raspberry Pi 4.

# Installation instructions

## Preparing the OS

Install the balena etcher app to image the sdcard you intend to use for your Pi.
```
brew install --cask balenaetcher
```

1. Download the desired raspberry pi image [here](https://www.raspberrypi.com/software/operating-systems/). I use Raspian Lite 64 bit.

2. Plug in in your SD card and open the balena etcher application. Select the source (downloaded image file) and destination (sdcard) and then hit flash.

3. Unplug and re-plug your SD card and run the following command once you see a boot volume attached.
```
touch /Volumes/boot/ssh
```
This will enable ssh access to your Pi.

4. Unplug your SD card again and now plug it into your Pi. 

5. Power on your Pi and hop back on your workstation.

References:
* https://www.padok.fr/en/blog/raspberry-kubernetes

## Configuring the OS

1. Find your pi local IP address (would recommend using your router GUI if you aren't comfortable with `arp`)
```
# List all IP addresses on your network:
arp -a
```
2. ssh into your pi and change the default password
```
ssh pi@${IP_ADDRESS}
```
3. Change the default password
```
passwd
```
4. Configure ssh
```
# Configure your public ssh key
mkdir ~/.ssh
nano ~/.ssh/authorized_keys
# paste contents of your workstation's local ~/.ssh/id_rsa.pub then save and exit

# Set correct permissions
sudo chmod 700 ~/.ssh/
sudo chmod 600 ~/.ssh/authorized_keys
sudo chown -R pi:pi ~/.ssh/

# Optional, but recommended: disable password authentication on your Pi
sudo nano /etc/ssh/sshd_config
# Set PasswordAuthentication No then save and exit
```
5. Update your Pi wtih
```
sudo apt update && sudo apt upgrade
```
6. Append the following text to the end of the existing first line in `/boot/cmdline.txt`
```
cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
```
This allows for limits to be enforced for containers (important)

7. Reboot your pi for the changes to take effect:
```
sudo reboot
```

## Installing k3s

1. SSH into your Pi
```
ssh pi@${IP_ADDRESS}
```
2. Install Rancher's k3s Kubernetes distro:
```
# Install k3s
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
```

## Configure your workstation

1. Install helm, kubernetes-cli, kubectx, and k9s (if not already installed)
```
brew install helm kubernetes-cli kubectx k9s
```
2. Save the rancher kubeconfig to your local workstation, but replace localhost with the pi private IP address, and the default name values with your own name (to prevent collisions):
```
PI_NAME=homepi4
ssh pi@${IP_ADDRESS} "sudo cat /etc/rancher/k3s/k3s.yaml" | sed -e "s/127.0.0.1/${IP_ADDRESS}/; s/: default/: ${PI_NAME}/" > ~/.kube/k3s-config
```
3. Back up and replace your existing kubeconfig with the merged kubeconfig with the k3s cluster config
```
cp ~/.kube/config ~/.kube/config.bak && KUBECONFIG=~/.kube/config:~/.kube/k3s-config kubectl config view --flatten > /tmp/config && mv /tmp/config ~/.kube/config
```
4. Switch to your Pi k3s context
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

References:
* https://www.padok.fr/en/blog/raspberry-kubernetes