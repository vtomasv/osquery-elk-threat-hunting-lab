#!/bin/bash
###############################################################################
# IMPORT DASHBOARDS - Crea dashboards con visualizaciones REALES en Kibana 8.12
# Usa la API de Saved Objects con formato NDJSON correcto para Lens
#
# Uso: ./import_dashboards.sh [kibana_url]
###############################################################################

KIBANA_URL="${1:-http://localhost:5601}"

echo "=============================================="
echo "  IMPORTANDO DASHBOARDS CON VISUALIZACIONES"
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
# Generar el NDJSON con Python para control preciso del JSON
# ============================================================================
echo "[*] Generando visualizaciones..."

python3 << 'PYTHON_SCRIPT'
import json
import sys

objects = []

# === INDEX PATTERN ===
objects.append({
    "type": "index-pattern",
    "id": "idx-threat-hunting",
    "attributes": {
        "title": "threat-hunting-*",
        "timeFieldName": "@timestamp",
        "name": "Threat Hunting Events"
    },
    "references": [],
    "managed": False
})

# === METRIC 1: Critical Events Count ===
objects.append({
    "type": "lens",
    "id": "vis-critical-count",
    "attributes": {
        "title": "Critical Events Count",
        "description": "Total de eventos criticos",
        "visualizationType": "lnsLegacyMetric",
        "state": {
            "datasourceStates": {
                "formBased": {
                    "layers": {
                        "layer1": {
                            "columnOrder": ["col1"],
                            "columns": {
                                "col1": {
                                    "dataType": "number",
                                    "isBucketed": False,
                                    "label": "Critical Events",
                                    "operationType": "count",
                                    "scale": "ratio",
                                    "sourceField": "___records___",
                                    "filter": {
                                        "language": "kuery",
                                        "query": "risk_level : \"CRITICAL\""
                                    }
                                }
                            },
                            "incompleteColumns": {}
                        }
                    }
                }
            },
            "filters": [],
            "query": {"language": "kuery", "query": ""},
            "visualization": {
                "layerId": "layer1",
                "layerType": "data",
                "accessor": "col1",
                "colorMode": "Labels",
                "palette": {
                    "name": "custom",
                    "type": "palette",
                    "params": {
                        "steps": 3,
                        "stops": [{"color": "#BD271E", "stop": 100}],
                        "continuity": "above",
                        "rangeType": "number"
                    }
                }
            }
        }
    },
    "references": [
        {"id": "idx-threat-hunting", "name": "indexpattern-datasource-layer-layer1", "type": "index-pattern"}
    ],
    "managed": False
})

# === METRIC 2: Endpoints Comprometidos ===
objects.append({
    "type": "lens",
    "id": "vis-endpoints-compromised",
    "attributes": {
        "title": "Endpoints Comprometidos",
        "description": "Endpoints unicos comprometidos",
        "visualizationType": "lnsLegacyMetric",
        "state": {
            "datasourceStates": {
                "formBased": {
                    "layers": {
                        "layer1": {
                            "columnOrder": ["col1"],
                            "columns": {
                                "col1": {
                                    "dataType": "number",
                                    "isBucketed": False,
                                    "label": "Endpoints",
                                    "operationType": "unique_count",
                                    "scale": "ratio",
                                    "sourceField": "endpoint"
                                }
                            },
                            "incompleteColumns": {}
                        }
                    }
                }
            },
            "filters": [],
            "query": {"language": "kuery", "query": "risk_level : \"CRITICAL\""},
            "visualization": {
                "layerId": "layer1",
                "layerType": "data",
                "accessor": "col1",
                "colorMode": "Labels",
                "palette": {
                    "name": "custom",
                    "type": "palette",
                    "params": {
                        "steps": 3,
                        "stops": [{"color": "#F5A700", "stop": 100}],
                        "continuity": "above",
                        "rangeType": "number"
                    }
                }
            }
        }
    },
    "references": [
        {"id": "idx-threat-hunting", "name": "indexpattern-datasource-layer-layer1", "type": "index-pattern"}
    ],
    "managed": False
})

