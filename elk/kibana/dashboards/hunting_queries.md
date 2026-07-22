# 🔍 Queries de Threat Hunting para Kibana

## Uso en Kibana Discover

Navega a **Discover** (`http://localhost:5601/app/discover`) y selecciona el index pattern correspondiente.

---

## 1. Detección de Initial Access (T1566)

### Descargas sospechosas
```kql
event_type: "file_download" OR (process.name: "wget" OR process.name: "curl") AND risk_level: "HIGH"
```

### Archivos con doble extensión
```kql
file.path: *.pdf.sh OR file.path: *.doc.exe OR file.path: *.xlsx.sh
```

---

## 2. Detección de Ejecución Maliciosa (T1059)

### Procesos ejecutados desde /tmp
```kql
process.path: /tmp/* AND event_type: "process_start"
```

### Comandos codificados en Base64
```kql
process.cmdline: *base64* OR process.cmdline: *eval* OR process.cmdline: *decode*
```

### Reverse shells
```kql
process.cmdline: */dev/tcp/* OR process.cmdline: *bash -i* OR process.cmdline: *nc -e*
```

---

## 3. Detección de Persistencia (T1053, T1546)

### Modificaciones de crontab
```kql
event_type: "persistence_installed" OR (file.path: */cron* AND event_type: "file_create_or_modify")
```

### Modificaciones de .bashrc
```kql
file.path: *.bashrc AND event_type: "file_create_or_modify"
```

---

## 4. Detección de Movimiento Lateral (T1021)

### Conexiones SSH entre endpoints
```kql
event_type: "lateral_movement" OR (network.remote_port: 22 AND event_type: "network_connection")
```

### Uso de sshpass (fuerza bruta SSH)
```kql
process.name: "sshpass" OR process.cmdline: *sshpass*
```

### Timeline de compromiso
```kql
event_type: "lateral_movement" AND risk_level: "CRITICAL"
```

---

## 5. Detección de Credential Access (T1003)

### Acceso a archivos de credenciales
```kql
event_type: "credential_access" OR file.path: */shadow* OR file.path: *ntds.dit*
```

### Búsqueda de archivos sensibles
```kql
process.cmdline: *find* AND (process.cmdline: *.env* OR process.cmdline: *password* OR process.cmdline: *credential*)
```

---

## 6. Detección de Exfiltración (T1048)

### Transferencia de datos
```kql
event_type: "exfiltration" OR (process.cmdline: *tar czf* AND file.path: */tmp/.exfil*)
```

### Conexiones a IP del atacante
```kql
network.remote_address: "10.10.10.200" OR threat_type: "connection_to_attacker"
```

### Datos codificados para transferencia
```kql
process.cmdline: *base64* AND (file.path: *.tar.gz* OR file.path: *exfil*)
```

---

## 7. Detección de C2 Communication (T1071)

### Beacons periódicos
```kql
network.remote_port: 4444 OR network.remote_port: 4443 OR threat_type: "possible_c2_communication"
```

### Conexiones HTTP sospechosas
```kql
network.remote_port: 8080 AND network.remote_address: "10.10.10.200"
```

---

## 8. Queries Agregadas por Severidad

### Todos los eventos CRITICAL
```kql
risk_level: "CRITICAL" OR severity: "CRITICAL"
```

### Todos los eventos HIGH
```kql
risk_level: "HIGH"
```

### Timeline completa del ataque
```kql
event_type: * AND (risk_level: "HIGH" OR risk_level: "CRITICAL")
```

---

## 9. Queries por Endpoint

### Eventos de un endpoint específico
```kql
endpoint: "WS-FINANZAS-01"
```

### Comparar actividad entre endpoints
```kql
endpoint: "WS-FINANZAS-01" OR endpoint: "WS-RRHH-01"
```

---

## 10. Queries Osquery (para osqueryi interactivo)

```sql
-- Procesos sospechosos ejecutándose ahora
SELECT pid, name, path, cmdline, uid 
FROM processes 
WHERE path LIKE '/tmp/%' OR cmdline LIKE '%nc %' OR cmdline LIKE '%base64%';

-- Conexiones de red activas a IPs externas
SELECT p.name, p.cmdline, ps.remote_address, ps.remote_port 
FROM process_open_sockets ps 
JOIN processes p ON ps.pid = p.pid 
WHERE ps.remote_address NOT IN ('127.0.0.1', '::1', '') 
AND ps.state = 'ESTABLISHED';

-- Archivos recientes en /tmp
SELECT path, size, mtime, uid 
FROM file 
WHERE path LIKE '/tmp/%' 
AND mtime > (strftime('%s','now') - 3600);

-- Crontab entries (persistencia)
SELECT * FROM crontab;

-- Usuarios logueados
SELECT * FROM logged_in_users WHERE host != '';

-- Puertos en escucha (backdoors)
SELECT p.name, p.path, lp.port, lp.protocol 
FROM listening_ports lp 
JOIN processes p ON lp.pid = p.pid 
WHERE lp.port NOT IN (22, 5901, 6901);

-- Archivos SUID (escalación de privilegios)
SELECT path, username, permissions FROM suid_bin;

-- Módulos del kernel sospechosos
SELECT name, path, size FROM kernel_modules 
WHERE name NOT IN ('ext4','overlay','bridge','br_netfilter');
```
