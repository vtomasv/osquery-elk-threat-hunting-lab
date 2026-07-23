#!/bin/bash
###############################################################################
# SEND TO ELK - Función helper para enviar eventos directamente a Elasticsearch
# Se llama desde full_attack_chain.sh para garantizar que los eventos
# aparezcan en el dashboard en tiempo real.
#
# Uso: send_to_elk.sh <event_type> <technique> <tactic> <endpoint> <endpoint_ip> <risk_level> <description> [extra_json]
###############################################################################

ES_URL="http://elasticsearch:9200"
TODAY=$(date +%Y.%m.%d)
NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

EVENT_TYPE="${1:-unknown}"
TECHNIQUE="${2:-}"
TACTIC="${3:-}"
ENDPOINT="${4:-}"
ENDPOINT_IP="${5:-}"
RISK_LEVEL="${6:-HIGH}"
DESCRIPTION="${7:-}"
EXTRA_JSON="${8:-}"

# Construir el documento JSON
DOC='{
  "@timestamp": "'"${NOW}"'",
  "event_type": "'"${EVENT_TYPE}"'",
  "technique": "'"${TECHNIQUE}"'",
  "tactic": "'"${TACTIC}"'",
  "endpoint": "'"${ENDPOINT}"'",
  "endpoint_ip": "'"${ENDPOINT_IP}"'",
  "risk_level": "'"${RISK_LEVEL}"'",
  "description": "'"${DESCRIPTION}"'"
}'

# Si hay JSON extra, mergearlo
if [ -n "$EXTRA_JSON" ]; then
    DOC=$(echo "$DOC" | python3 -c "
import json, sys
doc = json.load(sys.stdin)
extra = json.loads('${EXTRA_JSON}')
doc.update(extra)
print(json.dumps(doc))
" 2>/dev/null || echo "$DOC")
fi

# Enviar a Elasticsearch
curl -s -X POST "${ES_URL}/threat-hunting-${TODAY}/_doc" \
    -H "Content-Type: application/json" \
    -d "${DOC}" > /dev/null 2>&1