# === METRIC 3: MITRE Techniques ===
objects.append({
    "type": "lens",
    "id": "vis-mitre-count",
    "attributes": {
        "title": "Tecnicas MITRE ATT&CK",
        "description": "Tecnicas unicas detectadas",
        "visualizationType": "lnsLegacyMetric",
        "state": {
            "datasourceStates": {
                "formBased": {
                    "layers": {
                        "layer1": {
                            "columnOrder": ["col1"],
                            "columns": {
                                "col1": {
                                    "dataType": "number",
                                    "isBucketed": False,
                                    "label": "Tecnicas",
                                    "operationType": "unique_count",
                                    "scale": "ratio",
                                    "sourceField": "technique"
                                }
                            },
                            "incompleteColumns": {}
                        }
                    }
                }
            },
            "filters": [],
            "query": {"language": "kuery", "query": ""},
            "visualization": {
                "layerId": "layer1",
                "layerType": "data",
                "accessor": "col1",
                "colorMode": "Labels",
                "palette": {
                    "name": "custom",
                    "type": "palette",
                    "params": {
                        "steps": 3,
                        "stops": [{"color": "#6092C0", "stop": 100}],
                        "continuity": "above",
                        "rangeType": "number"
                    }
                }
            }
        }
    },
    "references": [
        {"id": "idx-threat-hunting", "name": "indexpattern-datasource-layer-layer1", "type": "index-pattern"}
    ],
    "managed": False
})

# === METRIC 4: Total Events ===
objects.append({
    "type": "lens",
    "id": "vis-total-events",
    "attributes": {
        "title": "Total Events",
        "description": "Total de eventos de ataque",
        "visualizationType": "lnsLegacyMetric",
        "state": {
            "datasourceStates": {
                "formBased": {
                    "layers": {
                        "layer1": {
                            "columnOrder": ["col1"],
                            "columns": {
                                "col1": {
                                    "dataType": "number",
                                    "isBucketed": False,
                                    "label": "Total Events",
                                    "operationType": "count",
                                    "scale": "ratio",
                                    "sourceField": "___records___"
                                }
                            },
                            "incompleteColumns": {}
                        }
                    }
                }
            },
            "filters": [],
            "query": {"language": "kuery", "query": ""},
            "visualization": {
                "layerId": "layer1",
                "layerType": "data",
                "accessor": "col1"
            }
        }
    },
    "references": [
        {"id": "idx-threat-hunting", "name": "indexpattern-datasource-layer-layer1", "type": "index-pattern"}
    ],
    "managed": False
})

# === VIS 5: Attack Timeline (XY Bar) ===
objects.append({
    "type": "lens",
    "id": "vis-attack-timeline",
    "attributes": {
        "title": "Attack Timeline",
        "description": "Eventos en el tiempo",
        "visualizationType": "lnsXY",
        "state": {
            "datasourceStates": {
                "formBased": {
                    "layers": {
                        "layer1": {
                            "columnOrder": ["col-date", "col-count"],
                            "columns": {
                                "col-date": {
                                    "dataType": "date",
                                    "isBucketed": True,
                                    "label": "@timestamp",
                                    "operationType": "date_histogram",
                                    "params": {"interval": "auto", "includeEmptyRows": True},
                                    "scale": "interval",
                                    "sourceField": "@timestamp"
                                },
                                "col-count": {
                                    "dataType": "number",
                                    "isBucketed": False,
                                    "label": "Events",
                                    "operationType": "count",
                                    "scale": "ratio",
                                    "sourceField": "___records___"
                                }
                            },
                            "incompleteColumns": {}
                        }
                    }
                }
            },
            "filters": [],
            "query": {"language": "kuery", "query": ""},
            "visualization": {
                "preferredSeriesType": "bar_stacked",
                "layers": [{
                    "layerId": "layer1",
                    "layerType": "data",
                    "seriesType": "bar_stacked",
                    "accessors": ["col-count"],
                    "xAccessor": "col-date",
                    "yConfig": [{"forAccessor": "col-count", "color": "#BD271E"}]
                }],
                "legend": {"isVisible": True, "position": "right"},
                "valueLabels": "hide"
            }
        }
    },
    "references": [
        {"id": "idx-threat-hunting", "name": "indexpattern-datasource-layer-layer1", "type": "index-pattern"}
    ],
    "managed": False
})

