#!/bin/bash
###############################################################################
# KIBANA COMPLETE SETUP
# Configura: Data Views, Index Templates, Dashboards, Alertas, y genera datos
#
# Uso: ./setup_dashboards.sh [kibana_url] [elasticsearch_url]
###############################################################################

KIBANA_URL="${1:-http://localhost:5601}"
ES_URL="${2:-http://localhost:9200}"

echo "=============================================="
echo "  KIBANA COMPLETE SETUP - Threat Hunting Lab"
echo "  Kibana: ${KIBANA_URL}"
echo "  Elasticsearch: ${ES_URL}"
echo "=============================================="

# Esperar a que Kibana esté listo
echo "[*] Esperando a que Kibana esté disponible..."
for i in $(seq 1 60); do
    if curl -s "${KIBANA_URL}/api/status" 2>/dev/null | grep -q "available"; then
        echo "[+] Kibana disponible"
        break
    fi
    sleep 5
    echo -n "."
done
echo ""

# ============================================================================
# 1. CREAR INDEX TEMPLATES EN ELASTICSEARCH
# ============================================================================
echo "[1/5] Creando Index Templates en Elasticsearch..."

curl -s -X PUT "${ES_URL}/_index_template/threat-hunting" \
    -H "Content-Type: application/json" \
    -d '{
        "index_patterns": ["threat-hunting-*"],
        "template": {
            "settings": {"number_of_shards": 1, "number_of_replicas": 0},
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "event_type": {"type": "keyword"},
                    "technique": {"type": "keyword"},
                    "tactic": {"type": "keyword"},
                    "endpoint": {"type": "keyword"},
                    "endpoint_ip": {"type": "ip"},
                    "target_endpoint": {"type": "keyword"},
                    "target_ip": {"type": "ip"},
                    "source_ip": {"type": "ip"},
                    "user": {"type": "keyword"},
                    "target_user": {"type": "keyword"},
                    "risk_level": {"type": "keyword"},
                    "description": {"type": "text"},
                    "process.name": {"type": "keyword"},
                    "process.cmdline": {"type": "text", "fields": {"keyword": {"type": "keyword", "ignore_above": 512}}},
                    "process.pid": {"type": "integer"},
                    "process.ppid": {"type": "integer"},
                    "network.remote_ip": {"type": "ip"},
                    "network.remote_port": {"type": "integer"},
                    "network.local_port": {"type": "integer"},
                    "network.direction": {"type": "keyword"},
                    "network.bytes_sent": {"type": "long"},
                    "ioc.file_name": {"type": "keyword"},
                    "ioc.file_hash_md5": {"type": "keyword"},
                    "ioc.url": {"type": "keyword"}
                }
            }
        }
    }' > /dev/null 2>&1
echo "  [+] Template: threat-hunting-*"

curl -s -X PUT "${ES_URL}/_index_template/process-events" \
    -H "Content-Type: application/json" \
    -d '{
        "index_patterns": ["process-events-*"],
        "template": {
            "settings": {"number_of_shards": 1, "number_of_replicas": 0},
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "endpoint": {"type": "keyword"},
                    "endpoint_ip": {"type": "ip"},
                    "event_type": {"type": "keyword"},
                    "risk_level": {"type": "keyword"},
                    "process.name": {"type": "keyword"},
                    "process.cmdline": {"type": "text", "fields": {"keyword": {"type": "keyword", "ignore_above": 512}}},
                    "process.pid": {"type": "integer"},
                    "process.ppid": {"type": "integer"},
                    "process.user": {"type": "keyword"}
                }
            }
        }
    }' > /dev/null 2>&1
echo "  [+] Template: process-events-*"

