#!/bin/bash
###############################################################################
# IMPORT DASHBOARDS - Crea visualizaciones y dashboard usando tipos estables
# Usa visualization (legacy aggregation-based) en vez de Lens para evitar
# problemas de migración con la API _import de Kibana 8.12
#
# Uso: ./import_dashboards.sh [kibana_url]
###############################################################################

KIBANA_URL="${1:-http://localhost:5601}"

echo "=============================================="
echo "  IMPORTANDO DASHBOARD"
echo "  Kibana: ${KIBANA_URL}"
echo "=============================================="

# Esperar a Kibana
for i in $(seq 1 30); do
    if curl -s "${KIBANA_URL}/api/status" 2>/dev/null | grep -q "available"; then
        break
    fi
    sleep 3
done

# Obtener el ID del data view
DV_ID=$(curl -s "${KIBANA_URL}/api/data_views" -H "kbn-xsrf: true" 2>/dev/null | \
    python3 -c "
import json,sys
try:
    data = json.load(sys.stdin)
    for dv in data.get('data_view', []):
        if 'threat-hunting' in dv.get('title',''):
            print(dv['id']); break
    else: print('')
except: print('')
" 2>/dev/null)

if [ -z "$DV_ID" ]; then
    DV_ID="threat-hunting"
fi
echo "  Data View ID: ${DV_ID}"

# ============================================================================
# Crear visualizaciones usando el tipo 'visualization' (legacy, estable)
# ============================================================================
echo "[*] Creando visualizaciones..."

# Función helper para crear una visualización
create_vis() {
    local id="$1"
    local body="$2"
    
    # Intentar crear, si existe actualizar
    curl -s -X POST "${KIBANA_URL}/api/saved_objects/visualization/${id}?overwrite=true" \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        -d "$body" > /dev/null 2>&1
}

# VIS 1: Metric - Critical Events Count
create_vis "vis-critical-count" '{
  "attributes": {
    "title": "Critical Events Count",
    "visState": "{\"title\":\"Critical Events Count\",\"type\":\"metric\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"}],\"params\":{\"metric\":{\"percentageMode\":false,\"colorSchema\":\"Green to Red\",\"metricColorMode\":\"Labels\",\"colorsRange\":[{\"from\":0,\"to\":100}],\"labels\":{\"show\":true},\"style\":{\"bgColor\":false,\"labelColor\":true,\"fontSize\":60}},\"addTooltip\":true,\"addLegend\":false,\"type\":\"metric\"}}",
    "uiStateJSON": "{}",
    "description": "Total de eventos criticos",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"risk_level: \\\"CRITICAL\\\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [{"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": "'"${DV_ID}"'"}]
}'
echo "  [+] Critical Events Count"

# VIS 2: Metric - Endpoints Comprometidos
create_vis "vis-endpoints-count" '{
  "attributes": {
    "title": "Endpoints Comprometidos",
    "visState": "{\"title\":\"Endpoints Comprometidos\",\"type\":\"metric\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"cardinality\",\"params\":{\"field\":\"endpoint\"},\"schema\":\"metric\"}],\"params\":{\"metric\":{\"percentageMode\":false,\"colorSchema\":\"Green to Red\",\"metricColorMode\":\"Labels\",\"colorsRange\":[{\"from\":0,\"to\":10}],\"labels\":{\"show\":true},\"style\":{\"bgColor\":false,\"labelColor\":true,\"fontSize\":60}},\"addTooltip\":true,\"addLegend\":false,\"type\":\"metric\"}}",
    "uiStateJSON": "{}",
    "description": "Endpoints unicos comprometidos",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"risk_level: \\\"CRITICAL\\\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [{"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": "'"${DV_ID}"'"}]
}'
echo "  [+] Endpoints Comprometidos"

# VIS 3: Metric - Tecnicas MITRE
create_vis "vis-mitre-count" '{
  "attributes": {
    "title": "Tecnicas MITRE ATT&CK",
    "visState": "{\"title\":\"Tecnicas MITRE ATT&CK\",\"type\":\"metric\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"cardinality\",\"params\":{\"field\":\"technique\"},\"schema\":\"metric\"}],\"params\":{\"metric\":{\"percentageMode\":false,\"colorSchema\":\"Green to Red\",\"metricColorMode\":\"Labels\",\"colorsRange\":[{\"from\":0,\"to\":20}],\"labels\":{\"show\":true},\"style\":{\"bgColor\":false,\"labelColor\":true,\"fontSize\":60}},\"addTooltip\":true,\"addLegend\":false,\"type\":\"metric\"}}",
    "uiStateJSON": "{}",
    "description": "Tecnicas unicas detectadas",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [{"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": "'"${DV_ID}"'"}]
}'
echo "  [+] Tecnicas MITRE"

