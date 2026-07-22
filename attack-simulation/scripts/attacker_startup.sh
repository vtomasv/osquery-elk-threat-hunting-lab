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
/usr/sbin/sshd

# Configurar VNC
mkdir -p /root/.vnc
echo "${VNC_PASSWORD:-attack2024}" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

# Iniciar VNC
vncserver :1 -geometry 1280x800 -depth 24 -localhost no 2>/dev/null || \
vncserver :1 -geometry 1280x800 -depth 24 2>/dev/null

# Iniciar noVNC
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
Name=🔴 LANZAR ATAQUE COMPLETO
Exec=xfce4-terminal -e "/opt/attack-scripts/full_attack_chain.sh"
Icon=dialog-warning
Terminal=false
EOF
chmod +x /root/Desktop/launch_attack.desktop

cat > /root/Desktop/README.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=📋 Instrucciones del Ataque
Exec=xfce4-terminal -e "cat /opt/attack-scripts/README_ATTACK.md"
Icon=text-x-generic
Terminal=false
EOF
chmod +x /root/Desktop/README.desktop

# Crear banner de bienvenida
cat > /root/.bashrc << 'BASHRC'
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         🔴 ATTACKER MACHINE - THREAT HUNTING LAB 🔴         ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Targets:                                                    ║"
echo "║    10.10.10.101 - WS-FINANZAS-01 (Initial Access)          ║"
echo "║    10.10.10.102 - WS-RRHH-01 (Lateral Movement)            ║"
echo "║    10.10.10.103 - SRV-FILESERVER-01 (Data Exfiltration)     ║"
echo "║    10.10.10.104 - WS-DESARROLLO-01 (Credential Theft)      ║"
echo "║    10.10.10.105 - DC-CORP-01 (Domain Compromise)           ║"
echo "║                                                              ║"
echo "║  Scripts disponibles:                                        ║"
echo "║    /opt/attack-scripts/full_attack_chain.sh                 ║"
echo "║    /opt/attack-scripts/phase1_initial_access.sh             ║"
echo "║    /opt/attack-scripts/phase2_execution.sh                  ║"
echo "║    /opt/attack-scripts/phase3_lateral_movement.sh           ║"
echo "║    /opt/attack-scripts/phase4_exfiltration.sh               ║"
echo "║                                                              ║"
echo "║  C2 Server: /opt/c2/simple_c2.py                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
BASHRC

echo "[*] Attacker machine ready"
echo "[*] noVNC available at http://localhost:6901"

# Mantener vivo
tail -f /dev/null
