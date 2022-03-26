# Router log forwarding (syslog https proxy_

## Overview

I use LogDNA for analyzing my logs (disclosure: I work there) and take advantage of custom parsing to generate pretty graphs and track down devices abusing DHCP negotiation (I'm looking at you Wi-Fi rower). I wrote a containerized syslog forwarding module so I can send my logs over the internet via https instead of UDP. You can view the repo [here](https://github.com/logdna/logdna-rsyslog).

## Installation

I followed the same installation instructions except that I just make the services type `LoadBalancer` instead of `ClusterIP` so I can expose them to my local network.

```
INGESTION_KEY=<your LogDNA ingestion key here>

kubectl create ns logdna-agent

kubectl create secret generic -n logdna-agent logdna-agent-key --from-literal=logdna-agent-key=${INGESTION_KEY}

kubectl apply -n logdna-agent -f https://raw.githubusercontent.com/logdna/logdna-rsyslog/master/logdna-rsyslog-config-https.yml

curl -s https://raw.githubusercontent.com/logdna/logdna-rsyslog/master/logdna-rsyslog-workload.yml | sed 's/ClusterIP/LoadBalancer/g' | kubectl apply -n logdna-agent -f -
```

# References
* [rsyslog forwarder](https://github.com/logdna/logdna-rsyslog)
* [LogDNA](https://www.logdna.com)


# Log collection via LogDNA Kubernetes agent

## Overview

For the same reasons I forward my router logs via the rsyslog proxy, I also like to forward my Kubernetes container logs to LogDNA via the LogDNA agent.

## Installation

If you haven't already installed the rsyslog forwarder, follow the steps below. Otherwise, skip to the next step.
```
INGESTION_KEY=<your LogDNA ingestion key here>

kubectl create ns logdna-agent

kubectl create secret generic -n logdna logdna-agent-key --from-literal=logdna-agent-key=${INGESTION_KEY}
```

Once the `logdna-agent` namespace and secret are created, deploy the agent and its accompanying configuration.
```
curl -s https://raw.githubusercontent.com/logdna/logdna-agent-v2/2.2.4/k8s/agent-resources.yaml | sed 's#image:.*#image: beefcheeks/logdna-agent:2.2.4#' | kubectl apply -n logdna-agent -f -
```
Note: the LogDNA agent is not supported for ARM architectures. I've manually built an ARM64-compatible docker image using [docker buildx](https://github.com/docker/buildx), but due to the lack of ARMv7 support for the RedHat Universal Basic Image used as the base for the logdna-agent, it is not easily possible to build an ARMv7 one.

# References
* [LogDNA agent](https://github.com//logdna/logdna-agent-v2)
* [Docker buildx](https://github.com/docker/buildx)
* [Docker buildx multi-architecture how-to](https://medium.com/@artur.klauser/building-multi-architecture-docker-images-with-buildx-27d80f7e2408)
