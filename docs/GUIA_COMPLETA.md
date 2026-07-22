# Guía Completa del Taller: Threat Hunting con Osquery y ELK

## MAR404 — Cacería de Amenazas (Threat Hunter)

---

## Introducción

Esta guía proporciona instrucciones detalladas paso a paso para ejecutar el taller de Threat Hunting. El objetivo es que el estudiante comprenda cómo un ataque APT se desarrolla en una red corporativa y cómo un Threat Hunter puede detectar cada fase utilizando herramientas de monitoreo y análisis de telemetría.

---

## Parte 1: Preparación del Entorno

### 1.1 Verificación de Requisitos

Antes de iniciar, verificar que el sistema host cumple con los requisitos mínimos. Ejecutar los siguientes comandos para confirmar:

```bash
# Verificar Docker
docker --version
# Esperado: Docker version 24.0+ o superior

# Verificar Docker Compose
docker compose version
# Esperado: Docker Compose version v2.20+ o superior

# Verificar RAM disponible (mínimo 8 GB libres)
free -h

# Verificar espacio en disco (mínimo 20 GB)
df -h /
```

### 1.2 Configuración del Kernel

Elasticsearch requiere un valor elevado de `vm.max_map_count` para funcionar correctamente. Este parámetro controla el número máximo de áreas de memoria que un proceso puede mapear, y Elasticsearch necesita al menos 262144 para sus índices basados en Lucene [5]:

```bash
# Aplicar inmediatamente
sudo sysctl -w vm.max_map_count=262144

# Verificar
cat /proc/sys/vm/max_map_count
# Debe mostrar: 262144

# Hacer permanente (sobrevive reinicios)
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 1.3 Clonación y Construcción

```bash
# Clonar el repositorio
git clone https://github.com/YOUR_USER/osquery-elk-threat-hunting-lab.git
cd osquery-elk-threat-hunting-lab

# Construir todas las imágenes Docker
# NOTA: La primera construcción toma 10-15 minutos por la descarga de paquetes
docker compose build --no-cache

# Verificar que las imágenes se crearon correctamente
docker images | grep -E "osquery-elk|endpoint|attacker"
```

### 1.4 Despliegue del Laboratorio

```bash
# Levantar todos los servicios en segundo plano
docker compose up -d

# Monitorear el arranque (esperar ~2 minutos)
docker compose logs -f --tail=20
# Presionar Ctrl+C cuando vea "Kibana is now available"

# Verificar estado de todos los contenedores
docker compose ps
# Todos deben mostrar "Up" o "running"
```

### 1.5 Configuración Inicial de Kibana

Una vez que Kibana está disponible (verificar accediendo a http://localhost:5601):

```bash
# Ejecutar script de configuración de dashboards
chmod +x elk/kibana/dashboards/setup_dashboards.sh
./elk/kibana/dashboards/setup_dashboards.sh
```

Este script crea los index patterns necesarios para que Kibana pueda visualizar los datos:

| Index Pattern | Contenido |
|---|---|
| `osquery-results-*` | Resultados de queries programadas de Osquery |
| `process-events-*` | Eventos de creación/terminación de procesos |
| `network-events-*` | Conexiones de red establecidas/cerradas |
| `syslog-*` | Logs del sistema (auth, syslog) |
| `threat-hunting-*` | Eventos de la simulación de ataque |

---

## Parte 2: Exploración del Entorno

### 2.1 Acceso a Kibana

Abrir el navegador y navegar a **http://localhost:5601**. La interfaz de Kibana presenta varias secciones relevantes:

1. **Discover** (menú lateral izquierdo): Permite explorar logs en tiempo real con queries KQL
2. **Dashboard**: Visualizaciones agregadas
3. **Observability**: Métricas de infraestructura

Para comenzar a explorar, ir a **Discover** y seleccionar el index pattern `threat-hunting-*` en el selector superior izquierdo. Configurar el rango de tiempo a "Last 1 hour".

### 2.2 Acceso a los Endpoints via noVNC

Abrir una nueva pestaña del navegador y acceder a cada endpoint:

**Endpoint 1 (WS-FINANZAS-01):** http://localhost:6901

Al conectar, se mostrará un escritorio XFCE4 que simula una estación de trabajo corporativa. El password de VNC es `hunter2024`. Dentro del escritorio se puede:

- Abrir una terminal (clic derecho en el escritorio o usar el icono)
- Navegar con Firefox
- Ejecutar comandos como lo haría un usuario real

### 2.3 Verificación de Osquery en los Endpoints

Conectarse a un endpoint y verificar que Osquery está funcionando:

```bash
# Desde el host, conectar al endpoint 1
docker exec -it endpoint1-workstation bash

