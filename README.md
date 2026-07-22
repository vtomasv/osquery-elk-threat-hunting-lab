# Osquery + ELK Threat Hunting Lab

## Taller Completo de Cacería de Amenazas con Monitoreo en Tiempo Real

**Universidad Mayor — MAR404 — Cacería de Amenazas (Threat Hunter)**

---

## Descripción General

Este laboratorio proporciona un entorno completo de **Threat Hunting** basado en contenedores Docker que simula una red corporativa con 5 endpoints monitoreados en tiempo real mediante **Osquery** y el stack **ELK (Elasticsearch, Logstash, Kibana)**. El laboratorio permite ejecutar simulaciones de ataques APT reales y observar cada fase del ataque en los dashboards de Kibana, proporcionando una experiencia educativa inmersiva para analistas SOC y Threat Hunters en formación.

La arquitectura implementa el concepto de **detección basada en comportamiento** (Behavior-Based Detection) documentado por MITRE ATT&CK [1], donde los eventos de telemetría de los endpoints son correlacionados en tiempo real para identificar patrones de actividad maliciosa que corresponden a técnicas, tácticas y procedimientos (TTPs) conocidos de grupos APT.

---

## Arquitectura del Laboratorio

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        RED CORPORATIVA SIMULADA                          │
│                          10.10.10.0/24                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │
│  │ Elasticsearch│  │   Logstash   │  │    Kibana    │                 │
│  │  10.10.10.10 │  │  10.10.10.11 │  │  10.10.10.12 │                 │
│  │   :9200      │  │  :5044/:5045 │  │    :5601     │                 │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘                 │
│         │                  │                                            │
│         └──────────────────┼────────────────────────────────────┐      │
│                            │                                    │      │
│  ┌─────────────────────────┼────────────────────────────────┐   │      │
│  │              ENDPOINTS MONITOREADOS                        │   │      │
│  │                                                           │   │      │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────────────┐   │   │      │
│  │  │ ENDPOINT 1 │ │ ENDPOINT 2 │ │    ENDPOINT 3      │   │   │      │
│  │  │WS-FINANZAS │ │  WS-RRHH   │ │ SRV-FILESERVER     │   │   │      │
│  │  │10.10.10.101│ │10.10.10.102│ │   10.10.10.103     │   │   │      │
│  │  │noVNC :6901 │ │noVNC :6902 │ │   noVNC :6903      │   │   │      │
│  │  └────────────┘ └────────────┘ └────────────────────┘   │   │      │
│  │                                                           │   │      │
│  │  ┌────────────┐ ┌────────────────────────────────────┐   │   │      │
│  │  │ ENDPOINT 4 │ │         ENDPOINT 5                  │   │   │      │
│  │  │WS-DESARROL │ │        DC-CORP-01                   │   │   │      │
│  │  │10.10.10.104│ │       10.10.10.105                  │   │   │      │
│  │  │noVNC :6904 │ │       noVNC :6905                   │   │   │      │
│  │  └────────────┘ └────────────────────────────────────┘   │   │      │
│  └───────────────────────────────────────────────────────────┘   │      │
│                                                                   │      │
│  ┌────────────────┐  ┌──────────────────────────────────────┐    │      │
│  │   ATTACKER     │  │      MALICIOUS WEB SERVER            │    │      │
│  │  10.10.10.200  │  │       10.10.10.66                    │    │      │
│  │  noVNC :6900   │  │       (evil-downloads.corp)          │    │      │
│  │  C2: :4444     │  │            :8888                     │    │      │
│  └────────────────┘  └──────────────────────────────────────┘    │      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Componentes del Sistema

| Componente | IP | Puerto(s) | Función |
|---|---|---|---|
| Elasticsearch | 10.10.10.10 | 9200, 9300 | Almacenamiento y búsqueda de logs |
| Logstash | 10.10.10.11 | 5044, 5045 | Ingesta y procesamiento de eventos |
| Kibana | 10.10.10.12 | 5601 | Visualización y dashboards |
| WS-FINANZAS-01 | 10.10.10.101 | 6901 (noVNC) | Endpoint inicial del ataque |
| WS-RRHH-01 | 10.10.10.102 | 6902 (noVNC) | Target de movimiento lateral |
| SRV-FILESERVER-01 | 10.10.10.103 | 6903 (noVNC) | Servidor de archivos (exfiltración) |
| WS-DESARROLLO-01 | 10.10.10.104 | 6904 (noVNC) | Workstation desarrollo (credenciales) |
| DC-CORP-01 | 10.10.10.105 | 6905 (noVNC) | Domain Controller (objetivo final) |
| ATTACKER | 10.10.10.200 | 6900 (noVNC) | Máquina del adversario |
| Malicious Web | 10.10.10.66 | 8888 | Servidor de payloads |

