#!/bin/bash
###############################################################################
# QUICK START - Threat Hunting Lab
# Script de despliegue rápido del laboratorio completo
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       OSQUERY + ELK THREAT HUNTING LAB - Quick Start       ║"
echo "║       MAR404 - Cacería de Amenazas (Threat Hunter)         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 1. Verificar Docker
echo -e "${YELLOW}[1/6] Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}ERROR: Docker no está instalado. Instálalo primero.${NC}"
    exit 1
fi
if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}ERROR: Docker Compose no está disponible.${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Docker $(docker --version | cut -d' ' -f3) detectado${NC}"

# 2. Configurar kernel
echo -e "${YELLOW}[2/6] Configurando parámetros del kernel...${NC}"
current_map_count=$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo "0")
if [ "$current_map_count" -lt 262144 ]; then
    echo "  Aumentando vm.max_map_count a 262144..."
    sudo sysctl -w vm.max_map_count=262144 > /dev/null 2>&1 || true
fi
echo -e "${GREEN}[✓] vm.max_map_count configurado${NC}"

# 3. Construir imágenes
echo -e "${YELLOW}[3/6] Construyendo imágenes Docker (esto puede tomar 10-15 min)...${NC}"
docker compose build
echo -e "${GREEN}[✓] Imágenes construidas exitosamente${NC}"

# 4. Levantar servicios
echo -e "${YELLOW}[4/6] Levantando servicios...${NC}"
docker compose up -d
echo -e "${GREEN}[✓] Todos los servicios iniciados${NC}"

# 5. Esperar a que ELK esté listo
echo -e "${YELLOW}[5/6] Esperando a que ELK Stack esté listo...${NC}"
echo "  Esperando Elasticsearch..."
until curl -s http://localhost:9200/_cluster/health 2>/dev/null | grep -q '"status"'; do
    sleep 5
    echo -n "."
done
echo ""
echo "  Esperando Kibana..."
until curl -s http://localhost:5601/api/status 2>/dev/null | grep -q 'available'; do
    sleep 5
    echo -n "."
done
echo ""
echo -e "${GREEN}[✓] ELK Stack listo${NC}"

# 6. Configurar dashboards
echo -e "${YELLOW}[6/6] Configurando dashboards de Kibana...${NC}"
sleep 10
./elk/kibana/dashboards/setup_dashboards.sh
echo -e "${GREEN}[✓] Dashboards configurados${NC}"

# Resumen final
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ LABORATORIO DESPLEGADO CON ÉXITO            ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  Servicios disponibles:                                      ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  📊 Kibana:          http://localhost:5601                   ║${NC}"
echo -e "${GREEN}║  🔴 Attacker noVNC:  http://localhost:6900  (pass:attack2024)║${NC}"
echo -e "${GREEN}║  💻 Endpoint 1:      http://localhost:6901  (pass:hunter2024)║${NC}"
echo -e "${GREEN}║  💻 Endpoint 2:      http://localhost:6902  (pass:hunter2024)║${NC}"
echo -e "${GREEN}║  💻 Endpoint 3:      http://localhost:6903  (pass:hunter2024)║${NC}"
echo -e "${GREEN}║  💻 Endpoint 4:      http://localhost:6904  (pass:hunter2024)║${NC}"
echo -e "${GREEN}║  💻 Endpoint 5:      http://localhost:6905  (pass:hunter2024)║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  Para ejecutar el ataque:                                    ║${NC}"
echo -e "${GREEN}║  docker exec -it attacker-machine \\                         ║${NC}"
echo -e "${GREEN}║    /opt/attack-scripts/full_attack_chain.sh                  ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Siguiente paso: Abre Kibana y luego ejecuta el ataque.${NC}"