# Verificar que osqueryd está corriendo
pgrep -a osqueryd
# Debe mostrar el proceso del daemon

# Verificar que genera logs
ls -la /var/log/osquery/
# Debe mostrar osqueryd.results.log con tamaño creciente

# Ejecutar una query interactiva
osqueryi "SELECT pid, name, path FROM processes WHERE name = 'osqueryd';"

# Verificar la configuración activa
osqueryi "SELECT * FROM osquery_schedule;"
# Muestra todas las queries programadas y su intervalo
```

### 2.4 Verificación de Filebeat

```bash
# Dentro del endpoint
filebeat test output
# Debe mostrar conexión exitosa a Logstash

# Ver logs de Filebeat
tail -5 /var/log/filebeat/filebeat
```

---

## Parte 3: Ejecución del Ataque (Demo en Vivo)

### 3.1 Preparación para la Observación

Antes de ejecutar el ataque, preparar el entorno de monitoreo:

1. **Ventana 1**: Kibana Discover con index pattern `threat-hunting-*` y auto-refresh cada 5 segundos
2. **Ventana 2**: noVNC del endpoint 1 (http://localhost:6901) — donde ocurre el acceso inicial
3. **Ventana 3**: Terminal con `docker exec -it attacker-machine bash` — para ejecutar el ataque

En Kibana, configurar el auto-refresh:
- Clic en el icono de reloj (esquina superior derecha)
- Seleccionar "5 seconds"
- Esto actualizará la vista automáticamente

### 3.2 Ejecución del Ataque Completo

Desde la terminal del atacante:

```bash
# Conectar a la máquina atacante
docker exec -it attacker-machine bash

# Ejecutar la cadena completa de ataque
/opt/attack-scripts/full_attack_chain.sh
```

El script ejecutará las 9 fases del ataque con pausas entre cada una. Durante cada pausa, observar en Kibana cómo aparecen nuevos eventos.

### 3.3 Observación Fase por Fase

#### Fase 1: Initial Access

**Qué ocurre**: El script simula que `maria.gonzalez` descarga un archivo malicioso desde `http://10.10.10.66/malicious_update.sh` y lo guarda como `factura_pendiente.pdf.sh`.

**Qué buscar en Kibana**:
```kql
event_type: "initial_access" OR process.name: "wget"
```

**Indicadores de Compromiso (IOCs)**:
- Proceso `wget` conectando a IP `10.10.10.66`
- Archivo con doble extensión `.pdf.sh` creado en `/tmp`
- Hash MD5 del archivo descargado

#### Fase 2: Execution + Persistence

**Qué ocurre**: El payload se ejecuta, establece comunicación con el servidor C2 (10.10.10.200:4444), y crea mecanismos de persistencia.

**Qué buscar en Kibana**:
```kql
event_type: "execution" OR network.remote_port: 4444 OR technique: "T1053.003"
```

**IOCs**:
- Proceso ejecutándose desde `/tmp`
- Conexión saliente al puerto 4444
- Nueva entrada en crontab (`*/5 * * * *`)
- Modificación de `.bashrc`

#### Fase 3: Lateral Movement

