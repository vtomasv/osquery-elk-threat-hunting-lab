# ==============================================================================
# MAKEFILE - Osquery + ELK Threat Hunting Lab
# ==============================================================================

.PHONY: help build up down restart logs attack clean status

help: ## Mostrar esta ayuda
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║       OSQUERY + ELK THREAT HUNTING LAB - Comandos          ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

build: ## Construir todas las imágenes Docker
	@echo "[*] Construyendo imágenes..."
	docker compose build

up: ## Levantar todo el laboratorio
	@echo "[*] Configurando kernel..."
	@sudo sysctl -w vm.max_map_count=262144 > /dev/null 2>&1 || true
	@echo "[*] Levantando servicios..."
	docker compose up -d
	@echo "[✓] Laboratorio iniciado"
	@echo "    Kibana: http://localhost:5601"
	@echo "    Attacker: http://localhost:6900"

down: ## Detener el laboratorio (preserva datos)
	docker compose down

restart: ## Reiniciar todo el laboratorio
	docker compose restart

logs: ## Ver logs en tiempo real
	docker compose logs -f --tail=50

attack: ## Ejecutar ataque completo
	@echo "[!] Ejecutando cadena de ataque APT..."
	docker exec -it attacker-machine /opt/attack-scripts/full_attack_chain.sh

attack-phase1: ## Ejecutar solo Fase 1 (Initial Access)
	docker exec -it attacker-machine /opt/attack-scripts/phase1_initial_access.sh

attack-phase2: ## Ejecutar solo Fase 2 (Execution)
	docker exec -it attacker-machine /opt/attack-scripts/phase2_execution.sh

attack-phase3: ## Ejecutar solo Fase 3 (Lateral Movement)
	docker exec -it attacker-machine /opt/attack-scripts/phase3_lateral_movement.sh

attack-phase4: ## Ejecutar solo Fase 4 (Exfiltration)
	docker exec -it attacker-machine /opt/attack-scripts/phase4_exfiltration.sh

setup-kibana: ## Configurar dashboards de Kibana
	./elk/kibana/dashboards/setup_dashboards.sh

status: ## Ver estado de todos los contenedores
	docker compose ps

osquery-ep1: ## Conectar a osqueryi en Endpoint 1
	docker exec -it endpoint1-workstation osqueryi

osquery-ep2: ## Conectar a osqueryi en Endpoint 2
	docker exec -it endpoint2-workstation osqueryi

osquery-ep3: ## Conectar a osqueryi en Endpoint 3
	docker exec -it endpoint3-server osqueryi

osquery-ep4: ## Conectar a osqueryi en Endpoint 4
	docker exec -it endpoint4-workstation osqueryi

osquery-ep5: ## Conectar a osqueryi en Endpoint 5
	docker exec -it endpoint5-dc osqueryi

shell-attacker: ## Shell en máquina atacante
	docker exec -it attacker-machine bash

shell-ep1: ## Shell en Endpoint 1
	docker exec -it endpoint1-workstation bash

clean: ## Eliminar todo (contenedores, volúmenes, imágenes)
	@echo "[!] Eliminando todo el laboratorio..."
	docker compose down -v --rmi all
	@echo "[✓] Limpieza completada"
