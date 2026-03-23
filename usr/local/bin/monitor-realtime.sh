#!/bin/bash

CONFIG_FILE="/etc/monitor.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: /etc/monitor.conf"
    exit 1
fi

source $CONFIG_FILE

HOST=${HOSTNAME:-$(hostname)}

while true
do
    CPU_JSON=$(mpstat -P ALL 1 1 | awk '
    /^[0-9]/ {
        cpu=$1
        idle=$NF
        usage=100-idle
        printf "\"core_%s\": %.2f,", cpu, usage
    }')

    MEM=$(free | awk '/Mem:/ {print ($3/$2) * 100.0}')
    DISK=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1)

    JSON="{\"host\":\"$HOST\", $CPU_JSON \"memory\":$MEM, \"disk\":$DISK, \"load\":$LOAD}"

    curl -s -X POST "$API_URL" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON" > /dev/null

    sleep $INTERVAL
done