**Qué ocurre**: Desde WS-FINANZAS-01, el atacante se propaga a los otros 4 endpoints usando SSH con credenciales robadas.

**Qué buscar en Kibana**:
```kql
event_type: "lateral_movement" OR (process.name: "sshpass" AND network.remote_port: 22)
```

**IOCs**:
- Múltiples conexiones SSH salientes desde 10.10.10.101
- Proceso `sshpass` en el endpoint origen
- Archivos `.lateral_marker` creados en `/tmp` de cada víctima
- Nuevos beacons desde IPs 10.10.10.102-105 hacia 10.10.10.200

#### Fase 4: Exfiltration

**Qué ocurre**: Se extraen credenciales (/etc/shadow, claves SSH, archivos .env), se comprimen datos sensibles y se exfiltran al servidor C2.

**Qué buscar en Kibana**:
```kql
event_type: "exfiltration" OR event_type: "credential_access" OR technique: "T1003*"
```

**IOCs**:
- Acceso a `/etc/shadow` en múltiples endpoints
- Comandos `tar czf` creando archivos en `/tmp`
- Transferencias HTTP POST a 10.10.10.200:8080
- Datos codificados en base64

---

## Parte 4: Hunting Proactivo (Ejercicio del Estudiante)

### 4.1 Ejercicio: Reconstruir la Timeline del Ataque

Usando Kibana Discover, el estudiante debe reconstruir la timeline completa del ataque respondiendo las siguientes preguntas:

1. **¿Cuál fue el primer evento sospechoso?** (timestamp exacto)
2. **¿Qué usuario fue el vector de acceso inicial?**
3. **¿Cuánto tiempo pasó entre el acceso inicial y el primer movimiento lateral?**
4. **¿En qué orden fueron comprometidos los endpoints?**
5. **¿Qué datos fueron exfiltrados y hacia dónde?**

**Query para la timeline completa:**
```kql
(risk_level: "HIGH" OR risk_level: "CRITICAL") AND event_type: *
```

Ordenar por `@timestamp` ascendente para ver la secuencia cronológica.

### 4.2 Ejercicio: Identificar IOCs con Osquery

Conectarse a cada endpoint y ejecutar queries para encontrar evidencia del compromiso:

```bash
# Conectar al endpoint 1
docker exec -it endpoint1-workstation osqueryi

# Query 1: Encontrar procesos sospechosos
SELECT pid, name, path, cmdline, uid 
FROM processes 
WHERE path LIKE '/tmp/%' 
   OR cmdline LIKE '%nc %' 
   OR cmdline LIKE '%base64%';

# Query 2: Encontrar conexiones C2
SELECT p.name, ps.remote_address, ps.remote_port, ps.state
FROM process_open_sockets ps 
JOIN processes p ON ps.pid = p.pid 
WHERE ps.remote_port IN (4444, 4443, 8080)
  AND ps.state = 'ESTABLISHED';

# Query 3: Verificar persistencia
SELECT * FROM crontab WHERE command LIKE '%hidden%' OR command LIKE '%beacon%';

# Query 4: Archivos sospechosos en /tmp
SELECT path, size, mtime, uid 
FROM file 
WHERE path LIKE '/tmp/.%'
  AND size > 0;

# Query 5: Usuarios con sesiones activas (movimiento lateral)
SELECT * FROM logged_in_users WHERE host != '' AND host != '::1';
```

### 4.3 Ejercicio: Crear Reglas de Detección

Basándose en los IOCs encontrados, el estudiante debe proponer reglas de detección. Ejemplo de regla Sigma:

```yaml
title: Detección de Movimiento Lateral via SSH desde Endpoint Comprometido
id: a1b2c3d4-e5f6-7890-abcd-ef1234567890
status: experimental
description: Detecta conexiones SSH salientes desde workstations que normalmente no inician conexiones SSH
author: Estudiante MAR404
date: 2025/07/22
references:
    - https://attack.mitre.org/techniques/T1021/004/
logsource:
    category: network_connection
    product: osquery
detection:
    selection:
        remote_port: 22
        state: 'ESTABLISHED'
    filter:
        source_hostname|startswith: 'SRV-'
    condition: selection and not filter
falsepositives:
    - Administradores realizando mantenimiento remoto
level: high
tags:
    - attack.lateral_movement
    - attack.t1021.004
```

---

## Parte 5: Análisis Post-Incidente

### 5.1 Generación de Reporte de Incidente

Después de completar el hunting, el estudiante debe generar un reporte que incluya:

1. **Resumen Ejecutivo**: Descripción del incidente en lenguaje no técnico
2. **Timeline de Eventos**: Secuencia cronológica con timestamps
3. **Endpoints Afectados**: Lista con nivel de compromiso
4. **IOCs Identificados**: Hashes, IPs, dominios, archivos
5. **Técnicas MITRE ATT&CK**: Mapeo completo
6. **Recomendaciones**: Acciones de contención y remediación

### 5.2 Mapeo MITRE ATT&CK Navigator

El estudiante puede usar MITRE ATT&CK Navigator (https://mitre-attack.github.io/attack-navigator/) para crear un mapa visual de las técnicas utilizadas en el ataque:

| Táctica | Técnica | Sub-técnica | Detectada |
|---|---|---|---|
| Initial Access | T1566 | .002 Spearphishing Link | Sí |
| Execution | T1059 | .004 Unix Shell | Sí |
| Persistence | T1053 | .003 Cron | Sí |
| Persistence | T1546 | .004 Unix Shell Config | Sí |
| Discovery | T1046 | Network Service Discovery | Sí |
| Discovery | T1087 | Account Discovery | Sí |
| Lateral Movement | T1021 | .004 SSH | Sí |
| Credential Access | T1003 | .008 /etc/shadow | Sí |
| Collection | T1005 | Data from Local System | Sí |
| Collection | T1074 | .001 Local Data Staging | Sí |
| Exfiltration | T1048 | .003 Over Unencrypted Protocol | Sí |
| Impact | T1486 | Data Encrypted for Impact | Sí (simulado) |

---

## Parte 6: Limpieza y Restauración

### 6.1 Detener el Laboratorio

```bash
# Detener todos los contenedores (preserva datos)
docker compose stop

# Para reanudar después:
docker compose start
```

### 6.2 Reinicio Completo (borrar todo)

```bash
# Eliminar contenedores, redes y volúmenes
docker compose down -v

# Eliminar imágenes construidas
docker compose down -v --rmi all

# Reconstruir desde cero
docker compose build --no-cache
docker compose up -d
```

---

## Referencias Bibliográficas

[1] MITRE Corporation. "ATT&CK: Adversarial Tactics, Techniques, and Common Knowledge." https://attack.mitre.org/

[2] Ussath, M., Jaeger, D., Cheng, F., & Meinel, C. (2016). "Advanced Persistent Threats: Behind the Scenes." Annual Conference on Information Science and Systems.

[3] Facebook/Meta. "Osquery: SQL powered operating system instrumentation, monitoring, and analytics." https://osquery.io/

[4] Elastic. "Elastic Stack Documentation." https://www.elastic.co/guide/

[5] Hutchins, E., Cloppert, M., & Amin, R. (2011). "Intelligence-Driven Computer Network Defense Informed by Analysis of Adversary Campaigns and Intrusion Kill Chains." Lockheed Martin.

[6] Sqrrl (now Amazon). "A Framework for Cyber Threat Hunting." https://www.threathunting.net/

[7] Lee, R. & Lee, R. (2023). "The Threat Hunting Reference Model." SANS Institute.

[8] Bianco, D. (2013). "The Pyramid of Pain." https://detect-respond.blogspot.com/2013/03/the-pyramid-of-pain.html
