#!/bin/sh
# Install htpasswd + yq
apk add apache2-utils yq

# Add username and encrypted password to config
cat /opt/config/AdGuardHome.yaml \
    | PASSWORD=$(htpasswd -B -n -b $ADGUARD_USER $ADGUARD_PASSWORD | cut -d ':' -f2) \
    yq e '.users += [{"name": env(ADGUARD_USER),"password": env(PASSWORD)}]' \
    > /opt/adguardhome/conf/AdGuardHome.yaml

# Generate static client list
while IFS= read -r line
do
    read mac ip name < <(echo $line | tr ',' ' ')
    name=$(echo $name | tr '_', ' ') ip=$ip mac=$mac yq -i e '.clients.persistent += [
        {
            "name":env(name),
            "ids":[env(ip), env(mac)],
            "use_global_settings": true,
            "use_global_blocked_services": true
            "blocked_services": {}
        }
        ]' \
        /opt/adguardhome/conf/AdGuardHome.yaml
done < /opt/static-clients/static-clients.csv
