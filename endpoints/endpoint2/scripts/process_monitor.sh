#!/bin/bash
###############################################################################
# PROCESS MONITOR - Genera logs JSON de procesos para ELK
# Detecta: nuevos procesos, procesos sospechosos, ejecuciones desde /tmp
###############################################################################

LOG_FILE="/var/log/process_audit.log"
HOSTNAME=$(hostname)

log_process_event() {
    local pid=$1
    local ppid=$2
    local name=$3
    local cmdline=$4
    local user=$5
    local path=$6
    local risk="normal"
    
    # Clasificar riesgo
    if echo "$cmdline" | grep -qiE "wget|curl.*http|nc -|ncat|socat|python.*socket|perl.*socket|bash -i|/dev/tcp"; then
        risk="HIGH"
    elif echo "$path" | grep -qiE "^/tmp/|^/dev/shm/|^/var/tmp/"; then
        risk="MEDIUM"
    elif echo "$cmdline" | grep -qiE "base64|eval|chmod \+x|ssh.*@"; then
        risk="MEDIUM"
    fi
    
    # Generar evento JSON
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"hostname\":\"${HOSTNAME}\",\"event_type\":\"process_start\",\"process\":{\"pid\":${pid},\"ppid\":${ppid},\"name\":\"${name}\",\"cmdline\":\"${cmdline}\",\"user\":\"${user}\",\"path\":\"${path}\"},\"risk_level\":\"${risk}\",\"endpoint\":\"${ENDPOINT_NAME}\"}" >> "$LOG_FILE"
}

echo "[process_monitor] Starting process monitoring on ${HOSTNAME}..."

# Monitoreo continuo usando /proc
declare -A known_pids

while true; do
    for pid_dir in /proc/[0-9]*/; do
        pid=$(basename "$pid_dir" 2>/dev/null)
        
        # Skip si ya conocemos este PID
        if [[ -n "${known_pids[$pid]}" ]]; then
            continue
        fi
        
        # Obtener información del proceso
        if [[ -f "/proc/$pid/status" ]] && [[ -f "/proc/$pid/cmdline" ]]; then
            name=$(grep "^Name:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}')
            ppid=$(grep "^PPid:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}')
            uid=$(grep "^Uid:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}')
            cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | sed 's/"/\\"/g')
            path=$(readlink -f "/proc/$pid/exe" 2>/dev/null)
            user=$(getent passwd "$uid" 2>/dev/null | cut -d: -f1)
            
            if [[ -n "$name" ]] && [[ "$name" != "process_monit" ]]; then
                known_pids[$pid]=1
                log_process_event "$pid" "$ppid" "$name" "$cmdline" "${user:-uid:$uid}" "${path:-unknown}"
            fi
        fi
    done
    
    # Limpiar PIDs que ya no existen
    for pid in "${!known_pids[@]}"; do
        if [[ ! -d "/proc/$pid" ]]; then
            unset "known_pids[$pid]"
        fi
    done
    
    sleep 2
done
