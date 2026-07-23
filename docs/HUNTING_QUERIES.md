# Queries de Cacería de Amenazas — Reconstrucción Completa del Ataque APT

Este documento contiene todas las queries necesarias para detectar, investigar y reconstruir la cadena completa del ataque APT simulado en el laboratorio. Las queries están organizadas por fase MITRE ATT&CK y pueden ejecutarse en **Kibana Discover** (KQL), **Dev Tools** (Elasticsearch DSL) y **Osquery** (desde los endpoints).

---

## Configuración Previa en Kibana

Antes de ejecutar las queries, asegúrate de:

1. **Data View**: Seleccionar `threat-hunting-*` en el selector de Data View (arriba izquierda en Discover)
2. **Rango de tiempo**: Establecer en `Last 2 hours` o `Last 24 hours`
3. **Auto-refresh**: Activar refresh cada 5 segundos para monitoreo en tiempo real

---

## 1. Query Maestra — Visión Completa del Ataque

Esta query devuelve **todos los eventos del ataque** ordenados cronológicamente:

### KQL (Kibana Discover)
```
event_type: *
```

### Elasticsearch DSL (Dev Tools)
```json
GET threat-hunting-*/_search
{
  "size": 100,
  "sort": [{"@timestamp": "asc"}],
  "query": {
    "match_all": {}
  }
}
```

### Resumen por Fase (Aggregation)
```json
GET threat-hunting-*/_search
{
  "size": 0,
  "aggs": {
    "attack_phases": {
      "terms": {
        "field": "event_type",
        "size": 20,
        "order": {"_count": "desc"}
      },
      "aggs": {
        "techniques": {
          "terms": {"field": "technique", "size": 10}
        },
        "endpoints": {
          "terms": {"field": "endpoint", "size": 10}
        },
        "timeline": {
          "min": {"field": "@timestamp"}
        }
      }
    }
  }
}
```

---

## 2. Fase 1 — Initial Access (T1566.002)

Detectar la descarga del archivo malicioso por el usuario.

### KQL
```
event_type: "initial_access"
```

```
technique: "T1566.002"
```

### Elasticsearch DSL
```json
GET threat-hunting-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"event_type": "initial_access"}},
        {"term": {"technique": "T1566.002"}}
      ]
    }
  }
}
```

### Osquery (ejecutar en endpoint WS-FINANZAS-01)
```sql
-- Detectar archivos descargados recientemente en /tmp
SELECT path, filename, size, mtime, atime
FROM file
WHERE directory = '/tmp'
AND filename LIKE '%.sh'
AND mtime > (strftime('%s','now') - 7200);

-- Detectar archivos con doble extensión (técnica de engaño)
SELECT path, filename, size, mtime
FROM file
WHERE directory = '/tmp'
AND (filename LIKE '%.pdf.sh' OR filename LIKE '%.doc.sh' OR filename LIKE '%.xls.sh');

-- Verificar conexiones wget/curl recientes
SELECT pid, name, cmdline, start_time
FROM processes
WHERE name IN ('wget', 'curl')
OR cmdline LIKE '%wget%'
OR cmdline LIKE '%curl%';
```

### Indicadores de Compromiso (IOCs)
| IOC | Valor | Tipo |
|-----|-------|------|
| Archivo malicioso | `factura_pendiente.pdf.sh` | Filename |
| Ruta de descarga | `/tmp/factura_pendiente.pdf.sh` | Path |
| Servidor origen | `http://10.10.10.66/malicious_update.sh` | URL |
| Técnica MITRE | T1566.002 | Spearphishing Link |

---

## 3. Fase 2 — Execution (T1059.004)

Detectar la ejecución del payload y establecimiento del beacon C2.

### KQL
```
event_type: "execution"
```

```
technique: "T1059.004" AND endpoint: "WS-FINANZAS-01"
```

### Elasticsearch DSL
```json
GET threat-hunting-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"event_type": "execution"}},
        {"term": {"endpoint": "WS-FINANZAS-01"}}
      ]
    }
  }
}
```

