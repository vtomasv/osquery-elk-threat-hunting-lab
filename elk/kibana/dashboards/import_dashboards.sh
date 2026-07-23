#!/bin/bash
###############################################################################
# IMPORT DASHBOARDS - Crea dashboard con visualizaciones embebidas (by-value)
# Usa paneles inline en el dashboard para evitar problemas de migración Lens
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

# ============================================================================
# Crear dashboard con paneles embebidos (by-value) usando la API directa
# Esto evita los problemas de migración de Lens saved objects
# ============================================================================
echo "[*] Creando dashboard con visualizaciones embebidas..."

# Primero obtener el ID del data view threat-hunting-*
DV_ID=$(curl -s "${KIBANA_URL}/api/data_views" -H "kbn-xsrf: true" 2>/dev/null | \
    python3 -c "
import json,sys
try:
    data = json.load(sys.stdin)
    for dv in data.get('data_view', []):
        if 'threat-hunting' in dv.get('title','') or 'threat-hunting' in dv.get('name',''):
            print(dv['id']); break
    else:
        print('')
except: print('')
" 2>/dev/null)

if [ -z "$DV_ID" ]; then
    echo "  [!] No se encontro data view threat-hunting-*, creando uno..."
    DV_ID=$(curl -s -X POST "${KIBANA_URL}/api/data_views/data_view" \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        -d '{"data_view":{"title":"threat-hunting-*","name":"Threat Hunting Events","timeFieldName":"@timestamp"}}' 2>/dev/null | \
        python3 -c "import json,sys; print(json.load(sys.stdin).get('data_view',{}).get('id',''))" 2>/dev/null)
fi
echo "  Data View ID: ${DV_ID}"

# Generar el dashboard con Python
python3 - "$KIBANA_URL" "$DV_ID" << 'PYTHON_SCRIPT'
import json
import sys
import urllib.request

KIBANA_URL = sys.argv[1]
DV_ID = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else "threat-hunting"

def make_lens_metric(title, field, op, filter_query="", color="#6092C0"):
    """Create an inline Lens metric panel config"""
    col = {
        "dataType": "number",
        "isBucketed": False,
        "label": title,
        "operationType": op,
        "scale": "ratio",
        "sourceField": field
    }
    if filter_query:
        col["filter"] = {"language": "kuery", "query": filter_query}
    
    return {
        "attributes": {
            "title": title,
            "visualizationType": "lnsLegacyMetric",
            "state": json.dumps({
                "datasourceStates": {"formBased": {"layers": {"l1": {"columnOrder": ["c1"], "columns": {"c1": col}, "incompleteColumns": {}}}}},
                "filters": [],
                "query": {"language": "kuery", "query": ""},
                "visualization": {"layerId": "l1", "layerType": "data", "accessor": "c1"}
            }),
            "references": [{"id": DV_ID, "name": "indexpattern-datasource-layer-l1", "type": "index-pattern"}]
        }
    }

def make_lens_bar_timeline(title):
    """Create an inline Lens XY bar chart over time"""
    return {
        "attributes": {
            "title": title,
            "visualizationType": "lnsXY",
            "state": json.dumps({
                "datasourceStates": {"formBased": {"layers": {"l1": {
                    "columnOrder": ["x", "y"],
                    "columns": {
                        "x": {"dataType": "date", "isBucketed": True, "label": "@timestamp", "operationType": "date_histogram", "params": {"interval": "auto", "includeEmptyRows": True}, "scale": "interval", "sourceField": "@timestamp"},
                        "y": {"dataType": "number", "isBucketed": False, "label": "Events", "operationType": "count", "scale": "ratio", "sourceField": "___records___"}
                    },
                    "incompleteColumns": {}
                }}}},
                "filters": [],
                "query": {"language": "kuery", "query": ""},
                "visualization": {"preferredSeriesType": "bar_stacked", "layers": [{"layerId": "l1", "layerType": "data", "seriesType": "bar_stacked", "accessors": ["y"], "xAccessor": "x"}], "legend": {"isVisible": True, "position": "right"}, "valueLabels": "hide"}
            }),
            "references": [{"id": DV_ID, "name": "indexpattern-datasource-layer-l1", "type": "index-pattern"}]
        }
    }

def make_lens_pie(title, field, shape="donut"):
    """Create an inline Lens pie/donut chart"""
    return {
        "attributes": {
            "title": title,
            "visualizationType": "lnsPie",
            "state": json.dumps({
                "datasourceStates": {"formBased": {"layers": {"l1": {
                    "columnOrder": ["b", "m"],
                    "columns": {
                        "b": {"dataType": "string", "isBucketed": True, "label": field, "operationType": "terms", "params": {"orderBy": {"columnId": "m", "type": "column"}, "orderDirection": "desc", "size": 10}, "scale": "ordinal", "sourceField": field},
                        "m": {"dataType": "number", "isBucketed": False, "label": "Count", "operationType": "count", "scale": "ratio", "sourceField": "___records___"}
                    },
                    "incompleteColumns": {}
                }}}},
                "filters": [],
                "query": {"language": "kuery", "query": ""},
                "visualization": {"shape": shape, "layers": [{"layerId": "l1", "layerType": "data", "primaryGroups": ["b"], "metrics": ["m"], "categoryDisplay": "default", "legendDisplay": "show", "nestedLegend": False, "numberDisplay": "percent"}]}
            }),
            "references": [{"id": DV_ID, "name": "indexpattern-datasource-layer-l1", "type": "index-pattern"}]
        }
    }

def make_lens_hbar(title, field):
    """Create an inline Lens horizontal bar chart"""
    return {
        "attributes": {
            "title": title,
            "visualizationType": "lnsXY",
            "state": json.dumps({
                "datasourceStates": {"formBased": {"layers": {"l1": {
                    "columnOrder": ["b", "m"],
                    "columns": {
                        "b": {"dataType": "string", "isBucketed": True, "label": field, "operationType": "terms", "params": {"orderBy": {"columnId": "m", "type": "column"}, "orderDirection": "desc", "size": 10}, "scale": "ordinal", "sourceField": field},
                        "m": {"dataType": "number", "isBucketed": False, "label": "Count", "operationType": "count", "scale": "ratio", "sourceField": "___records___"}
                    },
                    "incompleteColumns": {}
                }}}},
                "filters": [],
                "query": {"language": "kuery", "query": ""},
                "visualization": {"preferredSeriesType": "bar_horizontal", "layers": [{"layerId": "l1", "layerType": "data", "seriesType": "bar_horizontal", "accessors": ["m"], "xAccessor": "b"}], "legend": {"isVisible": False}, "valueLabels": "show"}
            }),
            "references": [{"id": DV_ID, "name": "indexpattern-datasource-layer-l1", "type": "index-pattern"}]
        }
    }

def make_lens_table(title, fields):
    """Create an inline Lens datatable"""
    cols = {}
    col_order = []
    for i, f in enumerate(fields):
        cid = f"c{i}"
        col_order.append(cid)
        cols[cid] = {"dataType": "string", "isBucketed": True, "label": f, "operationType": "terms", "params": {"orderBy": {"columnId": "cm", "type": "column"}, "orderDirection": "desc", "size": 20}, "scale": "ordinal", "sourceField": f}
    col_order.append("cm")
    cols["cm"] = {"dataType": "number", "isBucketed": False, "label": "Count", "operationType": "count", "scale": "ratio", "sourceField": "___records___"}
    
    vis_cols = [{"columnId": c, "isTransposed": False} for c in col_order]
    
    return {
        "attributes": {
            "title": title,
            "visualizationType": "lnsDatatable",
            "state": json.dumps({
                "datasourceStates": {"formBased": {"layers": {"l1": {"columnOrder": col_order, "columns": cols, "incompleteColumns": {}}}}},
                "filters": [],
                "query": {"language": "kuery", "query": ""},
                "visualization": {"layerId": "l1", "layerType": "data", "columns": vis_cols}
            }),
            "references": [{"id": DV_ID, "name": "indexpattern-datasource-layer-l1", "type": "index-pattern"}]
        }
    }

# Build panels (by-value, embedded in dashboard)
panels = []

def add_panel(x, y, w, h, panel_type, config):
    idx = f"p{len(panels)}"
    panel = {
        "version": "8.12.0",
        "type": panel_type,
        "gridData": {"x": x, "y": y, "w": w, "h": h, "i": idx},
        "panelIndex": idx,
        "embeddableConfig": config
    }
    panels.append(panel)

# Row 1: Metrics
add_panel(0, 0, 12, 8, "lens", make_lens_metric("Critical Events", "___records___", "count", 'risk_level : "CRITICAL"', "#BD271E"))
add_panel(12, 0, 12, 8, "lens", make_lens_metric("Endpoints Comprometidos", "endpoint", "unique_count", "", "#F5A700"))
add_panel(24, 0, 12, 8, "lens", make_lens_metric("Tecnicas MITRE", "technique", "unique_count", "", "#6092C0"))
add_panel(36, 0, 12, 8, "lens", make_lens_pie("Risk Distribution", "risk_level", "pie"))

# Row 2: Timeline
add_panel(0, 8, 48, 14, "lens", make_lens_bar_timeline("Attack Timeline"))

# Row 3: Charts
add_panel(0, 22, 16, 14, "lens", make_lens_pie("Events by Phase", "event_type", "donut"))
add_panel(16, 22, 16, 14, "lens", make_lens_hbar("Events by Endpoint", "endpoint"))
add_panel(32, 22, 16, 14, "lens", make_lens_hbar("Events by Technique", "technique"))

# Row 4: Table
add_panel(0, 36, 48, 14, "lens", make_lens_table("MITRE ATT&CK Details", ["technique", "tactic", "endpoint"]))

# Create dashboard via API
dashboard_body = {
    "attributes": {
        "title": "Threat Hunting - Attack Overview",
        "description": "Dashboard de monitoreo en tiempo real del ataque APT. Auto-refresh 5s.",
        "panelsJSON": json.dumps(panels),
        "optionsJSON": json.dumps({"useMargins": True, "syncColors": True, "syncCursor": True, "syncTooltips": True, "hidePanelTitles": False}),
        "timeRestore": True,
        "timeFrom": "now-2h",
        "timeTo": "now",
        "refreshInterval": {"pause": False, "value": 5000},
        "kibanaSavedObjectMeta": {
            "searchSourceJSON": json.dumps({"query": {"query": "", "language": "kuery"}, "filter": []})
        }
    }
}

# Use the saved objects API to create/update the dashboard
url = f"{KIBANA_URL}/api/saved_objects/dashboard/threat-hunting-overview"
data = json.dumps(dashboard_body).encode()

req = urllib.request.Request(url, data=data, method="PUT")
req.add_header("kbn-xsrf", "true")
req.add_header("Content-Type", "application/json")

try:
    # Try PUT (update)
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    print(f"[+] Dashboard actualizado: {result.get('id', 'ok')}")
except urllib.error.HTTPError as e:
    if e.code == 404:
        # Try POST (create)
        req2 = urllib.request.Request(f"{KIBANA_URL}/api/saved_objects/dashboard/threat-hunting-overview", data=data, method="POST")
        req2.add_header("kbn-xsrf", "true")
        req2.add_header("Content-Type", "application/json")
        try:
            resp2 = urllib.request.urlopen(req2)
            result2 = json.loads(resp2.read())
            print(f"[+] Dashboard creado: {result2.get('id', 'ok')}")
        except urllib.error.HTTPError as e2:
            body = e2.read().decode()
            print(f"[!] Error creando dashboard: {e2.code}")
            print(body[:500])
    else:
        body = e.read().decode()
        print(f"[!] Error: {e.code}")
        print(body[:500])
except Exception as ex:
    print(f"[!] Exception: {ex}")

PYTHON_SCRIPT

echo ""
echo "=============================================="
echo "  DASHBOARD LISTO"
echo "  Ir a: ${KIBANA_URL}/app/dashboards"
echo "  Abrir: 'Threat Hunting - Attack Overview'"
echo "=============================================="
