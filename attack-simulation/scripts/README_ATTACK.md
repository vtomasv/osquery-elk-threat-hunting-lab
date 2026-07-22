# 🔴 GUÍA DE ATAQUE - APT SIMULATION

## Escenario: Operation Shadow Finance

Un grupo APT ha identificado a la empresa CORP como objetivo. El vector de ataque
inicial es un email de spearphishing dirigido a una empleada de Finanzas.

## Cadena de Ataque (Cyber Kill Chain)

```
1. RECONNAISSANCE    → Identificación de empleados (LinkedIn/OSINT)
2. WEAPONIZATION     → Creación de payload (factura_pendiente.pdf.sh)
3. DELIVERY          → Email con link a sitio malicioso
4. EXPLOITATION      → Usuario descarga y ejecuta el archivo
5. INSTALLATION      → Persistencia via crontab + .bashrc
6. C2                → Comunicación con servidor 10.10.10.200
7. ACTIONS           → Movimiento lateral + Exfiltración
```

## Scripts Disponibles

| Script | Descripción | MITRE ATT&CK |
|--------|-------------|--------------|
| `full_attack_chain.sh` | Cadena completa (5 min) | Todas las fases |
| `phase1_initial_access.sh` | Solo descarga inicial | T1566.002 |
| `phase2_execution.sh` | Ejecución + Persistencia | T1059.004, T1053.003 |
| `phase3_lateral_movement.sh` | Movimiento lateral | T1021.004 |
| `phase4_exfiltration.sh` | Robo + Exfiltración | T1003, T1048 |

## Ejecución

```bash
# Ataque completo (recomendado para demo)
/opt/attack-scripts/full_attack_chain.sh

# O por fases individuales:
/opt/attack-scripts/phase1_initial_access.sh
/opt/attack-scripts/phase2_execution.sh
/opt/attack-scripts/phase3_lateral_movement.sh
/opt/attack-scripts/phase4_exfiltration.sh
```

## Monitoreo en ELK

Abre Kibana en http://localhost:5601 y observa los dashboards de:
- Osquery Results
- Process Events
- Network Events
- Attack Simulation Timeline

## ⚠️ DISCLAIMER

Este laboratorio es EXCLUSIVAMENTE para uso educativo en el contexto del
curso MAR404 - Cacería de Amenazas (Threat Hunter).
