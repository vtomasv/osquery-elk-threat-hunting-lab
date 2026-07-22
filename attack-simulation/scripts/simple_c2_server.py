#!/usr/bin/env python3
"""
###############################################################################
# SIMPLE C2 SERVER - Threat Hunting Lab
# Servidor de Comando y Control simulado para demostración educativa
#
# Funcionalidades:
#   - Recibe beacons de endpoints comprometidos
#   - Registra todas las comunicaciones
#   - Proporciona interfaz web simple para visualizar actividad
#   - Simula distribución de tareas a agentes
#
# ⚠️ SOLO PARA USO EDUCATIVO ⚠️
###############################################################################
"""

import http.server
import json
import datetime
import threading
import socket
import sys
from urllib.parse import urlparse, parse_qs

# Almacenamiento de beacons
beacons = []
exfil_data = []
agents = {}

class C2Handler(http.server.BaseHTTPRequestHandler):
    """Handler para el servidor C2 HTTP"""
    
    def log_message(self, format, *args):
        """Override para logging personalizado"""
        timestamp = datetime.datetime.utcnow().isoformat()
        print(f"[C2] [{timestamp}] {args[0]}")
    
    def do_GET(self):
        """Maneja requests GET (beacons, status, tasks)"""
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        
        if parsed.path == '/beacon':
            # Registrar beacon
            host = params.get('h', ['unknown'])[0]
            timestamp = datetime.datetime.utcnow().isoformat()
            beacon_data = {
                'timestamp': timestamp,
                'host': host,
                'source_ip': self.client_address[0],
                'type': 'beacon'
            }
            beacons.append(beacon_data)
            agents[host] = {
                'last_seen': timestamp,
                'ip': self.client_address[0],
                'status': 'active'
            }
            
            print(f"[C2] 📡 Beacon from {host} ({self.client_address[0]})")
            
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b"OK")
            
        elif parsed.path == '/status':
            # Dashboard de status
            status = {
                'active_agents': len(agents),
                'total_beacons': len(beacons),
                'total_exfil': len(exfil_data),
                'agents': agents,
                'last_10_beacons': beacons[-10:]
            }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(status, indent=2).encode())
            
        elif parsed.path.startswith('/tasks/'):
            # Simular distribución de tareas
            host = parsed.path.split('/')[-1]
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            # No enviar comandos reales, solo ACK
            self.wfile.write(b"# No tasks pending\n")
            
        elif parsed.path == '/alive':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"1")
            
        elif parsed.path == '/':
            # Página principal del C2
            html = """
            <html>
            <head><title>C2 Server - Threat Hunting Lab</title></head>
            <body style="background:#1a1a2e;color:#0f0;font-family:monospace;padding:20px;">
            <h1>🔴 C2 Server - APT Simulation</h1>
            <h2>Active Agents: {agents}</h2>
            <h2>Total Beacons: {beacons}</h2>
            <h2>Exfiltrated Data: {exfil}</h2>
            <hr>
            <h3>Endpoints:</h3>
            <pre>{agent_list}</pre>
            <hr>
            <p>⚠️ EDUCATIONAL USE ONLY - THREAT HUNTING LAB</p>
            <p>API: /status | /beacon?h=hostname | /tasks/hostname</p>
            </body>
            </html>
            """.format(
                agents=len(agents),
                beacons=len(beacons),
                exfil=len(exfil_data),
                agent_list=json.dumps(agents, indent=2)
            )
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(html.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        """Maneja requests POST (exfiltración de datos)"""
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        
        if '/exfil' in self.path:
            timestamp = datetime.datetime.utcnow().isoformat()
            exfil_entry = {
                'timestamp': timestamp,
                'source_ip': self.client_address[0],
                'data_size': content_length,
                'path': self.path
            }
            exfil_data.append(exfil_entry)
            
            print(f"[C2] 📦 EXFILTRATION received from {self.client_address[0]} - Size: {content_length} bytes")
            
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b"DATA_RECEIVED")
        else:
            self.send_response(200)
            self.end_headers()


def tcp_listener(port=4444):
    """Listener TCP para beacons raw (netcat)"""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', port))
    server.listen(5)
    print(f"[C2] 🎯 TCP Listener started on port {port}")
    
    while True:
        try:
            client, addr = server.accept()
            data = client.recv(1024).decode('utf-8', errors='ignore').strip()
            timestamp = datetime.datetime.utcnow().isoformat()
            
            beacon_data = {
                'timestamp': timestamp,
                'source_ip': addr[0],
                'data': data,
                'type': 'tcp_beacon'
            }
            beacons.append(beacon_data)
            
            # Parsear hostname del beacon
            if '|' in data:
                parts = data.split('|')
                host = parts[0]
                agents[host] = {
                    'last_seen': timestamp,
                    'ip': addr[0],
                    'status': 'active',
                    'type': 'tcp'
                }
            
            print(f"[C2] 📡 TCP Beacon from {addr[0]}: {data[:50]}")
            client.close()
        except Exception as e:
            print(f"[C2] Error in TCP listener: {e}")


def main():
    """Iniciar C2 Server"""
    print("=" * 60)
    print("  🔴 C2 SERVER - THREAT HUNTING LAB")
    print("  ⚠️  EDUCATIONAL USE ONLY")
    print("=" * 60)
    print(f"  HTTP Server: http://0.0.0.0:8080")
    print(f"  TCP Listener: 0.0.0.0:4444")
    print(f"  Status API: http://0.0.0.0:8080/status")
    print("=" * 60)
    
    # Iniciar TCP listener en thread separado
    tcp_thread = threading.Thread(target=tcp_listener, args=(4444,), daemon=True)
    tcp_thread.start()
    
    # Iniciar HTTP server
    server = http.server.HTTPServer(('0.0.0.0', 8080), C2Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[C2] Server stopped")
        sys.exit(0)


if __name__ == '__main__':
    main()