# === VIS 6: Events by Type (Pie/Donut) ===
objects.append({
    "type": "lens",
    "id": "vis-events-by-type",
    "attributes": {
        "title": "Events by Attack Phase",
        "description": "Distribucion por tipo de evento",
        "visualizationType": "lnsPie",
        "state": {
            "datasourceStates": {
                "formBased": {
                    "layers": {
                        "layer1": {
                            "columnOrder": ["col-type", "col-count"],
                            "columns": {
                                "col-type": {
                                    "dataType": "string",
                                    "isBucketed": True,
                                    "label": "Event Type",
                                    "operationType": "terms",
                                    "params": {"orderBy": {"columnId": "col-count", "type": "column"}, "orderDirection": "desc", "size": 10},
                                    "scale": "ordinal",
                                    "sourceField": "event_type"
                                },
                                "col-count": {
                                    "dataType": "number",
                                    "isBucketed": False,
                                    "label": "Count",
                                    "operationType": "count",
                                    "scale": "ratio",
                                    "sourceField": "___records___"
                                }
                            },
                            "incompleteColumns": {}
                        }
                    }
                }
            },
            "filters": [],
            "query": {"language": "kuery", "query": ""},
            "visualization": {
                "shape": "donut",
                "layers": [{
                    "layerId": "layer1",
                    "layerType": "data",
                    "primaryGroups": ["col-type"],
                    "metrics": ["col-count"],
                    "categoryDisplay": "default",
                    "legendDisplay": "show",
                    "nestedLegend": False,
                    "numberDisplay": "percent"
                }]
            }
        }
    },
    "references": [
        {"id": "idx-threat-hunting", "name": "indexpattern-datasource-layer-layer1", "type": "index-pattern"}
    ],
    "managed": False
})

# === VIS 7: Events by Endpoint (Horizontal Bar) ===
objects.append({
    "type": "lens",
    "id": "vis-events-by-endpoint",
    "attributes": {
        "title": "Events by Endpoint",
        "description": "Actividad por endpoint",
        "visualizationType": "lnsXY",
        "state": {
            "datasourceStates": {
                "formBased": {
                    "layers": {
                        "layer1": {
                            "columnOrder": ["col-ep", "col-count"],
                            "columns": {
                                "col-ep": {
                                    "dataType": "string",
                                    "isBucketed": True,
                                    "label": "Endpoint",
                                    "operationType": "terms",
                                    "params": {"orderBy": {"columnId": "col-count", "type": "column"}, "orderDirection": "desc", "size": 10},
                                    "scale": "ordinal",
                                    "sourceField": "endpoint"
                                },
                                "col-count": {
                                    "dataType": "number",
                                    "isBucketed": False,
                                    "label": "Events",
                                    "operationType": "count",
                                    "scale": "ratio",
                                    "sourceField": "___records___"
                                }
                            },
                            "incompleteColumns": {}
                        }
                    }
                }
            },
            "filters": [],
            "query": {"language": "kuery", "query": ""},
            "visualization": {
                "preferredSeriesType": "bar_horizontal",
                "layers": [{
                    "layerId": "layer1",
                    "layerType": "data",
                    "seriesType": "bar_horizontal",
                    "accessors": ["col-count"],
                    "xAccessor": "col-ep"
                }],
                "legend": {"isVisible": False, "position": "right"},
                "valueLabels": "show"
            }
        }
    },
    "references": [
        {"id": "idx-threat-hunting", "name": "indexpattern-datasource-layer-layer1", "type": "index-pattern"}
    ],
    "managed": False
})

# === VIS 8: Risk Level (Pie) ===
objects.append({
    "type": "lens",
    "id": "vis-risk-distribution",
    "attributes": {
        "title": "Risk Level Distribution",
        "description": "Distribucion por nivel de riesgo",
        "visualizationType": "lnsPie",
        "state": {
            "datasourceStates": {
                "formBased": {
                    "layers": {
                        "layer1": {
                            "columnOrder": ["col-risk", "col-count"],
                            "columns": {
                                "col-risk": {
                                    "dataType": "string",
                                    "isBucketed": True,
                                    "label": "Risk Level",
                                    "operationType": "terms",
                                    "params": {"orderBy": {"columnId": "col-count", "type": "column"}, "orderDirection": "desc", "size": 5},
                                    "scale": "ordinal",
                                    "sourceField": "risk_level"
                                },
                                "col-count": {
                                    "dataType": "number",
                                    "isBucketed": False,
                                    "label": "Count",
                                    "operationType": "count",
                                    "scale": "ratio",
                                    "sourceField": "___records___"
                                }
                            },
                            "incompleteColumns": {}
                        }
                    }
                }
            },
            "filters": [],
            "query": {"language": "kuery", "query": ""},
            "visualization": {
                "shape": "pie",
                "layers": [{
                    "layerId": "layer1",
                    "layerType": "data",
                    "primaryGroups": ["col-risk"],
                    "metrics": ["col-count"],
                    "categoryDisplay": "default",
                    "legendDisplay": "show",
                    "nestedLegend": False,
                    "numberDisplay": "value"
                }]
            }
        }
    },
    "references": [
        {"id": "idx-threat-hunting", "name": "indexpattern-datasource-layer-layer1", "type": "index-pattern"}
    ],
    "managed": False
})