# VIS 4: Pie - Risk Level Distribution
create_vis "vis-risk-pie" '{
  "attributes": {
    "title": "Risk Level Distribution",
    "visState": "{\"title\":\"Risk Level Distribution\",\"type\":\"pie\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"risk_level\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":5},\"schema\":\"segment\"}],\"params\":{\"type\":\"pie\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"isDonut\":false,\"labels\":{\"show\":true,\"values\":true,\"last_level\":true,\"truncate\":100}}}",
    "uiStateJSON": "{}",
    "description": "Distribucion por nivel de riesgo",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [{"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": "'"${DV_ID}"'"}]
}'
echo "  [+] Risk Level Pie"

# VIS 5: Area chart - Attack Timeline
create_vis "vis-attack-timeline" '{
  "attributes": {
    "title": "Attack Timeline",
    "visState": "{\"title\":\"Attack Timeline\",\"type\":\"area\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"date_histogram\",\"params\":{\"field\":\"@timestamp\",\"useNormalizedEsInterval\":true,\"scaleMetricValues\":false,\"interval\":\"auto\",\"drop_partials\":false,\"min_doc_count\":0,\"extended_bounds\":{}},\"schema\":\"segment\"}],\"params\":{\"type\":\"area\",\"grid\":{\"categoryLines\":false},\"categoryAxes\":[{\"id\":\"CategoryAxis-1\",\"type\":\"category\",\"position\":\"bottom\",\"show\":true,\"labels\":{\"show\":true,\"truncate\":100},\"title\":{}}],\"valueAxes\":[{\"id\":\"ValueAxis-1\",\"name\":\"LeftAxis-1\",\"type\":\"value\",\"position\":\"left\",\"show\":true,\"labels\":{\"show\":true},\"title\":{}}],\"seriesParams\":[{\"show\":true,\"type\":\"area\",\"mode\":\"stacked\",\"data\":{\"label\":\"Count\",\"id\":\"1\"},\"valueAxis\":\"ValueAxis-1\",\"drawLinesBetweenPoints\":true,\"lineWidth\":2,\"showCircles\":true,\"interpolate\":\"linear\"}],\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"times\":[],\"addTimeMarker\":false,\"thresholdLine\":{\"show\":false,\"value\":10,\"width\":1,\"style\":\"full\",\"color\":\"#E7664C\"}}}",
    "uiStateJSON": "{}",
    "description": "Eventos en el tiempo",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [{"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": "'"${DV_ID}"'"}]
}'
echo "  [+] Attack Timeline"

# VIS 6: Pie - Events by Type
create_vis "vis-events-type" '{
  "attributes": {
    "title": "Events by Attack Phase",
    "visState": "{\"title\":\"Events by Attack Phase\",\"type\":\"pie\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"event_type\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":10},\"schema\":\"segment\"}],\"params\":{\"type\":\"pie\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"isDonut\":true,\"labels\":{\"show\":true,\"values\":true,\"last_level\":true,\"truncate\":100}}}",
    "uiStateJSON": "{}",
    "description": "Distribucion por fase del ataque",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [{"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": "'"${DV_ID}"'"}]
}'
echo "  [+] Events by Phase"

# VIS 7: Tagcloud - Events by Endpoint (compatible con Kibana 8.12)
create_vis "vis-events-endpoint" '{
  "attributes": {
    "title": "Events by Endpoint",
    "visState": "{\"title\":\"Events by Endpoint\",\"type\":\"pie\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"endpoint\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":10},\"schema\":\"segment\"}],\"params\":{\"type\":\"pie\",\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"isDonut\":false,\"labels\":{\"show\":true,\"values\":true,\"last_level\":true,\"truncate\":100}}}",
    "uiStateJSON": "{}",
    "description": "Actividad por endpoint",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [{"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": "'"${DV_ID}"'"}]
}'
echo "  [+] Events by Endpoint"

# VIS 8: Table - MITRE Techniques
create_vis "vis-mitre-table" '{
  "attributes": {
    "title": "MITRE ATT&CK Techniques",
    "visState": "{\"title\":\"MITRE ATT&CK Techniques\",\"type\":\"table\",\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"count\",\"params\":{},\"schema\":\"metric\"},{\"id\":\"2\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"technique\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":20},\"schema\":\"bucket\"},{\"id\":\"3\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"tactic\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":20},\"schema\":\"bucket\"},{\"id\":\"4\",\"enabled\":true,\"type\":\"terms\",\"params\":{\"field\":\"endpoint\",\"orderBy\":\"1\",\"order\":\"desc\",\"size\":20},\"schema\":\"bucket\"}],\"params\":{\"perPage\":10,\"showPartialRows\":false,\"showMetricsAtAllLevels\":false,\"showTotal\":false,\"totalFunc\":\"sum\",\"percentageCol\":\"\"}}",
    "uiStateJSON": "{\"vis\":{\"params\":{\"sort\":{\"columnIndex\":null,\"direction\":null}}}}",
    "description": "Tabla de tecnicas MITRE detectadas",
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[],\"indexRefName\":\"kibanaSavedObjectMeta.searchSourceJSON.index\"}"
    }
  },
  "references": [{"name": "kibanaSavedObjectMeta.searchSourceJSON.index", "type": "index-pattern", "id": "'"${DV_ID}"'"}]
}'
echo "  [+] MITRE Table"

