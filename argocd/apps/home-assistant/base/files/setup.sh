#!/bin/sh

CONFIG_FILE_DEST=/config/configuration.yaml
BLUEPRINTS_DIR=/config/blueprints/automation/custom

# Create initial Setup
if [[ ! -f $CONFIG_FILE_DEST ]]
then
    cp /opt/config/configuration.yaml $CONFIG_FILE_DEST
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

# Ensure blueprints directory is created
if [[ ! -d $BLUEPRINTS_DIR ]]
then
    mkdir -p $BLUEPRINTS_DIR
fi
