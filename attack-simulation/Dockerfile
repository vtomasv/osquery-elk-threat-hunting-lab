###############################################################################
# ATTACKER MACHINE - Simula un adversario APT
# Incluye herramientas ofensivas para demostración educativa
# Compatible con: linux/amd64 y linux/arm64 (Apple Silicon)
###############################################################################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Santiago

RUN apt-get update && apt-get install -y \
    sudo curl wget git vim nano \
    net-tools iputils-ping iproute2 dnsutils traceroute \
    nmap tcpdump \
    openssh-server openssh-client sshpass \
    python3 python3-pip python3-venv \
    xfce4 xfce4-terminal xfce4-goodies dbus-x11 \
    tigervnc-standalone-server tigervnc-common \
    xdg-utils \
    netcat-openbsd socat \
    hydra \
    nikto \
    dirb \
    zip unzip jq htop \
    gcc g++ make \
    cron rsyslog supervisor \
    figlet toilet \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Python offensive tools (compatible con ARM64)
RUN pip3 install --no-cache-dir \
    impacket \
    paramiko \
    requests \
    colorama \
    rich

# noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --depth 1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# SSH
RUN mkdir -p /var/run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# VNC
RUN mkdir -p /root/.vnc && \
    echo '#!/bin/bash\nstartxfce4 &' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Directorios de ataque
RUN mkdir -p /opt/attack-scripts /opt/payloads /opt/lateral-movement /opt/c2 /var/log/supervisor

# Script de inicio
COPY scripts/attacker_startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

# Supervisord
COPY attacker_supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 6901 4444 4443 8080 22

CMD ["/opt/startup.sh"]
