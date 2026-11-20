#!/usr/local/bin/bash
set -euo pipefail
LOG=/var/log/bh-health.log
TS=$(date "+%Y-%m-%dT%H:%M:%S%z")
LOAD=$(sysctl -n vm.loadavg | awk '{print $2}')
TOTP=$(sysctl -n vm.stats.vm.v_page_count)
FREEP=$(sysctl -n vm.stats.vm.v_free_count)
MEM=$(( (TOTP - FREEP) * 100 / TOTP ))
DISK=$(df -P / | tail -1 | awk '{print $5}' | tr -dc '0-9')
STATUS=OK
if [ "$DISK" -ge 80 ] || [ "$MEM" -ge 90 ]; then STATUS=WARN; fi
echo "$TS host=$(hostname) load=$LOAD mem=${MEM}% disk=${DISK}% status=$STATUS" >> "$LOG"
if [ "$STATUS" != OK ]; then logger -t bh-health "WARN on $(hostname): mem=${MEM}% disk=${DISK}%"; fi
