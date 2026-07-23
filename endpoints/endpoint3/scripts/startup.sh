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
echo "root:Password123!" | chpasswd
usermod -aG sudo "${ENDPOINT_USER}" 2>/dev/null || true

# ============================================================================
# 2. Configurar SSH para movimiento lateral
# ============================================================================
echo "[+] Configurando SSH..."
mkdir -p /var/run/sshd
/usr/sbin/sshd

# ============================================================================
# 3. Iniciar rsyslog
# ============================================================================
echo "[+] Iniciando rsyslog..."
rsyslogd 2>/dev/null || true

# ============================================================================
# 4. Iniciar Osquery
# ============================================================================
echo "[+] Iniciando Osquery daemon..."
mkdir -p /var/log/osquery /var/osquery /etc/osquery/packs

osqueryd --config_path=/etc/osquery/osquery.conf \
         --logger_path=/var/log/osquery \
         --pidfile=/var/osquery/osquery.pidfile \
         --database_path=/var/osquery/osquery.db \
         --disable_events=false \
         --disable_audit=false \
         --host_identifier=hostname \
         --daemonize=true 2>/dev/null || echo "[!] Osquery failed to start (non-critical)"

# ============================================================================
# 5. Iniciar Filebeat
# ============================================================================
echo "[+] Iniciando Filebeat..."
filebeat -e -c /etc/filebeat/filebeat.yml &>/var/log/filebeat/filebeat.log &

# ============================================================================
# 6. Iniciar monitores de seguridad personalizados
# ============================================================================
echo "[+] Iniciando monitores de seguridad..."
touch /tmp/.file_monitor_marker
/opt/monitoring/process_monitor.sh &>/dev/null &
/opt/monitoring/network_monitor.sh &>/dev/null &
/opt/monitoring/file_monitor.sh &>/dev/null &

# ============================================================================
# 7. Iniciar VNC + noVNC
# ============================================================================
echo "[+] Configurando VNC server..."

# Crear directorio VNC
mkdir -p /root/.vnc

# Configurar password VNC
echo "${VNC_PASSWORD:-hunter2024}" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

# Crear xstartup correcto
cat > /root/.vnc/xstartup << 'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
exec startxfce4
XSTARTUP
chmod +x /root/.vnc/xstartup

# Limpiar locks anteriores si existen
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null

# Iniciar VNC server
echo "[+] Iniciando VNC en display :1..."
vncserver :1 -geometry 1280x800 -depth 24 -localhost no 2>/dev/null

# Esperar a que VNC esté listo
sleep 2

# Verificar que VNC está corriendo
if [ -f /tmp/.X1-lock ]; then
    echo "[✓] VNC server corriendo en display :1 (puerto 5901)"
else
    echo "[!] VNC no arrancó, reintentando..."
    # Reintentar con Xvnc directamente
    Xvnc :1 -geometry 1280x800 -depth 24 -rfbport 5901 -rfbauth /root/.vnc/passwd -pn &
    sleep 2
    # Iniciar XFCE manualmente
    DISPLAY=:1 startxfce4 &
fi

# Iniciar noVNC websocket proxy
echo "[+] Iniciando noVNC en puerto 6901..."
/opt/noVNC/utils/websockify/run \
    --web /opt/noVNC \
    6901 localhost:5901 &

# ============================================================================
# 8. Configurar browser por defecto (midori)
# ============================================================================
echo "[+] Configurando browser por defecto..."
export DISPLAY=:1
mkdir -p /root/.local/share/applications
cat > /root/.local/share/applications/midori.desktop << 'BROWSERDESKTOP'
[Desktop Entry]
Type=Application
Name=Midori Web Browser
Exec=midori %u
Icon=web-browser
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
Terminal=false
Categories=Network;WebBrowser;
BROWSERDESKTOP

xdg-mime default midori.desktop x-scheme-handler/http 2>/dev/null
xdg-mime default midori.desktop x-scheme-handler/https 2>/dev/null
xdg-mime default midori.desktop text/html 2>/dev/null
# También configurar en XFCE settings
mkdir -p /root/.config/xfce4
echo 'WebBrowser=midori' > /root/.config/xfce4/helpers.rc

# ============================================================================
# 9. Configurar desktop
# ============================================================================
echo "[+] Configurando escritorio..."
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
echo "=========================================="
EOF
chmod +x /root/Desktop/endpoint_info.sh

# ============================================================================
# 9. Mantener el contenedor activo
# ============================================================================
echo "[*] =============================================="
echo "[*] Endpoint ${ENDPOINT_NAME} READY"
echo "[*] noVNC: http://localhost:6901"
echo "[*] SSH: port 22"
echo "[*] =============================================="

# Mantener vivo
tail -f /dev/null