### Osquery
```sql
-- Detectar procesos ejecutando scripts desde /tmp (altamente sospechoso)
SELECT pid, name, path, cmdline, uid, parent, start_time
FROM processes
WHERE path LIKE '/tmp/%'
OR cmdline LIKE '/tmp/%';

-- Detectar conexiones de red hacia el C2 (10.10.10.200:4444)
SELECT pid, local_address, local_port, remote_address, remote_port, state
FROM process_open_sockets
WHERE remote_address = '10.10.10.200'
AND remote_port = 4444;

-- Detectar procesos con base64 decode (ejecución ofuscada)
SELECT pid, name, cmdline, start_time
FROM processes
WHERE cmdline LIKE '%base64%'
OR cmdline LIKE '%eval%'
OR cmdline LIKE '%/dev/tcp%';

-- Detectar reverse shells
SELECT pid, name, cmdline
FROM processes
WHERE cmdline LIKE '%/dev/tcp%'
OR cmdline LIKE '%bash -i%'
OR cmdline LIKE '%nc -e%'
OR cmdline LIKE '%ncat%';
```

### IOCs
| IOC | Valor | Tipo |
|-----|-------|------|
| C2 Server | `10.10.10.200:4444` | IP:Port |
| Proceso sospechoso | `bash -c 'while true; do echo beacon...'` | Cmdline |
| Técnica | T1059.004 | Unix Shell |

---

## 4. Fase 3 — Persistence (T1053.003, T1546.004)

Detectar mecanismos de persistencia instalados.

### KQL
```
event_type: "persistence"
```

```
technique: "T1053.003" OR technique: "T1546.004"
```

### Elasticsearch DSL
```json
GET threat-hunting-*/_search
{
  "query": {
    "bool": {
      "should": [
        {"term": {"technique": "T1053.003"}},
        {"term": {"technique": "T1546.004"}}
      ],
      "minimum_should_match": 1
    }
  }
}
```

### Osquery
```sql
-- Detectar crontabs sospechosos (persistencia via cron)
SELECT command, path, minute, hour, day_of_month, month, day_of_week
FROM crontab
WHERE command LIKE '%hidden%'
OR command LIKE '%beacon%'
OR command LIKE '%curl%'
OR command LIKE '%wget%'
OR command LIKE '/tmp/%';

-- Detectar modificaciones a .bashrc/.profile (persistencia shell)
SELECT path, mtime, size
FROM file
WHERE (path LIKE '/home/%/.bashrc' OR path LIKE '/home/%/.profile' OR path LIKE '/root/.bashrc')
AND mtime > (strftime('%s','now') - 7200);

-- Contenido sospechoso en .bashrc
SELECT path, size, md5
FROM hash
WHERE path LIKE '/home/%/.bashrc'
OR path LIKE '/root/.bashrc';

-- Detectar archivos ocultos en /tmp (scripts de persistencia)
SELECT path, filename, size, mtime, mode
FROM file
WHERE directory = '/tmp'
AND filename LIKE '.%'
AND mode LIKE '%x%';
```

### IOCs
| IOC | Valor | Tipo |
|-----|-------|------|
| Crontab backdoor | `*/5 * * * * /tmp/.hidden_beacon.sh` | Cron entry |
| Script oculto | `/tmp/.hidden_beacon.sh` | Path |
| Bashrc modificado | `/home/maria.gonzalez/.bashrc` | Path |
| Técnicas | T1053.003, T1546.004 | Cron, Shell Profile |

---

## 5. Fase 4 — Discovery (T1046, T1087)

Detectar actividades de reconocimiento interno.

### KQL
```
event_type: "discovery"
```

```
technique: "T1046" OR technique: "T1087.001"
```

### Elasticsearch DSL
```json
GET threat-hunting-*/_search
{
  "query": {
    "bool": {
      "must": [{"term": {"event_type": "discovery"}}]
    }
  },
  "sort": [{"@timestamp": "asc"}]
}
```