---

## Requisitos Previos

El laboratorio requiere los siguientes recursos en la máquina host:

| Requisito | Mínimo | Recomendado |
|---|---|---|
| RAM | 8 GB | 16 GB |
| CPU | 4 cores | 8 cores |
| Disco | 20 GB libres | 40 GB libres |
| Docker | 24.0+ | Última versión |
| Docker Compose | 2.20+ | Última versión |
| Sistema Operativo | Linux/macOS/Windows (WSL2) | Ubuntu 22.04+ |

---

## Instalación y Despliegue

### Paso 1: Clonar el repositorio

```bash
git clone https://github.com/YOUR_USER/osquery-elk-threat-hunting-lab.git
cd osquery-elk-threat-hunting-lab
```

### Paso 2: Configurar el sistema host

En sistemas Linux, es necesario aumentar el límite de memoria virtual para Elasticsearch:

```bash
# Requerido para Elasticsearch
sudo sysctl -w vm.max_map_count=262144

# Para hacerlo permanente:
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

### Paso 3: Construir y levantar el laboratorio

```bash
# Construir todas las imágenes (primera vez, ~10-15 minutos)
docker compose build

# Levantar todo el entorno
docker compose up -d

# Verificar que todos los contenedores están corriendo
docker compose ps
```

### Paso 4: Configurar Kibana (dashboards e index patterns)

Esperar aproximadamente 2 minutos a que Kibana esté completamente iniciado, luego ejecutar:

```bash
# Configurar index patterns y templates
./elk/kibana/dashboards/setup_dashboards.sh
```

### Paso 5: Verificar el despliegue

```bash
# Verificar Elasticsearch
curl http://localhost:9200/_cluster/health?pretty

# Verificar Kibana
curl http://localhost:5601/api/status

# Verificar endpoints (deben responder al ping)
docker exec endpoint1-workstation ping -c 1 10.10.10.12
```

---

## Acceso a los Servicios

### Kibana (Panel de Monitoreo)

Abrir en el navegador: **http://localhost:5601**

Desde aquí se puede acceder a:
- **Discover**: Exploración de logs en tiempo real
- **Dashboard**: Visualizaciones agregadas del ataque
- **Alerts**: Reglas de detección configuradas

### noVNC (Acceso Visual a Endpoints)

Cada endpoint tiene un escritorio XFCE4 accesible via navegador web:

| Endpoint | URL noVNC | Password |
|---|---|---|
| ATTACKER | http://localhost:6900 | attack2024 |
| WS-FINANZAS-01 | http://localhost:6901 | hunter2024 |
| WS-RRHH-01 | http://localhost:6902 | hunter2024 |
| SRV-FILESERVER-01 | http://localhost:6903 | hunter2024 |
| WS-DESARROLLO-01 | http://localhost:6904 | hunter2024 |
| DC-CORP-01 | http://localhost:6905 | hunter2024 |

---

## Escenario de Ataque: Operation Shadow Finance

### Narrativa

Un grupo APT denominado **APT-LABSIM** ha identificado a la empresa CORP como objetivo de alto valor. Mediante reconocimiento OSINT, identificaron a **María González** del departamento de Finanzas como vector de acceso inicial. El atacante envía un email de spearphishing con un enlace a una "factura pendiente" alojada en un sitio web comprometido. Cuando María descarga y ejecuta el archivo, se inicia una cadena de ataque que compromete toda la red corporativa.

### Fases del Ataque (Alineadas con MITRE ATT&CK)

| Fase | Técnica MITRE | Descripción | Endpoint Afectado |
|---|---|---|---|
| 1. Initial Access | T1566.002 | Descarga de payload desde sitio malicioso | WS-FINANZAS-01 |
| 2. Execution | T1059.004 | Ejecución del script malicioso | WS-FINANZAS-01 |
| 3. Persistence | T1053.003, T1546.004 | Crontab + .bashrc backdoor | WS-FINANZAS-01 |
| 4. Discovery | T1046, T1087 | Escaneo de red y enumeración | WS-FINANZAS-01 |
| 5. Lateral Movement | T1021.004 | Propagación SSH a todos los endpoints | Todos |
| 6. Credential Access | T1003.008 | Extracción de /etc/shadow y claves | Todos |
| 7. Collection | T1005, T1074 | Recolección de datos sensibles | Finanzas, RRHH, FileServer |
| 8. Exfiltration | T1048.003 | Transferencia de datos al C2 | Todos |
| 9. Impact | T1486 | Simulación de ransomware (solo marcadores) | Todos |

---

## Ejecución del Ataque

### Opción A: Ataque Completo Automatizado (Recomendado para Demo)

Conectarse a la máquina atacante y ejecutar la cadena completa:

```bash
# Desde el host
docker exec -it attacker-machine bash

