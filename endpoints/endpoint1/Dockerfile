###############################################################################
# ENDPOINT 1 - WS-FINANZAS-01
# Workstation del departamento de Finanzas
# Usuario: maria.gonzalez - Este es el endpoint INICIAL del ataque
# (El usuario descarga un archivo malicioso desde un sitio web)
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
    firefox \
    zip unzip jq htop strace ltrace lsof file binutils \
    cron rsyslog supervisor \
    netcat-openbsd socat \
    gcc g++ make \
    inotify-tools \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --depth 1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

# Osquery
RUN curl -fsSL https://pkg.osquery.io/deb/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/osquery-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/osquery-archive-keyring.gpg] https://pkg.osquery.io/deb deb main" > /etc/apt/sources.list.d/osquery.list && \
    apt-get update && apt-get install -y osquery && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Filebeat
RUN curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/elastic-archive-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" > /etc/apt/sources.list.d/elastic-8.x.list && \
    apt-get update && apt-get install -y filebeat && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

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
RUN mkdir -p /home/maria.gonzalez/{Documents,Downloads,Desktop,.ssh} && \
    echo "Presupuesto Q4 2024 - CONFIDENCIAL" > /home/maria.gonzalez/Documents/presupuesto_q4.xlsx && \
    echo "Lista de proveedores - NO COMPARTIR" > /home/maria.gonzalez/Documents/proveedores.csv && \
    echo "Claves bancarias - PRIVADO" > /home/maria.gonzalez/Documents/claves_banco.txt

EXPOSE 6901 22

CMD ["/opt/startup.sh"]