### Osquery
```sql
-- Detectar ejecución de nmap (network scanning)
SELECT pid, name, cmdline, start_time, parent
FROM processes
WHERE name = 'nmap'
OR cmdline LIKE '%nmap%';

-- Detectar escaneo de puertos con netcat
SELECT pid, name, cmdline
FROM processes
WHERE (name = 'nc' OR name = 'ncat' OR name = 'netcat')
AND (cmdline LIKE '%-z%' OR cmdline LIKE '%scan%');

-- Detectar enumeración de usuarios
SELECT pid, name, cmdline
FROM processes
WHERE cmdline LIKE '%/etc/passwd%'
OR cmdline LIKE '%whoami%'
OR cmdline LIKE '%id %'
OR cmdline LIKE '%w %';

-- Detectar archivos de resultados de reconocimiento
SELECT path, filename, size, mtime
FROM file
WHERE directory = '/tmp'
AND (filename LIKE '%scan%' OR filename LIKE '%enum%' OR filename LIKE '%sysinfo%');

-- Verificar conexiones de red salientes (port scanning)
SELECT local_address, local_port, remote_address, remote_port, state, pid
FROM process_open_sockets
WHERE remote_address LIKE '10.10.10.%'
AND state = 'SYN_SENT';
```

### IOCs
| IOC | Valor | Tipo |
|-----|-------|------|
| Herramienta | `nmap -sn 10.10.10.0/24` | Command |
| Archivo resultado | `/tmp/network_scan.txt` | Path |
| Archivo resultado | `/tmp/ssh_targets.txt` | Path |
| Técnicas | T1046, T1087 | Network Discovery, Account Discovery |

---

## 6. Fase 5 — Lateral Movement (T1021.004)

Detectar movimiento lateral SSH entre endpoints.

### KQL
```
event_type: "lateral_movement"
```

```
technique: "T1021.004" AND risk_level: "CRITICAL"
```

### Query para ver todos los endpoints comprometidos
```
event_type: "lateral_movement" AND risk_level: "CRITICAL"
```

### Elasticsearch DSL
```json
GET threat-hunting-*/_search
{
  "query": {
    "term": {"event_type": "lateral_movement"}
  },
  "sort": [{"@timestamp": "asc"}],
  "aggs": {
    "compromised_endpoints": {
      "terms": {"field": "endpoint", "size": 10}
    }
  }
}
```

### Elasticsearch — Mapa de Movimiento Lateral
```json
GET threat-hunting-*/_search
{
  "size": 0,
  "query": {"term": {"event_type": "lateral_movement"}},
  "aggs": {
    "by_endpoint": {
      "terms": {"field": "endpoint", "size": 10},
      "aggs": {
        "first_seen": {"min": {"field": "@timestamp"}},
        "technique_used": {"terms": {"field": "technique"}}
      }
    }
  }
}
```

### Osquery
```sql
-- Detectar conexiones SSH entrantes (movimiento lateral recibido)
SELECT pid, local_address, local_port, remote_address, remote_port, state
FROM process_open_sockets
WHERE local_port = 22
AND state = 'ESTABLISHED'
AND remote_address != '127.0.0.1';

-- Detectar autenticaciones SSH exitosas recientes
SELECT time, message
FROM syslog
WHERE facility = 'auth'
AND message LIKE '%Accepted%'
AND message LIKE '%ssh%'
ORDER BY time DESC
LIMIT 20;

-- Detectar uso de sshpass (fuerza bruta o credenciales robadas)
SELECT pid, name, cmdline, start_time
FROM processes
WHERE name = 'sshpass'
OR cmdline LIKE '%sshpass%';

-- Detectar archivos marcadores de compromiso
SELECT path, filename, mtime
FROM file
WHERE path LIKE '/tmp/.lateral_marker'
OR path LIKE '/tmp/.beacon%';

-- Detectar nuevas claves SSH autorizadas (persistencia post-lateral)
SELECT path, mtime, size
FROM file
WHERE path LIKE '/root/.ssh/authorized_keys'
OR path LIKE '/home/%/.ssh/authorized_keys';
```

