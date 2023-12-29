#!/bin/sh
# Ensure password file is created
touch /mosquitto/passwd/passwd
# Create all specified users from secret keys/values
for USER_PASS in $(env | grep -E '^mquser_')
do
    USER=$(echo $USER_PASS | cut -d '_' -f2- | cut -d '=' -f1)
    PASS=$(echo $USER_PASS | cut -d '_' -f2- | cut -d '=' -f2)
    /usr/bin/mosquitto_passwd -b /mosquitto/passwd/passwd ${USER} ${PASS}
done
# Start broker with config
/usr/sbin/mosquitto -c /mosquitto/config/mosquitto.conf