# === VIS 9: MITRE Table ===
objects.append({
    "type": "lens",
    "id": "vis-mitre-table",
    "attributes": {
        "title": "MITRE ATT&CK Techniques Detected",
        "description": "Tabla de tecnicas",
        "visualizationType": "lnsDatatable",
        "state": {
            "datasourceStates": {
                "formBased": {
                    "layers": {
                        "layer1": {
                            "columnOrder": ["col-tech", "col-tactic", "col-ep", "col-count"],
                            "columns": {
                                "col-tech": {
                                    "dataType": "string",
                                    "isBucketed": True,
                                    "label": "Technique ID",
                                    "operationType": "terms",
                                    "params": {"orderBy": {"columnId": "col-count", "type": "column"}, "orderDirection": "desc", "size": 20},
                                    "scale": "ordinal",
                                    "sourceField": "technique"
                                },
                                "col-tactic": {
                                    "dataType": "string",
                                    "isBucketed": True,
                                    "label": "Tactic",
                                    "operationType": "terms",
                                    "params": {"orderBy": {"columnId": "col-count", "type": "column"}, "orderDirection": "desc", "size": 20},
                                    "scale": "ordinal",
                                    "sourceField": "tactic"
                                },
                                "col-ep": {
                                    "dataType": "string",
                                    "isBucketed": True,
                                    "label": "Endpoint",
                                    "operationType": "terms",
                                    "params": {"orderBy": {"columnId": "col-count", "type": "column"}, "orderDirection": "desc", "size": 20},
                                    "scale": "ordinal",
                                    "sourceField": "endpoint"
                                },
                                "col-count": {
                                    "dataType": "number",
                                    "isBucketed": False,
                                    "label": "Count",
                                    "operationType": "count",
                                    "scale": "ratio",
                                    "sourceField": "___records___"
                                }
                            },
                            "incompleteColumns": {}
                        }
                    }
                }
            },
            "filters": [],
            "query": {"language": "kuery", "query": ""},
            "visualization": {
                "layerId": "layer1",
                "layerType": "data",
                "columns": [
                    {"columnId": "col-tech", "isTransposed": False},
                    {"columnId": "col-tactic", "isTransposed": False},
                    {"columnId": "col-ep", "isTransposed": False},
                    {"columnId": "col-count", "isTransposed": False}
                ]
            }
        }
    },
    "references": [
        {"id": "idx-threat-hunting", "name": "indexpattern-datasource-layer-layer1", "type": "index-pattern"}
    ],
    "managed": False
})

# === DASHBOARD ===
panels = [
    {"version":"8.12.0","type":"lens","gridData":{"x":0,"y":0,"w":12,"h":8,"i":"p1"},"panelIndex":"p1","embeddableConfig":{"enhancements":{}},"panelRefName":"panel_p1"},
    {"version":"8.12.0","type":"lens","gridData":{"x":12,"y":0,"w":12,"h":8,"i":"p2"},"panelIndex":"p2","embeddableConfig":{"enhancements":{}},"panelRefName":"panel_p2"},
    {"version":"8.12.0","type":"lens","gridData":{"x":24,"y":0,"w":12,"h":8,"i":"p3"},"panelIndex":"p3","embeddableConfig":{"enhancements":{}},"panelRefName":"panel_p3"},
    {"version":"8.12.0","type":"lens","gridData":{"x":36,"y":0,"w":12,"h":8,"i":"p4"},"panelIndex":"p4","embeddableConfig":{"enhancements":{}},"panelRefName":"panel_p4"},
    {"version":"8.12.0","type":"lens","gridData":{"x":0,"y":8,"w":48,"h":14,"i":"p5"},"panelIndex":"p5","embeddableConfig":{"enhancements":{}},"panelRefName":"panel_p5"},
    {"version":"8.12.0","type":"lens","gridData":{"x":0,"y":22,"w":16,"h":14,"i":"p6"},"panelIndex":"p6","embeddableConfig":{"enhancements":{}},"panelRefName":"panel_p6"},
    {"version":"8.12.0","type":"lens","gridData":{"x":16,"y":22,"w":16,"h":14,"i":"p7"},"panelIndex":"p7","embeddableConfig":{"enhancements":{}},"panelRefName":"panel_p7"},
    {"version":"8.12.0","type":"lens","gridData":{"x":32,"y":22,"w":16,"h":14,"i":"p8"},"panelIndex":"p8","embeddableConfig":{"enhancements":{}},"panelRefName":"panel_p8"},
    {"version":"8.12.0","type":"lens","gridData":{"x":0,"y":36,"w":48,"h":14,"i":"p9"},"panelIndex":"p9","embeddableConfig":{"enhancements":{}},"panelRefName":"panel_p9"},
]

