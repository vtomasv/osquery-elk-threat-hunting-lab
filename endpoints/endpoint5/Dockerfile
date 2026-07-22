###############################################################################
# ENDPOINT 5 - DC-CORP-01
# Domain Controller simulado (objetivo final del ataque)
# Usuario: admin.domain - Máximo privilegio en la red
###############################################################################
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Santiago

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
    ldap-utils \
    inotify-tools \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone --depth 1 https://github.com/novnc/websockify.git /opt/noVNC/utils/websockify && \
    ln -s /opt/noVNC/vnc.html /opt/noVNC/index.html

RUN curl -fsSL https://pkg.osquery.io/deb/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/osquery-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/osquery-archive-keyring.gpg] https://pkg.osquery.io/deb deb main" > /etc/apt/sources.list.d/osquery.list && \
    apt-get update && apt-get install -y osquery && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/elastic-archive-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" > /etc/apt/sources.list.d/elastic-8.x.list && \
    apt-get update && apt-get install -y filebeat && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    ssh-keygen -A

RUN mkdir -p /var/log/osquery /var/osquery /etc/osquery/packs /etc/osquery/yara \
    /var/log/filebeat /opt/monitoring /var/log/supervisor

COPY scripts/process_monitor.sh /opt/monitoring/process_monitor.sh
COPY scripts/network_monitor.sh /opt/monitoring/network_monitor.sh
COPY scripts/file_monitor.sh /opt/monitoring/file_monitor.sh
COPY scripts/startup.sh /opt/startup.sh
COPY yara/malware.yar /etc/osquery/yara/malware.yar
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /opt/monitoring/*.sh /opt/startup.sh

RUN mkdir -p /root/.vnc && \
    echo '#!/bin/bash\nstartxfce4 &' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Simular datos de Domain Controller
RUN mkdir -p /var/lib/samba/private /etc/krb5kdc && \
    echo "domain_admin:$6$rounds=5000$salt$hash:18000:0:99999:7:::" > /etc/shadow.bak && \
    echo "Kerberos TGT Database - CRITICAL" > /var/lib/samba/private/krb5.keytab && \
    echo "NTDS.dit simulation" > /var/lib/samba/private/ntds.dit && \
    echo "Group Policy Objects" > /etc/krb5kdc/gpo_backup.tar

EXPOSE 6901 22 389 636
CMD ["/opt/startup.sh"]