curl -s -X PUT "${ES_URL}/_index_template/network-events" \
    -H "Content-Type: application/json" \
    -d '{
        "index_patterns": ["network-events-*"],
        "template": {
            "settings": {"number_of_shards": 1, "number_of_replicas": 0},
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "endpoint": {"type": "keyword"},
                    "endpoint_ip": {"type": "ip"},
                    "event_type": {"type": "keyword"},
                    "risk_level": {"type": "keyword"},
                    "network.local_ip": {"type": "ip"},
                    "network.local_port": {"type": "integer"},
                    "network.remote_ip": {"type": "ip"},
                    "network.remote_port": {"type": "integer"},
                    "network.protocol": {"type": "keyword"},
                    "network.state": {"type": "keyword"},
                    "network.bytes_sent": {"type": "long"},
                    "process.name": {"type": "keyword"},
                    "process.pid": {"type": "integer"}
                }
            }
        }
    }' > /dev/null 2>&1
echo "  [+] Template: network-events-*"

curl -s -X PUT "${ES_URL}/_index_template/osquery-results" \
    -H "Content-Type: application/json" \
    -d '{
        "index_patterns": ["osquery-results-*"],
        "template": {
            "settings": {"number_of_shards": 1, "number_of_replicas": 0},
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "endpoint": {"type": "keyword"},
                    "endpoint_ip": {"type": "ip"},
                    "event.module": {"type": "keyword"},
                    "osquery.name": {"type": "keyword"},
                    "osquery.hostIdentifier": {"type": "keyword"},
                    "osquery.action": {"type": "keyword"}
                }
            }
        }
    }' > /dev/null 2>&1
echo "  [+] Template: osquery-results-*"

curl -s -X PUT "${ES_URL}/_index_template/syslog-events" \
    -H "Content-Type: application/json" \
    -d '{
        "index_patterns": ["syslog-*"],
        "template": {
            "settings": {"number_of_shards": 1, "number_of_replicas": 0},
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "endpoint": {"type": "keyword"},
                    "endpoint_ip": {"type": "ip"},
                    "syslog_message": {"type": "text"},
                    "syslog_program": {"type": "keyword"},
                    "syslog_hostname": {"type": "keyword"},
                    "event_type": {"type": "keyword"}
                }
            }
        }
    }' > /dev/null 2>&1
echo "  [+] Template: syslog-*"

# ============================================================================
# 2. GENERAR DATOS DE ATAQUE
# ============================================================================
echo ""
echo "[2/5] Generando datos de ataque simulados..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_SCRIPT="${SCRIPT_DIR}/../../scripts/generate_attack_data.sh"

if [ -f "$GENERATE_SCRIPT" ]; then
    bash "$GENERATE_SCRIPT" "$ES_URL"
else
    echo "  [!] Script no encontrado en: $GENERATE_SCRIPT"
    echo "  [!] Buscando alternativa..."
    ALT_SCRIPT="$(find / -name generate_attack_data.sh 2>/dev/null | head -1)"
    if [ -n "$ALT_SCRIPT" ]; then
        bash "$ALT_SCRIPT" "$ES_URL"
    else
        echo "  [!] No se encontro el script. Ejecutar manualmente despues."
    fi
fi

# ============================================================================
# 3. CREAR DATA VIEWS EN KIBANA
# ============================================================================
echo ""
echo "[3/5] Creando Data Views en Kibana..."

create_data_view() {
    local name=$1
    local pattern=$2
    curl -s -X POST "${KIBANA_URL}/api/data_views/data_view" \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        -d '{
            "data_view": {
                "title": "'"${pattern}"'",
                "name": "'"${name}"'",
                "timeFieldName": "@timestamp"
            },
            "override": true
        }' > /dev/null 2>&1
    echo "  [+] ${name} -> ${pattern}"
}

create_data_view "Threat Hunting Events" "threat-hunting-*"
create_data_view "Process Events" "process-events-*"
create_data_view "Network Events" "network-events-*"
create_data_view "Osquery Results" "osquery-results-*"
create_data_view "Syslog" "syslog-*"
create_data_view "All Events" "*-*"

# Set default data view
curl -s -X POST "${KIBANA_URL}/api/kibana/settings" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{"changes":{"defaultIndex":"threat-hunting"}}' > /dev/null 2>&1

# ============================================================================
# 4. CREAR ALERTAS (Detection Rules)
# ============================================================================
echo ""
echo "[4/5] Creando reglas de deteccion..."