### IOCs
| IOC | Valor | Tipo |
|-----|-------|------|
| Origen | WS-FINANZAS-01 (10.10.10.101) | Source |
| Target 1 | WS-RRHH-01 (10.10.10.102) | Destination |
| Target 2 | SRV-FILESERVER-01 (10.10.10.103) | Destination |
| Target 3 | WS-DESARROLLO-01 (10.10.10.104) | Destination |
| Target 4 | DC-CORP-01 (10.10.10.105) | Destination |
| Método | SSH con credenciales (sshpass) | Technique |
| Marcador | `/tmp/.lateral_marker` | File |
| Técnica | T1021.004 | SSH |

---

## 7. Fase 6 — Credential Access (T1003.008, T1552.001, T1003.003)

Detectar robo de credenciales y dumping.

### KQL
```
event_type: "credential_access"
```

```
technique: "T1003.008" OR technique: "T1552.001" OR technique: "T1003.003"
```

### Elasticsearch DSL
```json
GET threat-hunting-*/_search
{
  "query": {
    "term": {"event_type": "credential_access"}
  },
  "sort": [{"@timestamp": "asc"}]
}
```

### Osquery
```sql
-- Detectar acceso a /etc/shadow (credential dumping)
SELECT pid, name, cmdline, start_time
FROM processes
WHERE cmdline LIKE '%/etc/shadow%'
OR cmdline LIKE '%shadow%dump%';

-- Detectar archivos de dump de credenciales
SELECT path, filename, size, mtime
FROM file
WHERE directory = '/tmp'
AND (filename LIKE '%shadow%' OR filename LIKE '%creds%' OR filename LIKE '%dump%'
     OR filename LIKE '%.stolen%' OR filename LIKE '%ntds%');

-- Detectar búsqueda de archivos .env (API keys)
SELECT pid, name, cmdline
FROM processes
WHERE cmdline LIKE '%find%'
AND (cmdline LIKE '%.env%' OR cmdline LIKE '%config%' OR cmdline LIKE '%.conf%');

-- Detectar copia de claves SSH privadas
SELECT pid, name, cmdline
FROM processes
WHERE cmdline LIKE '%id_rsa%'
OR cmdline LIKE '%id_ed25519%'
OR cmdline LIKE '%private%key%';

-- Verificar integridad de /etc/shadow (fue leído recientemente?)
SELECT path, atime, mtime, ctime
FROM file_events
WHERE target_path = '/etc/shadow'
ORDER BY time DESC;
```

### IOCs
| IOC | Valor | Tipo |
|-----|-------|------|
| Shadow dump | `/tmp/.shadow_dump_*` | File pattern |
| Creds robadas | `/tmp/.stolen_creds.txt` | File |
| SSH key robada | `/tmp/.stolen_ssh_key` | File |
| NTDS dump | `/tmp/.ntds_dump` | File |
| Técnicas | T1003.008, T1552.001, T1003.003 | Credential Dumping |

---

## 8. Fase 7 — Collection (T1005, T1074.001)

Detectar recolección y staging de datos sensibles.

### KQL
```
event_type: "collection"
```

```
technique: "T1005" OR technique: "T1074.001"
```

### Elasticsearch DSL
```json
GET threat-hunting-*/_search
{
  "query": {
    "term": {"event_type": "collection"}
  }
}
```

### Osquery
```sql
-- Detectar compresión de archivos (staging para exfiltración)
SELECT pid, name, cmdline, start_time
FROM processes
WHERE name IN ('tar', 'gzip', 'zip', '7z', 'rar')
OR cmdline LIKE '%tar czf%'
OR cmdline LIKE '%zip -r%';

-- Detectar archivos comprimidos sospechosos en /tmp
SELECT path, filename, size, mtime
FROM file
WHERE directory = '/tmp'
AND (filename LIKE '%.tar.gz' OR filename LIKE '%.zip' OR filename LIKE '%.7z')
AND filename LIKE '%exfil%';

-- Detectar acceso masivo a documentos
SELECT pid, name, cmdline
FROM processes
WHERE cmdline LIKE '%Documents%'
OR cmdline LIKE '%/srv/shares%'
OR cmdline LIKE '%find%' AND cmdline LIKE '%-name%';
```

