#!/bin/bash
###############################################################################
# ATTACKER STARTUP - Inicializa la máquina del adversario
###############################################################################

echo ""
figlet "ATTACKER" 2>/dev/null || echo "=== ATTACKER MACHINE ==="
echo "=============================================="
echo "  APT Simulation - Threat Hunting Lab"
echo "  IP: 10.10.10.200"
echo "=============================================="
echo ""

# Iniciar SSH
mkdir -p /var/run/sshd
/usr/sbin/sshd

# Configurar VNC
mkdir -p /root/.vnc
echo "${VNC_PASSWORD:-attack2024}" | vncpasswd -f > /root/.vnc/passwd
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

# Limpiar locks anteriores
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null

# Iniciar VNC
echo "[+] Iniciando VNC en display :1..."
vncserver :1 -geometry 1280x800 -depth 24 -localhost no 2>/dev/null

# Esperar a que VNC esté listo
sleep 2

# Verificar y reintentar si es necesario
if [ ! -f /tmp/.X1-lock ]; then
    echo "[!] VNC no arrancó, reintentando con Xvnc..."
    Xvnc :1 -geometry 1280x800 -depth 24 -rfbport 5901 -rfbauth /root/.vnc/passwd -pn &
    sleep 2
    DISPLAY=:1 startxfce4 &
fi

# Iniciar noVNC
echo "[+] Iniciando noVNC en puerto 6901..."
/opt/noVNC/utils/websockify/run \
    --web /opt/noVNC \
    6901 localhost:5901 &

# Crear accesos directos en el escritorio
mkdir -p /root/Desktop

cat > /root/Desktop/Terminal.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Terminal Atacante
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
EOF
chmod +x /root/Desktop/Terminal.desktop

cat > /root/Desktop/launch_attack.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=LANZAR ATAQUE COMPLETO
Exec=xfce4-terminal -e "/opt/attack-scripts/full_attack_chain.sh"
Icon=dialog-warning
Terminal=false
EOF
chmod +x /root/Desktop/launch_attack.desktop

# Crear banner de bienvenida
cat > /root/.bashrc << 'BASHRC'
echo ""
echo "=============================================="
echo "  ATTACKER MACHINE - THREAT HUNTING LAB"
echo "=============================================="
echo "  Targets:"
echo "    10.10.10.101 - WS-FINANZAS-01 (Initial Access)"
echo "    10.10.10.102 - WS-RRHH-01 (Lateral Movement)"
echo "    10.10.10.103 - SRV-FILESERVER-01 (Data Exfiltration)"
echo "    10.10.10.104 - WS-DESARROLLO-01 (Credential Theft)"
echo "    10.10.10.105 - DC-CORP-01 (Domain Compromise)"
echo ""
echo "  Scripts:"
echo "    /opt/attack-scripts/full_attack_chain.sh"
echo "    /opt/attack-scripts/phase1_initial_access.sh"
echo "    /opt/attack-scripts/phase2_execution.sh"
echo "    /opt/attack-scripts/phase3_lateral_movement.sh"
echo "    /opt/attack-scripts/phase4_exfiltration.sh"
echo "=============================================="
echo ""
BASHRC

# Iniciar C2 server en background
python3 /opt/attack-scripts/simple_c2_server.py &>/var/log/c2_server.log &

echo "[*] Attacker machine ready"
echo "[*] noVNC available at http://localhost:6901"
echo "[*] C2 server running on :4444 (TCP) and :8080 (HTTP)"

# Mantener vivo
tail -f /dev/null