# Dentro del contenedor atacante
/opt/attack-scripts/full_attack_chain.sh
```

O directamente desde el host:

```bash
docker exec -it attacker-machine /opt/attack-scripts/full_attack_chain.sh
```

El script ejecuta todas las fases con pausas entre cada una para permitir la observación en Kibana. Tiempo total aproximado: **5 minutos**.

### Opción B: Ejecución por Fases (Recomendado para Aprendizaje)

Ejecutar cada fase individualmente para análisis detallado:

```bash
# Fase 1: Initial Access
docker exec -it attacker-machine /opt/attack-scripts/phase1_initial_access.sh

# Fase 2: Execution + Persistence
docker exec -it attacker-machine /opt/attack-scripts/phase2_execution.sh

# Fase 3: Lateral Movement
docker exec -it attacker-machine /opt/attack-scripts/phase3_lateral_movement.sh

# Fase 4: Credential Access + Exfiltration
docker exec -it attacker-machine /opt/attack-scripts/phase4_exfiltration.sh
```

### Opción C: Simulación Manual via noVNC (Máxima Interacción)

Para la experiencia más realista y educativa:

1. Abrir **http://localhost:6901** (WS-FINANZAS-01) en el navegador
2. Abrir Firefox dentro del escritorio virtual
3. Navegar a **http://10.10.10.66** (sitio malicioso)
4. Descargar el archivo `malicious_update.sh`
5. Abrir una terminal y ejecutar el archivo descargado
6. Observar en Kibana cómo se registran los eventos en tiempo real

---

## Monitoreo y Hunting en Kibana

### Acceso Rápido

Abrir **http://localhost:5601/app/discover** y seleccionar el index pattern `threat-hunting-*`.

### Queries de Hunting Esenciales

**Detectar todo el ataque:**
```kql
risk_level: "CRITICAL" OR risk_level: "HIGH"
```

**Detectar movimiento lateral:**
```kql
event_type: "lateral_movement"
```

**Detectar comunicación C2:**
```kql
network.remote_port: 4444 OR threat_type: "possible_c2_communication"
```

**Detectar exfiltración:**
```kql
event_type: "exfiltration" OR process.cmdline: *base64*
```

**Timeline completa por endpoint:**
```kql
endpoint: "WS-FINANZAS-01" AND risk_level: *
```

Para la lista completa de queries, consultar el archivo `elk/kibana/dashboards/hunting_queries.md`.

---

## Consultas Osquery Interactivas

Conectarse a cualquier endpoint y ejecutar consultas en tiempo real:

```bash
# Conectar a un endpoint
docker exec -it endpoint1-workstation osqueryi

# Dentro de osqueryi:
```

### Queries de Detección

```sql
-- Procesos sospechosos (ejecutados desde /tmp o con comandos peligrosos)
SELECT pid, name, path, cmdline, uid 
FROM processes 
WHERE path LIKE '/tmp/%' 
   OR cmdline LIKE '%nc %' 
   OR cmdline LIKE '%base64%'
   OR cmdline LIKE '%/dev/tcp%';

-- Conexiones de red activas (detectar C2)
SELECT p.name, p.cmdline, ps.remote_address, ps.remote_port 
FROM process_open_sockets ps 
JOIN processes p ON ps.pid = p.pid 
WHERE ps.remote_address NOT IN ('127.0.0.1', '::1', '') 
  AND ps.state = 'ESTABLISHED';

