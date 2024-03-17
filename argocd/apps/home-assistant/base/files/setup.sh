#!/bin/sh

# Create initial Setup
if [[ ! -f /config/configuration.yaml ]]
then
    cp /opt/config/configuration.yaml /config/configuration.yaml
fi
if [[ ! -f /config/automations.yaml ]]
then
    echo '[]' > /config/automations.yaml
fi
touch /config/scripts.yaml
touch /config/scenes.yaml
touch /config/template.yaml

# Install Home Assistant Community Store (HACS) custom component
if [[ ! -d /config/custom_components/hacs ]]
then
    wget -O - https://get.hacs.xyz | bash -
fi

# Hack to ensure programamble switches work with homekit
# Only needed if exposing triggers as homekit programmable switches
cat /usr/src/homeassistant/homeassistant/components/homekit/type_triggers.py | sed "s/subtype.replace/str(subtype).replace/" >  /homekit-triggers-workaround/type_triggers.py

# If blueprints exist, symlink blueprints directory in /config to mounted location
if [[ -d /opt/blueprints ]]
then
    if [[ ! -d /config/blueprints/automation ]]
    then
        mkdir -p /config/blueprints/automation
    fi
    if [[ ! -L /config/blueprints/automation/custom ]]
    then
        ln -s /opt/blueprints /config/blueprints/automation/custom
    fi
fi
