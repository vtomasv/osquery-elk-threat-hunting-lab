#!/bin/bash
###############################################################################
# FILE MONITOR - Genera logs JSON de eventos de archivos para ELK
# Detecta: creación de archivos en /tmp, modificación de configs, payloads
###############################################################################

LOG_FILE="/var/log/attack_simulation.log"
HOSTNAME=$(hostname)

# Directorios a monitorear
WATCH_DIRS="/tmp /dev/shm /var/tmp /home /root/Downloads"

log_file_event() {
    local action=$1
    local filepath=$2
    local risk="normal"
    local threat_type=""
    
    # Clasificar riesgo basado en extensión y ubicación
    if echo "$filepath" | grep -qiE "\.(sh|py|pl|rb|elf|bin|exe)$"; then
        risk="HIGH"
        threat_type="executable_in_monitored_dir"
    elif echo "$filepath" | grep -qiE "authorized_keys|id_rsa|\.bashrc|crontab"; then
        risk="HIGH"
        threat_type="persistence_file_modified"
    elif echo "$filepath" | grep -qiE "/tmp/|/dev/shm/"; then
        risk="MEDIUM"
        threat_type="file_in_temp_directory"
    fi
    
    local size=$(stat -c%s "$filepath" 2>/dev/null || echo "0")
    local owner=$(stat -c%U "$filepath" 2>/dev/null || echo "unknown")
    local perms=$(stat -c%a "$filepath" 2>/dev/null || echo "000")
    local md5sum_val=$(md5sum "$filepath" 2>/dev/null | awk '{print $1}' || echo "unknown")
    
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"hostname\":\"${HOSTNAME}\",\"event_type\":\"file_${action}\",\"file\":{\"path\":\"${filepath}\",\"size\":${size},\"owner\":\"${owner}\",\"permissions\":\"${perms}\",\"md5\":\"${md5sum_val}\"},\"risk_level\":\"${risk}\",\"threat_type\":\"${threat_type}\",\"endpoint\":\"${ENDPOINT_NAME}\"}" >> "$LOG_FILE"
}

echo "[file_monitor] Starting file monitoring on ${HOSTNAME}..."
echo "[file_monitor] Watching: ${WATCH_DIRS}"

# Usar inotifywait si está disponible, sino polling
if command -v inotifywait &> /dev/null; then
    inotifywait -m -r -e create,modify,attrib,moved_to --format '%w%f %e' $WATCH_DIRS 2>/dev/null | while read filepath event; do
        action=$(echo "$event" | tr '[:upper:]' '[:lower:]' | tr ',' '_')
        log_file_event "$action" "$filepath"
    done
else
    # Fallback: polling con find
    declare -A known_files
    
    while true; do
        for dir in $WATCH_DIRS; do
            if [[ -d "$dir" ]]; then
                while IFS= read -r filepath; do
                    mtime=$(stat -c%Y "$filepath" 2>/dev/null)
                    key="${filepath}:${mtime}"
                    
                    if [[ -z "${known_files[$key]}" ]]; then
                        known_files[$key]=1
                        log_file_event "create_or_modify" "$filepath"
                    fi
                done < <(find "$dir" -type f -newer /tmp/.file_monitor_marker 2>/dev/null)
            fi
        done
        
        touch /tmp/.file_monitor_marker
        sleep 5
    done
fi