### IOCs
| IOC | Valor | Tipo |
|-----|-------|------|
| Archivo staging | `/tmp/.exfil_data.tar.gz` | File |
| Archivo staging | `/tmp/.exfil_finanzas.tar.gz` | File |
| Archivo staging | `/tmp/.exfil_rrhh.tar.gz` | File |
| Técnicas | T1005, T1074.001 | Data from Local System, Local Data Staging |

---

## 9. Fase 8 — Exfiltration (T1048.003)

Detectar transferencia de datos al atacante.

### KQL
```
event_type: "exfiltration"
```

```
technique: "T1048.003" AND risk_level: "CRITICAL"
```

### Elasticsearch DSL
```json
GET threat-hunting-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"event_type": "exfiltration"}},
        {"term": {"risk_level": "CRITICAL"}}
      ]
    }
  }
}
```

### Osquery
```sql
-- Detectar transferencias de datos grandes hacia IPs externas
SELECT pid, local_address, local_port, remote_address, remote_port, state
FROM process_open_sockets
WHERE remote_address = '10.10.10.200'
AND remote_port IN (8080, 443, 80, 4444);

-- Detectar uso de curl/wget para POST (exfiltración HTTP)
SELECT pid, name, cmdline, start_time
FROM processes
WHERE (name = 'curl' AND cmdline LIKE '%POST%')
OR (name = 'curl' AND cmdline LIKE '%-d @%')
OR cmdline LIKE '%exfil%';

-- Detectar codificación base64 (ofuscación de datos)
SELECT pid, name, cmdline
FROM processes
WHERE cmdline LIKE '%base64%'
AND (cmdline LIKE '%exfil%' OR cmdline LIKE '%encoded%');

-- Detectar transferencias SCP/SFTP salientes
SELECT pid, name, cmdline
FROM processes
WHERE name IN ('scp', 'sftp', 'rsync')
AND cmdline LIKE '%10.10.10.200%';
```

### IOCs
| IOC | Valor | Tipo |
|-----|-------|------|
| C2 Exfil endpoint | `http://10.10.10.200:8080/exfil` | URL |
| Método | HTTP POST con datos base64 | Technique |
| Archivo encoded | `/tmp/.exfil_encoded.txt` | File |
| Técnica | T1048.003 | Exfiltration Over Unencrypted Protocol |

---

## 10. Fase 9 — Impact (T1486)

Detectar simulación de ransomware.

### KQL
```
event_type: "impact"
```

```
technique: "T1486" AND risk_level: "CRITICAL"
```

### Elasticsearch DSL
```json
GET threat-hunting-*/_search
{
  "query": {
    "term": {"technique": "T1486"}
  }
}
```

### Osquery
```sql
-- Detectar notas de rescate
SELECT path, filename, size, mtime
FROM file
WHERE filename LIKE '%RANSOM%'
OR filename LIKE '%README_DECRYPT%'
OR filename LIKE '%HOW_TO_RECOVER%';

-- Detectar creación masiva de archivos (cifrado simulado)
SELECT target_path, action, time
FROM file_events
WHERE target_path LIKE '/tmp/RANSOM%'
ORDER BY time DESC;
```

### IOCs
| IOC | Valor | Tipo |
|-----|-------|------|
| Nota de rescate | `/tmp/RANSOM_NOTE.txt` | File |
| BTC wallet | `bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh` | Crypto address |
| Técnica | T1486 | Data Encrypted for Impact |

---

## 11. Queries Agregadas — Análisis Forense Post-Incidente