# ============================================================================
# Crear el Dashboard referenciando las visualizaciones
# ============================================================================
echo "[*] Creando dashboard..."

PANELS='[{"version":"8.12.0","type":"visualization","gridData":{"x":0,"y":0,"w":12,"h":8,"i":"p0"},"panelIndex":"p0","embeddableConfig":{},"panelRefName":"panel_0"},{"version":"8.12.0","type":"visualization","gridData":{"x":12,"y":0,"w":12,"h":8,"i":"p1"},"panelIndex":"p1","embeddableConfig":{},"panelRefName":"panel_1"},{"version":"8.12.0","type":"visualization","gridData":{"x":24,"y":0,"w":12,"h":8,"i":"p2"},"panelIndex":"p2","embeddableConfig":{},"panelRefName":"panel_2"},{"version":"8.12.0","type":"visualization","gridData":{"x":36,"y":0,"w":12,"h":8,"i":"p3"},"panelIndex":"p3","embeddableConfig":{},"panelRefName":"panel_3"},{"version":"8.12.0","type":"visualization","gridData":{"x":0,"y":8,"w":48,"h":12,"i":"p4"},"panelIndex":"p4","embeddableConfig":{},"panelRefName":"panel_4"},{"version":"8.12.0","type":"visualization","gridData":{"x":0,"y":20,"w":16,"h":14,"i":"p5"},"panelIndex":"p5","embeddableConfig":{},"panelRefName":"panel_5"},{"version":"8.12.0","type":"visualization","gridData":{"x":16,"y":20,"w":16,"h":14,"i":"p6"},"panelIndex":"p6","embeddableConfig":{},"panelRefName":"panel_6"},{"version":"8.12.0","type":"visualization","gridData":{"x":32,"y":20,"w":16,"h":14,"i":"p7"},"panelIndex":"p7","embeddableConfig":{},"panelRefName":"panel_7"}]'

curl -s -X POST "${KIBANA_URL}/api/saved_objects/dashboard/threat-hunting-overview?overwrite=true" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d '{
  "attributes": {
    "title": "Threat Hunting - Attack Overview",
    "description": "Dashboard de monitoreo en tiempo real del ataque APT simulado",
    "panelsJSON": "'"$(echo $PANELS | sed 's/"/\\"/g')"'",
    "optionsJSON": "{\"useMargins\":true,\"syncColors\":true,\"hidePanelTitles\":false}",
    "timeRestore": true,
    "timeFrom": "now-2h",
    "timeTo": "now",
    "refreshInterval": {"pause": false, "value": 5000},
    "kibanaSavedObjectMeta": {
      "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"
    }
  },
  "references": [
    {"name": "panel_0", "type": "visualization", "id": "vis-critical-count"},
    {"name": "panel_1", "type": "visualization", "id": "vis-endpoints-count"},
    {"name": "panel_2", "type": "visualization", "id": "vis-mitre-count"},
    {"name": "panel_3", "type": "visualization", "id": "vis-risk-pie"},
    {"name": "panel_4", "type": "visualization", "id": "vis-attack-timeline"},
    {"name": "panel_5", "type": "visualization", "id": "vis-events-type"},
    {"name": "panel_6", "type": "visualization", "id": "vis-events-endpoint"},
    {"name": "panel_7", "type": "visualization", "id": "vis-mitre-table"}
  ]
}' > /dev/null 2>&1

echo "  [+] Dashboard creado"

echo ""
echo "=============================================="
echo "  DASHBOARD LISTO"
echo "  Ir a: ${KIBANA_URL}/app/dashboards"
echo "  Abrir: 'Threat Hunting - Attack Overview'"
echo ""
echo "  Paneles:"
echo "    [1] Critical Events (metrica)"
echo "    [2] Endpoints Comprometidos (metrica)"
echo "    [3] Tecnicas MITRE (metrica)"
echo "    [4] Risk Distribution (pie)"
echo "    [5] Attack Timeline (histograma)"
echo "    [6] Events by Phase (donut)"
echo "    [7] Events by Endpoint (bar horizontal)"
echo "    [8] MITRE Techniques (tabla)"
echo "=============================================="
