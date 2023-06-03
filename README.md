# Overview

Goal of this project is to act as a storage repository for various Raspberry Pi projects. At the moment, I'm running a [k3s](https://k3s.io) [kubernetes cluster](https://kubernetes.io) on Raspian Buster Lite 64-bit on a single Raspberry Pi 4.

# Getting started

I would highly recommend starting by following the [Raspian + k3s Installation Guide](raspian/README.md). If you prefer to use Ubuntu, follow [Ubuntu + k3s Installation Guide](ubuntu/README.md).

## Table of Contents

OS Installation & Configuration
* [Raspian](raspian/README.md)
* [Ubuntu](ubuntu/README.md)

Kubernetes expanded capabilities (often prequisites for specific applications)
* [Auto-renewing Lets Encrypt SSL certificates (cert-manager)](cert-manager/README.md)
* [Dynamic DNS updater with Cloudflare](cloudflare-ddns/README.md)
* [multus CNI plugin for attaching custom host interfaces to pods](multus/README.md)
* [Kubernetes gateways for auto-renewable TLS endpoints - EXPERIMENTAL!](gateway/README.md)

Kubernetes applications
* [homebridge](homebridge/README.md)
* [DNS filtering & adblock with pi-hole](pihole/README.md)
* [Asus Router Management via SSH](asus-router/README.md)
* [Logging with LogDNA agent & syslog forwarder](logdna/README.md)
* [Zigbee Device Management with deCONZ](deconz/README.md)
* [Dynamic edge lighting with hyperion](hyperion/README.md)