### Línea de Tiempo Completa del Ataque
```json
GET threat-hunting-*/_search
{
  "size": 100,
  "sort": [{"@timestamp": "asc"}],
  "query": {"match_all": {}},
  "_source": ["@timestamp", "event_type", "technique", "tactic", "endpoint", "risk_level", "description"]
}
```

### Conteo de Eventos por Nivel de Riesgo
```json
GET threat-hunting-*/_search
{
  "size": 0,
  "aggs": {
    "by_risk": {
      "terms": {"field": "risk_level"},
      "aggs": {
        "events": {"terms": {"field": "event_type", "size": 20}}
      }
    }
  }
}
```

### Endpoints más Afectados
```json
GET threat-hunting-*/_search
{
  "size": 0,
  "aggs": {
    "by_endpoint": {
      "terms": {"field": "endpoint", "size": 10},
      "aggs": {
        "critical_count": {
          "filter": {"term": {"risk_level": "CRITICAL"}}
        },
        "techniques_used": {
          "terms": {"field": "technique", "size": 10}
        },
        "first_compromise": {
          "min": {"field": "@timestamp"}
        }
      }
    }
  }
}
```

### Matriz MITRE ATT&CK — Técnicas Detectadas
```json
GET threat-hunting-*/_search
{
  "size": 0,
  "aggs": {
    "by_tactic": {
      "terms": {"field": "tactic", "size": 20},
      "aggs": {
        "techniques": {
          "terms": {"field": "technique", "size": 20},
          "aggs": {
            "endpoints": {"terms": {"field": "endpoint"}},
            "count": {"value_count": {"field": "technique"}}
          }
        }
      }
    }
  }
}
```

### Velocidad de Propagación (Tiempo entre Compromiso Inicial y DC)
```json
GET threat-hunting-*/_search
{
  "size": 0,
  "aggs": {
    "first_access": {
      "filter": {"term": {"event_type": "initial_access"}},
      "aggs": {"time": {"min": {"field": "@timestamp"}}}
    },
    "dc_compromised": {
      "filter": {
        "bool": {
          "must": [
            {"term": {"endpoint": "DC-CORP-01"}},
            {"term": {"event_type": "lateral_movement"}}
          ]
        }
      },
      "aggs": {"time": {"min": {"field": "@timestamp"}}}
    }
  }
}
```

---

## 12. Queries de Osquery — Monitoreo Continuo de Endpoints

Estas queries se ejecutan automáticamente cada 30 segundos en todos los endpoints via el pack `threat-hunting.conf`:

```sql
-- Estado de procesos sospechosos (ejecutar manualmente)
SELECT p.pid, p.name, p.path, p.cmdline, p.uid, p.gid,
       p.start_time, u.username,
       h.md5
FROM processes p
LEFT JOIN users u ON p.uid = u.uid
LEFT JOIN hash h ON p.path = h.path
WHERE p.path LIKE '/tmp/%'
OR p.path LIKE '/dev/shm/%'
OR p.cmdline LIKE '%base64%'
OR p.cmdline LIKE '%/dev/tcp%'
OR p.cmdline LIKE '%curl%http%'
ORDER BY p.start_time DESC;

-- Conexiones de red activas sospechosas
SELECT p.name, p.cmdline, s.local_address, s.local_port,
       s.remote_address, s.remote_port, s.state
FROM process_open_sockets s
JOIN processes p ON s.pid = p.pid
WHERE s.remote_address NOT IN ('127.0.0.1', '::1', '0.0.0.0')
AND s.remote_port IN (4444, 8080, 1337, 9001, 5555)
OR s.remote_address = '10.10.10.200';

-- Archivos modificados recientemente en directorios sensibles
SELECT path, filename, size, mtime, uid, gid, mode
FROM file
WHERE (directory = '/tmp' OR directory = '/dev/shm' OR directory = '/var/tmp')
AND mtime > (strftime('%s','now') - 3600)
AND (filename LIKE '.%' OR filename LIKE '%beacon%' OR filename LIKE '%exfil%'
     OR filename LIKE '%shadow%' OR filename LIKE '%RANSOM%')
ORDER BY mtime DESC;

-- Usuarios con login reciente
SELECT uid, username, directory, shell, description
FROM users
WHERE uid >= 1000
OR username = 'root';

-- Módulos del kernel cargados (detectar rootkits)
SELECT name, size, status, used_by
FROM kernel_modules
WHERE status = 'Live'
ORDER BY size DESC;

-- Puertos en escucha (detectar backdoors)
SELECT pid, port, protocol, address, path
FROM listening_ports
WHERE port NOT IN (22, 5901, 6901)
AND address != '127.0.0.1';
```

