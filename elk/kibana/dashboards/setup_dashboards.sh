#!/bin/bash
###############################################################################
# KIBANA DASHBOARD SETUP
# Configura index patterns, visualizaciones y dashboards para Threat Hunting
# 
# Ejecutar después de que Kibana esté completamente iniciado:
#   ./setup_dashboards.sh
###############################################################################

KIBANA_URL="http://localhost:5601"
ES_URL="http://localhost:9200"

echo "=============================================="
echo "  KIBANA DASHBOARD SETUP - Threat Hunting Lab"
echo "=============================================="
echo ""

# Esperar a que Kibana esté listo
echo "[*] Esperando a que Kibana esté disponible..."
until curl -s "${KIBANA_URL}/api/status" | grep -q '"level":"available"'; do
    echo "    Kibana no disponible aún, esperando 10s..."
    sleep 10
done
echo "[✓] Kibana está listo"

# ============================================================================
# 1. CREAR INDEX PATTERNS
# ============================================================================
echo ""
echo "[*] Creando Index Patterns..."

# Osquery Results
curl -s -X POST "${KIBANA_URL}/api/saved_objects/index-pattern/osquery-results" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{
        "attributes": {
            "title": "osquery-results-*",
            "timeFieldName": "@timestamp"
        }
    }' > /dev/null
echo "  [✓] Index pattern: osquery-results-*"

# Process Events
curl -s -X POST "${KIBANA_URL}/api/saved_objects/index-pattern/process-events" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{
        "attributes": {
            "title": "process-events-*",
            "timeFieldName": "@timestamp"
        }
    }' > /dev/null
echo "  [✓] Index pattern: process-events-*"

# Network Events
curl -s -X POST "${KIBANA_URL}/api/saved_objects/index-pattern/network-events" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{
        "attributes": {
            "title": "network-events-*",
            "timeFieldName": "@timestamp"
        }
    }' > /dev/null
echo "  [✓] Index pattern: network-events-*"

# Syslog
curl -s -X POST "${KIBANA_URL}/api/saved_objects/index-pattern/syslog" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{
        "attributes": {
            "title": "syslog-*",
            "timeFieldName": "@timestamp"
        }
    }' > /dev/null
echo "  [✓] Index pattern: syslog-*"

# Threat Hunting (general)
curl -s -X POST "${KIBANA_URL}/api/saved_objects/index-pattern/threat-hunting" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{
        "attributes": {
            "title": "threat-hunting-*",
            "timeFieldName": "@timestamp"
        }
    }' > /dev/null
echo "  [✓] Index pattern: threat-hunting-*"

# All events (wildcard)
curl -s -X POST "${KIBANA_URL}/api/saved_objects/index-pattern/all-events" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{
        "attributes": {
            "title": "*-*",
            "timeFieldName": "@timestamp"
        }
    }' > /dev/null
echo "  [✓] Index pattern: *-* (all events)"

# ============================================================================
# 2. CREAR DASHBOARDS VIA NDJSON IMPORT
# ============================================================================
echo ""
echo "[*] Importando dashboards..."

# Crear archivo NDJSON con el dashboard principal
cat > /tmp/threat_hunting_dashboard.ndjson << 'NDJSON'
{"attributes":{"description":"Dashboard principal de Threat Hunting - Monitoreo en tiempo real de todos los endpoints","hits":0,"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"},"optionsJSON":"{\"useMargins\":true,\"syncColors\":false,\"syncCursor\":true,\"syncTooltips\":false,\"hidePanelTitles\":false}","panelsJSON":"[]","refreshInterval":{"pause":false,"value":5000},"timeFrom":"now-1h","timeRestore":true,"timeTo":"now","title":"🔍 Threat Hunting - Main Dashboard","version":1},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"threat-hunting-main","managed":false,"references":[],"type":"dashboard","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
NDJSON

curl -s -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
    -H "kbn-xsrf: true" \
    --form file=@/tmp/threat_hunting_dashboard.ndjson > /dev/null
echo "  [✓] Dashboard principal importado"

# ============================================================================
# 3. CONFIGURAR DEFAULT INDEX PATTERN
# ============================================================================
echo ""
echo "[*] Configurando default index pattern..."
curl -s -X POST "${KIBANA_URL}/api/kibana/settings" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{"changes":{"defaultIndex":"threat-hunting"}}' > /dev/null
echo "  [✓] Default index pattern configurado"

# ============================================================================
# 4. CREAR TEMPLATE DE ELASTICSEARCH
# ============================================================================
echo ""
echo "[*] Creando index templates en Elasticsearch..."

