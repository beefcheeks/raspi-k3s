#!/bin/bash
echo "Starting script..."

# Custom client Format
# <Client Name>AB:CD:EF:01:23:45>0>0>>>>>
CUSTOM_CLIENTLIST=$(awk -F ',' '{gsub(/_/, " "); print "<"$3">"toupper($1)">0>0>>>>>"}' /opt/static-clients/static-clients.csv)

# Static Client Format
# <AB:CD:EF:01:23:45>1.2.3.4>>Client_Name
DHCP_STATICLIST=$(awk -F ',' '{print "<"toupper($1)">"$2">>"$3}' /opt/static-clients/static-clients.csv)

ssh $ROUTER_USER@$ROUTER_IP \
  -p $ROUTER_SSH_PORT \
  -i /opt/ssh/id_rsa \
  -o StrictHostKeyChecking=accept-new \
  "nvram set custom_clientlist=\"$CUSTOM_CLIENTLIST\""

ssh $ROUTER_USER@$ROUTER_IP \
  -p $ROUTER_SSH_PORT \
  -i /opt/ssh/id_rsa \
  -o StrictHostKeyChecking=accept-new \
  "nvram set dhcp_staticlist=\"$DHCP_STATICLIST\"""

echo "Script completed."
