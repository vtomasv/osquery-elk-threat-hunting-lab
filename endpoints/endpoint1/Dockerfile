###############################################################################
# ENDPOINT 1 - WS-FINANZAS-01
# Workstation del departamento de Finanzas
# Usuario: maria.gonzalez - Este es el endpoint INICIAL del ataque
# (El usuario descarga un archivo malicioso desde un sitio web)
#
# Compatible con: linux/amd64 y linux/arm64 (Apple Silicon)
###############################################################################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Santiago

# Paquetes base + desktop + herramientas
RUN apt-get update && apt-get install -y \
    sudo curl wget git vim nano \
    net-tools iputils-ping iproute2 dnsutils traceroute \
    nmap tcpdump \
    openssh-server openssh-client sshpass \
    python3 python3-pip \
    auditd \
    xfce4 xfce4-terminal xfce4-goodies dbus-x11 \
    tigervnc-standalone-server tigervnc-common \
    xdg-utils \
    zip unzip jq htop strace ltrace lsof file binutils \
    cron rsyslog supervisor \
    netcat-openbsd socat \
    gcc g++ make \
    inotify-tools \
    gnupg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --depth 1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# Osquery - Multi-architecture (amd64 + arm64/Apple Silicon)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        curl -fsSL https://pkg.osquery.io/deb/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/osquery-archive-keyring.gpg && \
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/osquery-archive-keyring.gpg] https://pkg.osquery.io/deb deb main" > /etc/apt/sources.list.d/osquery.list && \
        apt-get update && apt-get install -y osquery && \
        apt-get clean && rm -rf /var/lib/apt/lists/*; \
    else \
        curl -fsSL -o /tmp/osquery.deb "https://github.com/osquery/osquery/releases/download/5.18.1/osquery_5.18.1-1.linux_arm64.deb" && \
        dpkg -i /tmp/osquery.deb || (apt-get update && apt-get install -f -y) && \
        rm -f /tmp/osquery.deb && \
        apt-get clean && rm -rf /var/lib/apt/lists/*; \
    fi

# Filebeat - Multi-architecture (amd64 + arm64/Apple Silicon)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        curl -fsSL -o /tmp/filebeat.deb "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.0-amd64.deb"; \
    else \
        curl -fsSL -o /tmp/filebeat.deb "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.0-arm64.deb"; \
    fi && \
    dpkg -i /tmp/filebeat.deb && \
    rm -f /tmp/filebeat.deb

# SSH config
RUN mkdir -p /var/run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    ssh-keygen -A

# Directorios necesarios
RUN mkdir -p /var/log/osquery /var/osquery /etc/osquery/packs /etc/osquery/yara \
    /var/log/filebeat /opt/monitoring /var/log/supervisor

# Copiar scripts y configuraciones
COPY scripts/process_monitor.sh /opt/monitoring/process_monitor.sh
COPY scripts/network_monitor.sh /opt/monitoring/network_monitor.sh
COPY scripts/file_monitor.sh /opt/monitoring/file_monitor.sh
COPY scripts/startup.sh /opt/startup.sh
COPY yara/malware.yar /etc/osquery/yara/malware.yar
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /opt/monitoring/*.sh /opt/startup.sh

# VNC setup
RUN mkdir -p /root/.vnc && \
    echo '#!/bin/bash\nstartxfce4 &' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Crear archivos "señuelo" para simular workstation real
RUN mkdir -p /home/maria.gonzalez/Documents /home/maria.gonzalez/Downloads /home/maria.gonzalez/Desktop /home/maria.gonzalez/.ssh && \
    echo "Presupuesto Q4 2024 - CONFIDENCIAL" > /home/maria.gonzalez/Documents/presupuesto_q4.xlsx && \
    echo "Lista de proveedores - NO COMPARTIR" > /home/maria.gonzalez/Documents/proveedores.csv && \
    echo "Claves bancarias - PRIVADO" > /home/maria.gonzalez/Documents/claves_banco.txt

EXPOSE 6901 22

CMD ["/opt/startup.sh"]
