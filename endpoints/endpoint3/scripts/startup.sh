#!/bin/bash
###############################################################################
# STARTUP SCRIPT - ENDPOINT THREAT HUNTING LAB
# Inicializa todos los servicios del endpoint
###############################################################################

echo "[*] =============================================="
echo "[*] THREAT HUNTING LAB - Endpoint Starting"
echo "[*] Hostname: $(hostname)"
echo "[*] Endpoint: ${ENDPOINT_NAME}"
echo "[*] Role: ${ENDPOINT_ROLE}"
echo "[*] User: ${ENDPOINT_USER}"
echo "[*] =============================================="

# ============================================================================
# 1. Configurar usuario simulado
# ============================================================================
echo "[+] Creando usuario simulado: ${ENDPOINT_USER}"
useradd -m -s /bin/bash "${ENDPOINT_USER}" 2>/dev/null || true
echo "${ENDPOINT_USER}:Password123!" | chpasswd
usermod -aG sudo "${ENDPOINT_USER}" 2>/dev/null || true

# Crear estructura de directorios del usuario
mkdir -p "/home/${ENDPOINT_USER}/{Documents,Downloads,Desktop,.ssh}"
chown -R "${ENDPOINT_USER}:${ENDPOINT_USER}" "/home/${ENDPOINT_USER}"

# ============================================================================
# 2. Configurar SSH para movimiento lateral
# ============================================================================
echo "[+] Configurando SSH..."
/usr/sbin/sshd

# Generar claves SSH para el usuario
su - "${ENDPOINT_USER}" -c "ssh-keygen -t rsa -b 2048 -f /home/${ENDPOINT_USER}/.ssh/id_rsa -N '' -q" 2>/dev/null || true

# Configurar known_hosts para la red del lab
for i in 101 102 103 104 105; do
    echo "10.10.10.${i}" >> "/home/${ENDPOINT_USER}/.ssh/known_hosts" 2>/dev/null || true
done

# ============================================================================
# 3. Iniciar rsyslog
# ============================================================================
echo "[+] Iniciando rsyslog..."
rsyslogd

# ============================================================================
# 4. Iniciar auditoría del sistema
# ============================================================================
echo "[+] Configurando auditd..."
cat > /etc/audit/rules.d/threat-hunting.rules << 'EOF'
# Monitorear ejecución de procesos
-a always,exit -F arch=b64 -S execve -k process_exec
# Monitorear acceso a archivos sensibles
-w /etc/passwd -p wa -k identity_file
-w /etc/shadow -p wa -k identity_file
-w /etc/sudoers -p wa -k privilege_escalation
# Monitorear SSH
-w /root/.ssh -p wa -k ssh_access
-w /home -p wa -k user_home
# Monitorear /tmp (payloads)
-w /tmp -p wa -k tmp_activity
-w /dev/shm -p wa -k shm_activity
# Monitorear crontab
-w /etc/crontab -p wa -k persistence
-w /var/spool/cron -p wa -k persistence
# Monitorear conexiones de red
-a always,exit -F arch=b64 -S connect -k network_connect
EOF
auditd -l 2>/dev/null || true

# ============================================================================
# 5. Iniciar Osquery
# ============================================================================
echo "[+] Iniciando Osquery daemon..."
mkdir -p /var/log/osquery /var/osquery
cp /etc/osquery/osquery.conf /etc/osquery/osquery.conf.bak 2>/dev/null || true

# Crear directorio de packs si no existe
mkdir -p /etc/osquery/packs

osqueryd --config_path=/etc/osquery/osquery.conf \
         --logger_path=/var/log/osquery \
         --pidfile=/var/osquery/osquery.pidfile \
         --database_path=/var/osquery/osquery.db \
         --disable_events=false \
         --disable_audit=false \
         --audit_allow_config=true \
         --audit_allow_sockets=true \
         --host_identifier=hostname \
         --daemonize=true

echo "[+] Osquery PID: $(cat /var/osquery/osquery.pidfile 2>/dev/null || echo 'starting...')"

# ============================================================================
# 6. Iniciar Filebeat
# ============================================================================
echo "[+] Iniciando Filebeat..."
filebeat -e -c /etc/filebeat/filebeat.yml &

# ============================================================================
# 7. Iniciar monitores de seguridad personalizados
# ============================================================================
echo "[+] Iniciando monitores de seguridad..."
/opt/monitoring/process_monitor.sh &
/opt/monitoring/network_monitor.sh &
/opt/monitoring/file_monitor.sh &

# ============================================================================
# 8. Iniciar VNC + noVNC
# ============================================================================
echo "[+] Iniciando VNC server..."

# Configurar password VNC
mkdir -p /root/.vnc
echo "${VNC_PASSWORD:-hunter2024}" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

# Iniciar VNC
vncserver :1 -geometry 1280x800 -depth 24 -localhost no 2>/dev/null || \
vncserver :1 -geometry 1280x800 -depth 24 2>/dev/null

# Iniciar noVNC websocket proxy
echo "[+] Iniciando noVNC en puerto 6901..."
/opt/noVNC/utils/websockify/run \
    --web /opt/noVNC \
    --cert="" \
    6901 localhost:5901 &

# ============================================================================
# 9. Configurar desktop personalizado
# ============================================================================
echo "[+] Configurando escritorio..."

# Crear acceso directo en el escritorio
mkdir -p /root/Desktop
cat > /root/Desktop/Terminal.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
EOF
chmod +x /root/Desktop/Terminal.desktop

cat > /root/Desktop/Firefox.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Firefox Browser
Exec=firefox
Icon=firefox
Terminal=false
EOF
chmod +x /root/Desktop/Firefox.desktop

# Crear script de información del endpoint
cat > /root/Desktop/endpoint_info.sh << EOF
#!/bin/bash
echo "=========================================="
echo "  THREAT HUNTING LAB - Endpoint Info"
echo "=========================================="
echo "  Hostname: \$(hostname)"
echo "  Endpoint: ${ENDPOINT_NAME}"
echo "  Role: ${ENDPOINT_ROLE}"
echo "  User: ${ENDPOINT_USER}"
echo "  IP: \$(hostname -I | awk '{print \$1}')"
echo "  OS: \$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "  Osquery: \$(osqueryi --version 2>/dev/null | head -1)"
echo "=========================================="
echo ""
echo "Servicios activos:"
echo "  - Osquery: \$(pgrep osqueryd > /dev/null && echo 'RUNNING' || echo 'STOPPED')"
echo "  - Filebeat: \$(pgrep filebeat > /dev/null && echo 'RUNNING' || echo 'STOPPED')"
echo "  - SSH: \$(pgrep sshd > /dev/null && echo 'RUNNING' || echo 'STOPPED')"
echo "  - Auditd: \$(pgrep auditd > /dev/null && echo 'RUNNING' || echo 'STOPPED')"
echo "=========================================="
EOF
chmod +x /root/Desktop/endpoint_info.sh

# ============================================================================
# 10. Mantener el contenedor activo
# ============================================================================
echo "[*] =============================================="
echo "[*] Endpoint ${ENDPOINT_NAME} READY"
echo "[*] noVNC: http://localhost:6901"
echo "[*] SSH: port 22"
echo "[*] =============================================="

# Mantener vivo
tail -f /var/log/osquery/osqueryd.results.log 2>/dev/null || tail -f /dev/null
