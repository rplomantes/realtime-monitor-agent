#!/bin/bash

CONFIG_FILE="/etc/monitor.conf"
LOG_FILE="/var/log/monitor-agent.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_message "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

source $CONFIG_FILE

# Validate required variables
if [ -z "$API_HOST" ] || [ -z "$API_PORT" ] || [ -z "$API_ENDPOINT" ] || [ -z "$API_TOKEN" ]; then
    log_message "ERROR: Missing required configuration variables"
    exit 1
fi

HOST=${HOSTNAME:-$(hostname)}
API_URL="http://${API_HOST}:${API_PORT}${API_ENDPOINT}"

log_message "Starting monitoring agent for host: $HOST"
log_message "API URL: $API_URL"

# Check if required commands exist
for cmd in mpstat free df uptime curl awk; do
    if ! command -v $cmd &> /dev/null; then
        log_message "ERROR: Required command '$cmd' not found"
        exit 1
    fi
done

while true
do
    # Get CPU usage per core
    CPU_JSON=$(mpstat -P ALL 1 1 | awk '
    /Average:/ && /[0-9]+/ && !/CPU/ {
        cpu=$2
        idle=$NF
        usage=100-idle
        printf "\"core_%s\":%.2f,", cpu, usage
    }')
    
    # Fallback if mpstat format is different
    if [ -z "$CPU_JSON" ]; then
        CPU_JSON=$(mpstat -P ALL 1 1 | awk '
        /^[0-9]/ {
            cpu=$2
            idle=$NF
            usage=100-idle
            printf "\"core_%s\":%.2f,", cpu, usage
        }')
    fi
    
    # Remove trailing comma
    CPU_JSON=${CPU_JSON%,}

    # Get Memory usage
    MEM=$(free | awk '/Mem:/ {printf "%.2f", ($3/$2) * 100.0}')
    
    # Get Disk usage
    DISK=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    # Get Load average (1 minute)
    LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{print $1}' | sed 's/,//')

    # Validate metrics
    if [ -z "$CPU_JSON" ] || [ -z "$MEM" ] || [ -z "$DISK" ] || [ -z "$LOAD" ]; then
        log_message "ERROR: Failed to gather metrics"
        sleep $INTERVAL
        continue
    fi

    # Build JSON payload
    JSON="{\"host\":\"$HOST\",${CPU_JSON},\"memory\":${MEM},\"disk\":${DISK},\"load\":${LOAD}}"

    # Send to API
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$JSON" \
        --connect-timeout 10 \
        --max-time 30)
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
    
    # Log results
    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        log_message "✓ Metrics sent successfully (HTTP $HTTP_CODE)"
    else
        log_message "✗ Failed to send metrics (HTTP $HTTP_CODE)"
        log_message "Response: $RESPONSE_BODY"
        log_message "JSON sent: $JSON"
    fi

    sleep $INTERVAL
done