#!/bin/bash
###############################################################################
# IMPORT DASHBOARDS - Crea dashboards con visualizaciones REALES en Kibana
# Usa la API de Saved Objects para importar paneles Lens pre-configurados
#
# Uso: ./import_dashboards.sh [kibana_url]
###############################################################################

KIBANA_URL="${1:-http://localhost:5601}"

echo "=============================================="
echo "  IMPORTANDO DASHBOARDS CON VISUALIZACIONES"
echo "  Kibana: ${KIBANA_URL}"
echo "=============================================="

# Esperar a Kibana
echo "[*] Verificando Kibana..."
for i in $(seq 1 30); do
    if curl -s "${KIBANA_URL}/api/status" 2>/dev/null | grep -q "available"; then
        break
    fi
    sleep 3
done

# Primero necesitamos obtener el ID del data view de threat-hunting
echo "[*] Obteniendo Data View ID..."
DV_ID=$(curl -s "${KIBANA_URL}/api/data_views" \
    -H "kbn-xsrf: true" 2>/dev/null | python3 -c "
import json,sys
try:
    data = json.load(sys.stdin)
    for dv in data.get('data_view', []):
        if 'threat-hunting' in dv.get('title',''):
            print(dv['id'])
            break
    else:
        print('threat-hunting')
except:
    print('threat-hunting')
" 2>/dev/null)

if [ -z "$DV_ID" ]; then
    DV_ID="threat-hunting"
fi
echo "  Data View ID: ${DV_ID}"

# ============================================================================
# CREAR NDJSON CON DASHBOARD + VISUALIZACIONES
# ============================================================================
echo "[*] Generando dashboard con visualizaciones..."

cat > /tmp/full_dashboard.ndjson << 'DASHBOARD_EOF'
{"attributes":{"fieldAttrs":"{}","fieldFormatMap":"{}","fields":"[]","name":"Threat Hunting Events","runtimeFieldMap":"{}","sourceFilters":"[]","timeFieldName":"@timestamp","title":"threat-hunting-*","typeMeta":"{}"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"idx-threat-hunting","managed":false,"references":[],"type":"index-pattern","typeMigrationVersion":"8.0.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"fieldAttrs":"{}","fieldFormatMap":"{}","fields":"[]","name":"Process Events","runtimeFieldMap":"{}","sourceFilters":"[]","timeFieldName":"@timestamp","title":"process-events-*","typeMeta":"{}"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"idx-process-events","managed":false,"references":[],"type":"index-pattern","typeMigrationVersion":"8.0.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"fieldAttrs":"{}","fieldFormatMap":"{}","fields":"[]","name":"Network Events","runtimeFieldMap":"{}","sourceFilters":"[]","timeFieldName":"@timestamp","title":"network-events-*","typeMeta":"{}"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"idx-network-events","managed":false,"references":[],"type":"index-pattern","typeMigrationVersion":"8.0.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"fieldAttrs":"{}","fieldFormatMap":"{}","fields":"[]","name":"Osquery Results","runtimeFieldMap":"{}","sourceFilters":"[]","timeFieldName":"@timestamp","title":"osquery-results-*","typeMeta":"{}"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"idx-osquery-results","managed":false,"references":[],"type":"index-pattern","typeMigrationVersion":"8.0.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"description":"Total de eventos criticos detectados","state":{"datasourceStates":{"formBased":{"layers":{"layer1":{"columnOrder":["metric"],"columns":{"metric":{"dataType":"number","isBucketed":false,"label":"Critical Events","operationType":"count","params":{},"scale":"ratio","sourceField":"___records___","filter":{"language":"kuery","query":"risk_level: \"CRITICAL\""}}},"incompleteColumns":{}}}}},"filters":[],"internalReferences":[],"query":{"language":"kuery","query":""},"visualization":{"accessor":"metric","layerId":"layer1","layerType":"data","size":"xl","titlePosition":"bottom","textAlign":"center","color":"#BD271E"}},"title":"Critical Events Count","visualizationType":"lnsMetric"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"vis-critical-count","managed":false,"references":[{"id":"idx-threat-hunting","name":"indexpattern-datasource-layer-layer1","type":"index-pattern"}],"type":"lens","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"description":"Total de endpoints comprometidos","state":{"datasourceStates":{"formBased":{"layers":{"layer1":{"columnOrder":["metric"],"columns":{"metric":{"dataType":"number","isBucketed":false,"label":"Endpoints Comprometidos","operationType":"unique_count","params":{},"scale":"ratio","sourceField":"endpoint"}},"incompleteColumns":{}}}}},"filters":[],"internalReferences":[],"query":{"language":"kuery","query":"risk_level: \"CRITICAL\""},"visualization":{"accessor":"metric","layerId":"layer1","layerType":"data","size":"xl","titlePosition":"bottom","textAlign":"center","color":"#F5A700"}},"title":"Endpoints Comprometidos","visualizationType":"lnsMetric"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"vis-endpoints-compromised","managed":false,"references":[{"id":"idx-threat-hunting","name":"indexpattern-datasource-layer-layer1","type":"index-pattern"}],"type":"lens","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"description":"Tecnicas MITRE detectadas","state":{"datasourceStates":{"formBased":{"layers":{"layer1":{"columnOrder":["metric"],"columns":{"metric":{"dataType":"number","isBucketed":false,"label":"Tecnicas MITRE","operationType":"unique_count","params":{},"scale":"ratio","sourceField":"technique"}},"incompleteColumns":{}}}}},"filters":[],"internalReferences":[],"query":{"language":"kuery","query":""},"visualization":{"accessor":"metric","layerId":"layer1","layerType":"data","size":"xl","titlePosition":"bottom","textAlign":"center","color":"#6092C0"}},"title":"Tecnicas MITRE ATT&CK","visualizationType":"lnsMetric"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"vis-mitre-count","managed":false,"references":[{"id":"idx-threat-hunting","name":"indexpattern-datasource-layer-layer1","type":"index-pattern"}],"type":"lens","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"description":"Eventos de ataque en el tiempo","state":{"datasourceStates":{"formBased":{"layers":{"layer1":{"columnOrder":["date","count"],"columns":{"date":{"dataType":"date","isBucketed":true,"label":"@timestamp","operationType":"date_histogram","params":{"interval":"auto","includeEmptyRows":true},"scale":"interval","sourceField":"@timestamp"},"count":{"dataType":"number","isBucketed":false,"label":"Count","operationType":"count","params":{},"scale":"ratio","sourceField":"___records___"}},"incompleteColumns":{}}}}},"filters":[],"internalReferences":[],"query":{"language":"kuery","query":""},"visualization":{"axisTitlesVisibilitySettings":{"x":true,"yLeft":true,"yRight":true},"fittingFunction":"None","gridlinesVisibilitySettings":{"x":true,"yLeft":true,"yRight":true},"labelsOrientation":{"x":0,"yLeft":0,"yRight":0},"layers":[{"accessors":["count"],"layerId":"layer1","layerType":"data","position":"top","seriesType":"bar_stacked","showGridlines":false,"xAccessor":"date","yConfig":[{"color":"#BD271E","forAccessor":"count"}]}],"legend":{"isVisible":true,"position":"right"},"preferredSeriesType":"bar_stacked","tickLabelsVisibilitySettings":{"x":true,"yLeft":true,"yRight":true},"valueLabels":"hide","yLeftExtent":{"mode":"full"},"yRightExtent":{"mode":"full"}}},"title":"Attack Timeline","visualizationType":"lnsXY"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"vis-attack-timeline","managed":false,"references":[{"id":"idx-threat-hunting","name":"indexpattern-datasource-layer-layer1","type":"index-pattern"}],"type":"lens","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"description":"Distribucion de eventos por tipo","state":{"datasourceStates":{"formBased":{"layers":{"layer1":{"columnOrder":["event_type","count"],"columns":{"event_type":{"dataType":"string","isBucketed":true,"label":"Event Type","operationType":"terms","params":{"orderBy":{"columnId":"count","type":"column"},"orderDirection":"desc","size":10},"scale":"ordinal","sourceField":"event_type"},"count":{"dataType":"number","isBucketed":false,"label":"Count","operationType":"count","params":{},"scale":"ratio","sourceField":"___records___"}},"incompleteColumns":{}}}}},"filters":[],"internalReferences":[],"query":{"language":"kuery","query":""},"visualization":{"layers":[{"categoryDisplay":"default","layerId":"layer1","layerType":"data","legendDisplay":"show","metrics":["count"],"nestedLegend":false,"numberDisplay":"percent","primaryGroups":["event_type"]}],"shape":"donut"}},"title":"Events by Type","visualizationType":"lnsPie"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"vis-events-by-type","managed":false,"references":[{"id":"idx-threat-hunting","name":"indexpattern-datasource-layer-layer1","type":"index-pattern"}],"type":"lens","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"description":"Eventos por endpoint","state":{"datasourceStates":{"formBased":{"layers":{"layer1":{"columnOrder":["endpoint","count"],"columns":{"endpoint":{"dataType":"string","isBucketed":true,"label":"Endpoint","operationType":"terms","params":{"orderBy":{"columnId":"count","type":"column"},"orderDirection":"desc","size":10},"scale":"ordinal","sourceField":"endpoint"},"count":{"dataType":"number","isBucketed":false,"label":"Events","operationType":"count","params":{},"scale":"ratio","sourceField":"___records___"}},"incompleteColumns":{}}}}},"filters":[],"internalReferences":[],"query":{"language":"kuery","query":""},"visualization":{"axisTitlesVisibilitySettings":{"x":true,"yLeft":true,"yRight":true},"fittingFunction":"None","gridlinesVisibilitySettings":{"x":true,"yLeft":true,"yRight":true},"layers":[{"accessors":["count"],"layerId":"layer1","layerType":"data","position":"top","seriesType":"bar_horizontal","showGridlines":false,"xAccessor":"endpoint"}],"legend":{"isVisible":false,"position":"right"},"preferredSeriesType":"bar_horizontal","valueLabels":"show"}},"title":"Events by Endpoint","visualizationType":"lnsXY"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"vis-events-by-endpoint","managed":false,"references":[{"id":"idx-threat-hunting","name":"indexpattern-datasource-layer-layer1","type":"index-pattern"}],"type":"lens","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"description":"Distribucion por nivel de riesgo","state":{"datasourceStates":{"formBased":{"layers":{"layer1":{"columnOrder":["risk","count"],"columns":{"risk":{"dataType":"string","isBucketed":true,"label":"Risk Level","operationType":"terms","params":{"orderBy":{"columnId":"count","type":"column"},"orderDirection":"desc","size":5},"scale":"ordinal","sourceField":"risk_level"},"count":{"dataType":"number","isBucketed":false,"label":"Count","operationType":"count","params":{},"scale":"ratio","sourceField":"___records___"}},"incompleteColumns":{}}}}},"filters":[],"internalReferences":[],"query":{"language":"kuery","query":""},"visualization":{"layers":[{"categoryDisplay":"default","layerId":"layer1","layerType":"data","legendDisplay":"show","metrics":["count"],"nestedLegend":false,"numberDisplay":"value","primaryGroups":["risk"]}],"shape":"pie"}},"title":"Risk Level Distribution","visualizationType":"lnsPie"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"vis-risk-distribution","managed":false,"references":[{"id":"idx-threat-hunting","name":"indexpattern-datasource-layer-layer1","type":"index-pattern"}],"type":"lens","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"description":"Tecnicas MITRE ATT&CK utilizadas","state":{"datasourceStates":{"formBased":{"layers":{"layer1":{"columnOrder":["technique","count"],"columns":{"technique":{"dataType":"string","isBucketed":true,"label":"Technique","operationType":"terms","params":{"orderBy":{"columnId":"count","type":"column"},"orderDirection":"desc","size":15},"scale":"ordinal","sourceField":"technique"},"count":{"dataType":"number","isBucketed":false,"label":"Count","operationType":"count","params":{},"scale":"ratio","sourceField":"___records___"}},"incompleteColumns":{}}}}},"filters":[],"internalReferences":[],"query":{"language":"kuery","query":""},"visualization":{"columns":[{"columnId":"technique","isTransposed":false},{"columnId":"count","isTransposed":false}],"headerRowHeight":"auto","layerId":"layer1","layerType":"data","rowHeight":"auto"}},"title":"MITRE ATT&CK Techniques","visualizationType":"lnsDatatable"},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"vis-mitre-table","managed":false,"references":[{"id":"idx-threat-hunting","name":"indexpattern-datasource-layer-layer1","type":"index-pattern"}],"type":"lens","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
{"attributes":{"description":"Dashboard principal de Threat Hunting - Monitoreo en tiempo real del ataque APT","hits":0,"kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"},"optionsJSON":"{\"useMargins\":true,\"syncColors\":true,\"syncCursor\":true,\"syncTooltips\":true,\"hidePanelTitles\":false}","panelsJSON":"[{\"version\":\"8.12.0\",\"type\":\"lens\",\"gridData\":{\"x\":0,\"y\":0,\"w\":12,\"h\":8,\"i\":\"p1\"},\"panelIndex\":\"p1\",\"embeddableConfig\":{\"enhancements\":{}},\"panelRefName\":\"panel_p1\"},{\"version\":\"8.12.0\",\"type\":\"lens\",\"gridData\":{\"x\":12,\"y\":0,\"w\":12,\"h\":8,\"i\":\"p2\"},\"panelIndex\":\"p2\",\"embeddableConfig\":{\"enhancements\":{}},\"panelRefName\":\"panel_p2\"},{\"version\":\"8.12.0\",\"type\":\"lens\",\"gridData\":{\"x\":24,\"y\":0,\"w\":12,\"h\":8,\"i\":\"p3\"},\"panelIndex\":\"p3\",\"embeddableConfig\":{\"enhancements\":{}},\"panelRefName\":\"panel_p3\"},{\"version\":\"8.12.0\",\"type\":\"lens\",\"gridData\":{\"x\":36,\"y\":0,\"w\":12,\"h\":8,\"i\":\"p4\"},\"panelIndex\":\"p4\",\"embeddableConfig\":{\"enhancements\":{}},\"panelRefName\":\"panel_p4\"},{\"version\":\"8.12.0\",\"type\":\"lens\",\"gridData\":{\"x\":0,\"y\":8,\"w\":48,\"h\":12,\"i\":\"p5\"},\"panelIndex\":\"p5\",\"embeddableConfig\":{\"enhancements\":{}},\"panelRefName\":\"panel_p5\"},{\"version\":\"8.12.0\",\"type\":\"lens\",\"gridData\":{\"x\":0,\"y\":20,\"w\":20,\"h\":14,\"i\":\"p6\"},\"panelIndex\":\"p6\",\"embeddableConfig\":{\"enhancements\":{}},\"panelRefName\":\"panel_p6\"},{\"version\":\"8.12.0\",\"type\":\"lens\",\"gridData\":{\"x\":20,\"y\":20,\"w\":14,\"h\":14,\"i\":\"p7\"},\"panelIndex\":\"p7\",\"embeddableConfig\":{\"enhancements\":{}},\"panelRefName\":\"panel_p7\"},{\"version\":\"8.12.0\",\"type\":\"lens\",\"gridData\":{\"x\":34,\"y\":20,\"w\":14,\"h\":14,\"i\":\"p8\"},\"panelIndex\":\"p8\",\"embeddableConfig\":{\"enhancements\":{}},\"panelRefName\":\"panel_p8\"},{\"version\":\"8.12.0\",\"type\":\"lens\",\"gridData\":{\"x\":0,\"y\":34,\"w\":48,\"h\":12,\"i\":\"p9\"},\"panelIndex\":\"p9\",\"embeddableConfig\":{\"enhancements\":{}},\"panelRefName\":\"panel_p9\"}]","refreshInterval":{"pause":false,"value":5000},"timeFrom":"now-2h","timeRestore":true,"timeTo":"now","title":"Threat Hunting - Attack Overview","version":1},"coreMigrationVersion":"8.8.0","created_at":"2024-01-01T00:00:00.000Z","id":"threat-hunting-overview","managed":false,"references":[{"id":"vis-critical-count","name":"panel_p1","type":"lens"},{"id":"vis-endpoints-compromised","name":"panel_p2","type":"lens"},{"id":"vis-mitre-count","name":"panel_p3","type":"lens"},{"id":"vis-risk-distribution","name":"panel_p4","type":"lens"},{"id":"vis-attack-timeline","name":"panel_p5","type":"lens"},{"id":"vis-events-by-type","name":"panel_p6","type":"lens"},{"id":"vis-events-by-endpoint","name":"panel_p7","type":"lens"},{"id":"vis-mitre-table","name":"panel_p8","type":"lens"},{"id":"vis-mitre-table","name":"panel_p9","type":"lens"}],"type":"dashboard","typeMigrationVersion":"8.9.0","updated_at":"2024-01-01T00:00:00.000Z","version":"1"}
DASHBOARD_EOF