create_rule() {
    local name=$1
    local query=$2
    local severity=$3
    
    curl -s -X POST "${KIBANA_URL}/api/alerting/rule" \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "'"${name}"'",
            "rule_type_id": ".es-query",
            "consumer": "alerts",
            "schedule": {"interval": "1m"},
            "params": {
                "index": ["threat-hunting-*", "process-events-*", "network-events-*"],
                "timeField": "@timestamp",
                "esQuery": "{\"query\":{\"bool\":{\"must\":[{\"query_string\":{\"query\":\"'"${query}"'\"}}]}}}",
                "timeWindowSize": 5,
                "timeWindowUnit": "m",
                "threshold": [1],
                "thresholdComparator": ">="
            },
            "actions": [],
            "tags": ["threat-hunting", "'"${severity}"'"],
            "enabled": true
        }' > /dev/null 2>&1
    echo "  [+] ${name} [${severity}]"
}

create_rule "CRITICAL: Reverse Shell to C2" "event_type:execution AND network.remote_port:4444" "critical"
create_rule "CRITICAL: Lateral Movement SSH" "event_type:lateral_movement" "critical"
create_rule "CRITICAL: Data Exfiltration" "event_type:exfiltration" "critical"
create_rule "HIGH: Credential Dumping" "event_type:credential_access" "high"
create_rule "HIGH: Persistence Crontab" "event_type:persistence AND technique:T1053.003" "high"
create_rule "HIGH: Malicious Download" "event_type:initial_access" "high"
create_rule "MEDIUM: Network Scanning" "event_type:discovery AND technique:T1046" "medium"
create_rule "MEDIUM: Suspicious Process from /tmp" "process.cmdline:*tmp*" "medium"

# ============================================================================
# 5. IMPORTAR DASHBOARD
# ============================================================================
echo ""
echo "[5/5] Importando dashboard..."

cat > /tmp/dashboard_import.ndjson << 'NDJSON'
{"type":"dashboard","id":"threat-hunting-overview","attributes":{"title":"Threat Hunting - Attack Overview","description":"Dashboard principal: Vista general del ataque APT simulado con timeline, endpoints comprometidos y tecnicas MITRE ATT&CK","hits":0,"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"},"optionsJSON":"{\"useMargins\":true,\"syncColors\":false,\"syncCursor\":true,\"syncTooltips\":false,\"hidePanelTitles\":false}","panelsJSON":"[]","refreshInterval":{"pause":false,"value":5000},"timeFrom":"now-2h","timeRestore":true,"timeTo":"now","version":1},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","managed":false,"references":[],"typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
NDJSON

curl -s -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
    -H "kbn-xsrf: true" \
    --form file=@/tmp/dashboard_import.ndjson > /dev/null 2>&1
echo "  [+] Dashboard importado"

rm -f /tmp/dashboard_import.ndjson

# ============================================================================
# RESUMEN FINAL
# ============================================================================
echo ""
echo "=============================================="
echo "  SETUP COMPLETADO EXITOSAMENTE"
echo "=============================================="
echo ""
echo "  COMO VER LOS DATOS DE ATAQUE:"
echo ""
echo "  1. Abrir Kibana: ${KIBANA_URL}"
echo "  2. Ir a 'Discover' (menu lateral izquierdo)"
echo "  3. En el selector de Data View (arriba izquierda),"
echo "     seleccionar: 'Threat Hunting Events'"
echo "  4. Cambiar rango de tiempo a: 'Last 2 hours'"
echo "  5. Escribir en la barra KQL:"
echo "     risk_level : \"CRITICAL\""
echo ""
echo "  QUERIES DE HUNTING:"
echo "     event_type : \"lateral_movement\""
echo "     event_type : \"exfiltration\""
echo "     event_type : \"initial_access\""
echo "     technique : \"T1021.004\""
echo "     endpoint : \"WS-FINANZAS-01\""
echo ""
echo "  ALERTAS:"
echo "     Menu > Stack Management > Rules and Connectors"
echo ""
echo "=============================================="