-- Archivos recientes en directorios temporales (payloads)
SELECT path, size, mtime, uid 
FROM file 
WHERE (path LIKE '/tmp/%' OR path LIKE '/dev/shm/%')
  AND mtime > (strftime('%s','now') - 3600);

-- Verificar persistencia en crontab
SELECT * FROM crontab;

-- Detectar movimiento lateral (sesiones SSH)
SELECT * FROM logged_in_users WHERE host != '';

-- Puertos en escucha no autorizados (backdoors)
SELECT p.name, p.path, lp.port, lp.protocol 
FROM listening_ports lp 
JOIN processes p ON lp.pid = p.pid 
WHERE lp.port NOT IN (22, 5901, 6901);
```

---

## Estructura del Repositorio

```
osquery-elk-threat-hunting-lab/
├── docker-compose.yml              # Orquestación de todos los servicios
├── README.md                       # Este archivo
├── elk/
│   ├── elasticsearch/              # Configuración de Elasticsearch
│   ├── logstash/
│   │   ├── config/logstash.yml     # Configuración de Logstash
│   │   └── pipeline/logstash.conf  # Pipeline de procesamiento
│   └── kibana/
│       ├── config/kibana.yml       # Configuración de Kibana
│       └── dashboards/
│           ├── setup_dashboards.sh # Script de configuración
│           └── hunting_queries.md  # Queries de hunting
├── endpoints/
│   ├── Dockerfile.base             # Dockerfile base (referencia)
│   ├── endpoint1/Dockerfile        # WS-FINANZAS-01
│   ├── endpoint2/Dockerfile        # WS-RRHH-01
│   ├── endpoint3/Dockerfile        # SRV-FILESERVER-01
│   ├── endpoint4/Dockerfile        # WS-DESARROLLO-01
│   ├── endpoint5/Dockerfile        # DC-CORP-01
│   ├── scripts/
│   │   ├── startup.sh              # Script de inicio de endpoints
│   │   ├── process_monitor.sh      # Monitor de procesos -> JSON
│   │   ├── network_monitor.sh      # Monitor de red -> JSON
│   │   └── file_monitor.sh         # Monitor de archivos -> JSON
│   ├── supervisord.conf            # Gestión de servicios
│   └── yara/
│       └── malware.yar             # Reglas YARA de detección
├── attack-simulation/
│   ├── Dockerfile                  # Máquina atacante
│   ├── nginx.conf                  # Config del web server malicioso
│   ├── attacker_supervisord.conf   # Supervisord del atacante
│   ├── scripts/
│   │   ├── full_attack_chain.sh    # Ataque completo automatizado
│   │   ├── phase1_initial_access.sh
│   │   ├── phase2_execution.sh
│   │   ├── phase3_lateral_movement.sh
│   │   ├── phase4_exfiltration.sh
│   │   ├── simple_c2_server.py     # Servidor C2 simulado
│   │   ├── attacker_startup.sh     # Inicio del atacante
│   │   └── README_ATTACK.md        # Guía del ataque
│   ├── payloads/
│   │   └── malicious_update.sh     # Payload simulado
│   └── lateral-movement/           # Scripts de movimiento lateral
├── shared/
│   ├── osquery/
│   │   ├── osquery.conf            # Configuración principal Osquery
│   │   ├── osquery.flags           # Flags de Osquery
│   │   └── packs/
│   │       └── threat-hunting.conf # Pack de queries de hunting
│   └── filebeat/
│       └── filebeat.yml            # Configuración de Filebeat
└── docs/
    ├── GUIA_COMPLETA.md            # Guía paso a paso del taller
    └── images/                     # Capturas y diagramas