# Template para osquery results
curl -s -X PUT "${ES_URL}/_index_template/osquery-results" \
    -H "Content-Type: application/json" \
    -d '{
        "index_patterns": ["osquery-results-*"],
        "template": {
            "settings": {
                "number_of_shards": 1,
                "number_of_replicas": 0
            },
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "endpoint.name": {"type": "keyword"},
                    "endpoint.hostname": {"type": "keyword"},
                    "osquery.query_name": {"type": "keyword"},
                    "osquery.hostIdentifier": {"type": "keyword"},
                    "risk_level": {"type": "keyword"},
                    "threat.technique.id": {"type": "keyword"},
                    "threat.framework": {"type": "keyword"},
                    "event.module": {"type": "keyword"},
                    "tags": {"type": "keyword"}
                }
            }
        }
    }' > /dev/null
echo "  [✓] Template: osquery-results"

# Template para process events
curl -s -X PUT "${ES_URL}/_index_template/process-events" \
    -H "Content-Type: application/json" \
    -d '{
        "index_patterns": ["process-events-*"],
        "template": {
            "settings": {
                "number_of_shards": 1,
                "number_of_replicas": 0
            },
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "hostname": {"type": "keyword"},
                    "endpoint": {"type": "keyword"},
                    "event_type": {"type": "keyword"},
                    "process.pid": {"type": "integer"},
                    "process.ppid": {"type": "integer"},
                    "process.name": {"type": "keyword"},
                    "process.cmdline": {"type": "text", "fields": {"keyword": {"type": "keyword"}}},
                    "process.path": {"type": "keyword"},
                    "process.user": {"type": "keyword"},
                    "risk_level": {"type": "keyword"},
                    "threat.technique.id": {"type": "keyword"},
                    "tags": {"type": "keyword"}
                }
            }
        }
    }' > /dev/null
echo "  [✓] Template: process-events"

# Template para network events
curl -s -X PUT "${ES_URL}/_index_template/network-events" \
    -H "Content-Type: application/json" \
    -d '{
        "index_patterns": ["network-events-*"],
        "template": {
            "settings": {
                "number_of_shards": 1,
                "number_of_replicas": 0
            },
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "hostname": {"type": "keyword"},
                    "endpoint": {"type": "keyword"},
                    "event_type": {"type": "keyword"},
                    "network.protocol": {"type": "keyword"},
                    "network.local_address": {"type": "ip"},
                    "network.local_port": {"type": "integer"},
                    "network.remote_address": {"type": "ip"},
                    "network.remote_port": {"type": "integer"},
                    "network.state": {"type": "keyword"},
                    "process.pid": {"type": "integer"},
                    "process.name": {"type": "keyword"},
                    "risk_level": {"type": "keyword"},
                    "threat_type": {"type": "keyword"},
                    "tags": {"type": "keyword"}
                }
            }
        }
    }' > /dev/null
echo "  [✓] Template: network-events"

# Template para threat-hunting (general/attack simulation)
curl -s -X PUT "${ES_URL}/_index_template/threat-hunting" \
    -H "Content-Type: application/json" \
    -d '{
        "index_patterns": ["threat-hunting-*"],
        "template": {
            "settings": {
                "number_of_shards": 1,
                "number_of_replicas": 0
            },
            "mappings": {
                "properties": {
                    "@timestamp": {"type": "date"},
                    "timestamp": {"type": "date"},
                    "hostname": {"type": "keyword"},
                    "endpoint": {"type": "keyword"},
                    "event_type": {"type": "keyword"},
                    "technique": {"type": "keyword"},
                    "risk_level": {"type": "keyword"},
                    "severity": {"type": "keyword"},
                    "threat_type": {"type": "keyword"},
                    "source_host": {"type": "keyword"},
                    "destination_host": {"type": "keyword"},
                    "source_ip": {"type": "keyword"},
                    "method": {"type": "keyword"},
                    "action": {"type": "keyword"},
                    "user": {"type": "keyword"},
                    "file_path": {"type": "keyword"},
                    "process": {"type": "keyword"},
                    "c2_connection": {"type": "keyword"},
                    "tags": {"type": "keyword"}
                }
            }
        }
    }' > /dev/null
echo "  [✓] Template: threat-hunting"

echo ""
echo "=============================================="
echo "  ✅ SETUP COMPLETADO"
echo ""
echo "  Accede a Kibana: ${KIBANA_URL}"
echo "  Dashboard: ${KIBANA_URL}/app/dashboards"
echo "  Discover: ${KIBANA_URL}/app/discover"
echo ""
echo "  Index Patterns disponibles:"
echo "    - osquery-results-*"
echo "    - process-events-*"
echo "    - network-events-*"
echo "    - syslog-*"
echo "    - threat-hunting-*"
echo ""
echo "  Queries de ejemplo en Discover:"
echo "    risk_level: HIGH OR risk_level: CRITICAL"
echo "    event_type: lateral_movement"
echo "    technique: T1021*"
echo "    endpoint: WS-FINANZAS-01"
echo "=============================================="
