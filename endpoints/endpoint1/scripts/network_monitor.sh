#!/bin/bash
###############################################################################
# NETWORK MONITOR - Genera logs JSON de conexiones de red para ELK
# Detecta: conexiones salientes, puertos sospechosos, C2 communication
###############################################################################

LOG_FILE="/var/log/network_audit.log"
HOSTNAME=$(hostname)

# Puertos C2 conocidos
C2_PORTS="4444 4443 8443 1337 31337 6666 6667 9999 12345"
# IPs sospechosas (attacker)
SUSPICIOUS_IPS="10.10.10.200"

log_network_event() {
    local proto=$1
    local local_addr=$2
    local local_port=$3
    local remote_addr=$4
    local remote_port=$5
    local state=$6
    local pid=$7
    local process=$8
    local risk="normal"
    local threat_type=""
    
    # Clasificar riesgo
    if echo "$C2_PORTS" | grep -qw "$remote_port"; then
        risk="CRITICAL"
        threat_type="possible_c2_communication"
    elif echo "$SUSPICIOUS_IPS" | grep -qw "$remote_addr"; then
        risk="HIGH"
        threat_type="connection_to_attacker"
    elif [[ "$remote_port" == "22" ]] && [[ "$state" == "ESTABLISHED" ]]; then
        risk="MEDIUM"
        threat_type="ssh_lateral_movement"
    fi
    
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"hostname\":\"${HOSTNAME}\",\"event_type\":\"network_connection\",\"network\":{\"protocol\":\"${proto}\",\"local_address\":\"${local_addr}\",\"local_port\":${local_port},\"remote_address\":\"${remote_addr}\",\"remote_port\":${remote_port},\"state\":\"${state}\"},\"process\":{\"pid\":${pid:-0},\"name\":\"${process}\"},\"risk_level\":\"${risk}\",\"threat_type\":\"${threat_type}\",\"endpoint\":\"${ENDPOINT_NAME}\"}" >> "$LOG_FILE"
}

echo "[network_monitor] Starting network monitoring on ${HOSTNAME}..."

declare -A known_connections

while true; do
    # Monitorear conexiones TCP establecidas
    while IFS= read -r line; do
        # Parsear output de ss
        proto=$(echo "$line" | awk '{print $1}')
        local_full=$(echo "$line" | awk '{print $4}')
        remote_full=$(echo "$line" | awk '{print $5}')
        state=$(echo "$line" | awk '{print $2}')
        process_info=$(echo "$line" | awk '{print $6}')
        
        local_addr=$(echo "$local_full" | rev | cut -d: -f2- | rev)
        local_port=$(echo "$local_full" | rev | cut -d: -f1 | rev)
        remote_addr=$(echo "$remote_full" | rev | cut -d: -f2- | rev)
        remote_port=$(echo "$remote_full" | rev | cut -d: -f1 | rev)
        
        # Extraer PID y proceso
        pid=$(echo "$process_info" | grep -oP 'pid=\K[0-9]+' | head -1)
        process_name=$(echo "$process_info" | grep -oP '"\K[^"]+' | head -1)
        
        conn_key="${local_addr}:${local_port}-${remote_addr}:${remote_port}"
        
        if [[ -z "${known_connections[$conn_key]}" ]]; then
            known_connections[$conn_key]=1
            
            # Solo loggear conexiones relevantes (no localhost)
            if [[ "$remote_addr" != "127.0.0.1" ]] && [[ "$remote_addr" != "::1" ]] && [[ -n "$remote_addr" ]] && [[ "$remote_addr" != "*" ]]; then
                log_network_event "$proto" "$local_addr" "${local_port:-0}" "$remote_addr" "${remote_port:-0}" "$state" "${pid:-0}" "${process_name:-unknown}"
            fi
        fi
    done < <(ss -tnp 2>/dev/null | tail -n +2)
    
    # Limpiar conexiones cerradas cada 30 segundos
    if (( SECONDS % 30 == 0 )); then
        declare -A new_connections
        while IFS= read -r line; do
            local_full=$(echo "$line" | awk '{print $4}')
            remote_full=$(echo "$line" | awk '{print $5}')
            local_addr=$(echo "$local_full" | rev | cut -d: -f2- | rev)
            local_port=$(echo "$local_full" | rev | cut -d: -f1 | rev)
            remote_addr=$(echo "$remote_full" | rev | cut -d: -f2- | rev)
            remote_port=$(echo "$remote_full" | rev | cut -d: -f1 | rev)
            conn_key="${local_addr}:${local_port}-${remote_addr}:${remote_port}"
            new_connections[$conn_key]=1
        done < <(ss -tnp 2>/dev/null | tail -n +2)
        known_connections=()
        for key in "${!new_connections[@]}"; do
            known_connections[$key]=1
        done
    fi
    
    sleep 3
done