objects.append({
    "type": "dashboard",
    "id": "threat-hunting-overview",
    "attributes": {
        "title": "Threat Hunting - Attack Overview",
        "description": "Dashboard principal: Monitoreo en tiempo real del ataque APT. Auto-refresh 5s.",
        "hits": 0,
        "kibanaSavedObjectMeta": {
            "searchSourceJSON": json.dumps({"query": {"query": "", "language": "kuery"}, "filter": []})
        },
        "optionsJSON": json.dumps({"useMargins": True, "syncColors": True, "syncCursor": True, "syncTooltips": True, "hidePanelTitles": False}),
        "panelsJSON": json.dumps(panels),
        "refreshInterval": {"pause": False, "value": 5000},
        "timeFrom": "now-2h",
        "timeRestore": True,
        "timeTo": "now",
        "version": 1
    },
    "references": [
        {"id": "vis-critical-count", "name": "panel_p1", "type": "lens"},
        {"id": "vis-endpoints-compromised", "name": "panel_p2", "type": "lens"},
        {"id": "vis-mitre-count", "name": "panel_p3", "type": "lens"},
        {"id": "vis-total-events", "name": "panel_p4", "type": "lens"},
        {"id": "vis-attack-timeline", "name": "panel_p5", "type": "lens"},
        {"id": "vis-events-by-type", "name": "panel_p6", "type": "lens"},
        {"id": "vis-events-by-endpoint", "name": "panel_p7", "type": "lens"},
        {"id": "vis-risk-distribution", "name": "panel_p8", "type": "lens"},
        {"id": "vis-mitre-table", "name": "panel_p9", "type": "lens"},
    ],
    "managed": False
})

# Kibana 8.12 requires 'state' in Lens objects to be a JSON STRING, not an object
for obj in objects:
    if obj.get("type") == "lens" and "state" in obj.get("attributes", {}):
        obj["attributes"]["state"] = json.dumps(obj["attributes"]["state"])

# Write NDJSON
with open("/tmp/full_dashboard.ndjson", "w") as f:
    for obj in objects:
        f.write(json.dumps(obj) + "\n")

print(f"[+] Generated {len(objects)} objects in NDJSON")
PYTHON_SCRIPT

# Importar
echo "[*] Importando en Kibana..."
RESULT=$(curl -s -w "\n%{http_code}" -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
    -H "kbn-xsrf: true" \
    --form file=@/tmp/full_dashboard.ndjson 2>&1)

HTTP_CODE=$(echo "$RESULT" | tail -1)
BODY=$(echo "$RESULT" | sed '$d')

if echo "$BODY" | grep -q '"success":true'; then
    echo "[+] Dashboard importado exitosamente"
    echo "$BODY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'    Objetos importados: {d.get(\"successCount\", 0)}')" 2>/dev/null
else
    echo "[!] HTTP ${HTTP_CODE} - Detalles:"
    echo "$BODY" | python3 -m json.tool 2>/dev/null | head -30 || echo "$BODY" | head -20
fi

rm -f /tmp/full_dashboard.ndjson

echo ""
echo "=============================================="
echo "  DASHBOARD LISTO"
echo "  Ir a: ${KIBANA_URL}/app/dashboards"
echo "  Abrir: 'Threat Hunting - Attack Overview'"
echo "=============================================="