---

## 13. Queries KQL Rápidas — Cheat Sheet

| Objetivo | Query KQL |
|----------|-----------|
| Todos los eventos críticos | `risk_level: "CRITICAL"` |
| Solo movimiento lateral | `event_type: "lateral_movement"` |
| Solo exfiltración | `event_type: "exfiltration"` |
| Eventos en endpoint específico | `endpoint: "WS-FINANZAS-01"` |
| Técnica específica | `technique: "T1021.004"` |
| Táctica específica | `tactic: "Lateral Movement"` |
| Eventos de las últimas 2 horas | `@timestamp >= now-2h` |
| Buscar por descripción | `description: *shadow*` |
| Múltiples técnicas | `technique: ("T1021.004" OR "T1003.008")` |
| Excluir nivel medio | `risk_level: "CRITICAL" OR risk_level: "HIGH"` |
| Domain Controller comprometido | `endpoint: "DC-CORP-01" AND risk_level: "CRITICAL"` |
| Toda la cadena de un endpoint | `endpoint: "SRV-FILESERVER-01"` |

---

## 14. Flujo de Investigación Recomendado

Para reconstruir el ataque completo de forma forense, sigue este orden:

1. **Identificar el alcance**: `risk_level: "CRITICAL"` → ¿Cuántos eventos críticos hay?
2. **Encontrar el paciente cero**: `event_type: "initial_access"` → ¿Quién fue comprometido primero?
3. **Trazar la ejecución**: `endpoint: "WS-FINANZAS-01" AND event_type: "execution"` → ¿Qué se ejecutó?
4. **Detectar persistencia**: `event_type: "persistence"` → ¿Cómo mantienen acceso?
5. **Mapear el reconocimiento**: `event_type: "discovery"` → ¿Qué descubrieron?
6. **Seguir el movimiento lateral**: `event_type: "lateral_movement"` → ¿A dónde se movieron?
7. **Evaluar el robo de credenciales**: `event_type: "credential_access"` → ¿Qué credenciales robaron?
8. **Identificar datos comprometidos**: `event_type: "collection"` → ¿Qué datos recolectaron?
9. **Confirmar exfiltración**: `event_type: "exfiltration"` → ¿Qué salió de la red?
10. **Evaluar impacto**: `event_type: "impact"` → ¿Qué daño causaron?

---

## 15. Verificar que los Datos Existen

Si las queries no devuelven resultados, ejecuta estas verificaciones:

```bash
# Verificar que el índice tiene documentos
curl -s "http://localhost:9200/threat-hunting-*/_count" | python3 -m json.tool

# Ver los campos disponibles en el índice
curl -s "http://localhost:9200/threat-hunting-*/_mapping" | python3 -m json.tool | head -50

# Verificar un documento de ejemplo
curl -s "http://localhost:9200/threat-hunting-*/_search?size=1" | python3 -m json.tool

# Regenerar datos si es necesario
./elk/scripts/generate_attack_data.sh

# Ejecutar el ataque para generar datos en tiempo real
docker exec -it attacker-machine /opt/attack-scripts/full_attack_chain.sh
```

---

**Autor**: Laboratorio MAR404 — Cacería de Amenazas (Threat Hunter)  
**Universidad Mayor** — Formación Avanzada en Ciberdefensa  
**Versión**: 1.0 — Julio 2026