```

---

## Fundamento Científico y Técnico

### Detección Basada en Comportamiento

El laboratorio implementa los principios de **Behavior-Based Threat Detection** descritos en la investigación de Ussath et al. (2016) [2], donde la detección se basa en identificar secuencias de acciones (comportamientos) en lugar de firmas estáticas. Cada endpoint genera telemetría continua que es correlacionada por el pipeline de Logstash para identificar patrones que coinciden con TTPs documentados en MITRE ATT&CK [1].

### Osquery como Sensor de Endpoint

Osquery, desarrollado originalmente por Facebook (Meta) en 2014 [3], expone el estado del sistema operativo como una base de datos relacional consultable mediante SQL. En este laboratorio, Osquery actúa como el sensor principal de telemetría, ejecutando queries programadas cada 10-30 segundos que detectan cambios en procesos, conexiones de red, archivos y configuraciones del sistema. Según la documentación oficial de Osquery [4], esta aproximación permite una visibilidad granular del endpoint sin la sobrecarga de un agente EDR completo.

### ELK Stack para Correlación de Eventos

El stack ELK (Elasticsearch, Logstash, Kibana) proporciona la capacidad de almacenar, procesar y visualizar grandes volúmenes de eventos de seguridad en tiempo real [5]. Logstash aplica filtros de enriquecimiento que clasifican automáticamente los eventos según su nivel de riesgo y los mapean a técnicas MITRE ATT&CK, permitiendo al analista realizar hunting proactivo mediante queries KQL en Kibana.

### Movimiento Lateral y Cyber Kill Chain

La simulación de ataque sigue el modelo de **Cyber Kill Chain** de Lockheed Martin [6] y el framework **MITRE ATT&CK** [1], implementando una cadena realista que va desde el acceso inicial (spearphishing) hasta el impacto (ransomware simulado), pasando por todas las fases intermedias documentadas en campañas APT reales como APT29 [7] y APT41 [8].

---

## Troubleshooting

### Elasticsearch no arranca

```bash
# Verificar logs
docker logs elk-elasticsearch

# Solución común: aumentar vm.max_map_count
sudo sysctl -w vm.max_map_count=262144
```

### Los endpoints no envían logs a ELK

```bash
# Verificar conectividad desde un endpoint
docker exec endpoint1-workstation curl -s http://logstash:5044

# Verificar Filebeat
docker exec endpoint1-workstation filebeat test output

# Verificar Osquery está generando logs
docker exec endpoint1-workstation ls -la /var/log/osquery/
```

### noVNC no carga

```bash
# Verificar que VNC está corriendo
docker exec endpoint1-workstation pgrep -a Xvnc

# Reiniciar VNC
docker exec endpoint1-workstation vncserver -kill :1
docker exec endpoint1-workstation vncserver :1 -geometry 1280x800 -depth 24
```

### Reiniciar todo el laboratorio

```bash
docker compose down -v
docker compose up -d --build
```

---

## Detener y Limpiar

```bash
# Detener todos los contenedores
docker compose down

# Detener y eliminar volúmenes (datos de Elasticsearch)
docker compose down -v

# Eliminar imágenes construidas
docker compose down -v --rmi all
```

---

## Referencias

[1]: MITRE ATT&CK Framework. https://attack.mitre.org/ — "MITRE ATT&CK: Adversarial Tactics, Techniques, and Common Knowledge"

[2]: Ussath, M., Jaeger, D., Cheng, F., & Meinel, C. (2016). "Advanced Persistent Threats: Behind the Scenes." Annual Conference on Information Science and Systems (CISS).

[3]: Osquery Official Documentation. https://osquery.readthedocs.io/ — "Osquery: SQL powered operating system instrumentation"

[4]: Osquery Schema. https://osquery.io/schema/ — "Osquery Table Schema Reference"

[5]: Elastic Documentation. https://www.elastic.co/guide/index.html — "Elastic Stack Documentation"

[6]: Hutchins, E., Cloppert, M., & Amin, R. (2011). "Intelligence-Driven Computer Network Defense Informed by Analysis of Adversary Campaigns and Intrusion Kill Chains." Lockheed Martin.

[7]: MITRE ATT&CK - APT29. https://attack.mitre.org/groups/G0016/ — "APT29 (Cozy Bear) Techniques"

[8]: MITRE ATT&CK - APT41. https://attack.mitre.org/groups/G0096/ — "APT41 (Double Dragon) Techniques"

---

## Licencia

Este laboratorio es de uso exclusivamente educativo, desarrollado para el curso **MAR404 - Cacería de Amenazas (Threat Hunter)** de la Universidad Mayor. Los scripts de ataque son simulaciones controladas que no contienen código malicioso real.

**Autor**: Curso MAR404 - Ciberdefensa Avanzada  
**Versión**: 1.0.0  
**Fecha**: Julio 2025