# Importar
echo "[*] Importando dashboard con visualizaciones..."
RESULT=$(curl -s -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
    -H "kbn-xsrf: true" \
    --form file=@/tmp/full_dashboard.ndjson 2>&1)

if echo "$RESULT" | grep -q '"success":true'; then
    echo "[+] Dashboard importado exitosamente con 9 paneles"
else
    echo "[!] Resultado de importacion:"
    echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
fi

rm -f /tmp/full_dashboard.ndjson

echo ""
echo "=============================================="
echo "  DASHBOARD LISTO"
echo "=============================================="
echo ""
echo "  Acceder: ${KIBANA_URL}/app/dashboards"
echo "  Dashboard: 'Threat Hunting - Attack Overview'"
echo ""
echo "  Paneles incluidos:"
echo "    [1] Critical Events Count (metrica roja)"
echo "    [2] Endpoints Comprometidos (metrica naranja)"
echo "    [3] Tecnicas MITRE (metrica azul)"
echo "    [4] Risk Level Distribution (pie chart)"
echo "    [5] Attack Timeline (bar chart temporal)"
echo "    [6] Events by Type (donut chart)"
echo "    [7] Events by Endpoint (bar horizontal)"
echo "    [8] MITRE Techniques Table"
echo ""
echo "  Auto-refresh: cada 5 segundos"
echo "  Rango: Last 2 hours"
echo "=============================================="
