extends Node

const PORT = 9080

var _tcp_server = TCPServer.new()
var _peers: Dictionary[int, WebSocketPeer] = {}
var last_peer_id := 1

# Aquí guardamos el estado de cada jugador
var players: Dictionary[int, Dictionary] = {}

func _ready():
	var err = _tcp_server.listen(PORT)
	if err == OK:
		print("Server started on port %d." % PORT)
	else:
		push_error("Unable to start server.")
		set_process(false)

func _process(_delta):
	_accept_new_peers()
	_poll_peers()

# ------------------------------
# --- FUNCIONES AUXILIARES -----
# ------------------------------

func _accept_new_peers():
	while _tcp_server.is_connection_available():
		last_peer_id += 1
		print("+ Peer %d connected." % last_peer_id)
		
		var ws = WebSocketPeer.new()
		ws.accept_stream(_tcp_server.take_connection())
		_peers[last_peer_id] = ws
		
		# Inicializar jugador con estado básico
		players[last_peer_id] = {
			"id": last_peer_id,
			"position": Vector2.ZERO,
			"name": "Guest%d" % last_peer_id
		}
		
		# Enviar mensaje de bienvenida
		var welcome_msg = {"type": "welcome", "id": last_peer_id}
		ws.send_text(JSON.stringify(welcome_msg))

func _poll_peers():
	for peer_id in _peers.keys():
		var peer = _peers[peer_id]
		peer.poll()

		var state = peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			_handle_peer_messages(peer_id, peer)
		elif state == WebSocketPeer.STATE_CLOSED:
			_disconnect_peer(peer_id, peer)

func _handle_peer_messages(peer_id: int, peer: WebSocketPeer):
	while peer.get_available_packet_count():
		var packet = peer.get_packet()
		if peer.was_string_packet():
			var json_text = packet.get_string_from_utf8()
			var json_parser := JSON.new()  # Crear instancia de JSON
			var msg = json_parser.parse_string(json_text)
			if msg.error != OK:
				print("Invalid JSON from peer %d" % peer_id)
				continue

			_process_message(peer_id, msg.result)


func _process_message(peer_id: int, msg: Dictionary):
	match msg.get("type", ""):
		"login":
			# Establecer nombre del jugador
			players[peer_id]["name"] = msg.get("name", "Guest%d" % peer_id)
			
			# Notificar a todos que un jugador se unió
			_broadcast({"type": "player_joined", "player": players[peer_id]})

		"move":
			# Actualizar posición del jugador
			var pos = msg.get("position", Vector2.ZERO)
			players[peer_id]["position"] = pos
			
			# Enviar movimiento a todos los demás jugadores
			var exclude_peers = [peer_id]  # Se debe crear el array fuera de la llamada
			_broadcast({"type": "player_move", "id": peer_id, "position": pos}, exclude_peers)

		"chat":
			var text = msg.get("text", "")
			_broadcast({"type": "chat", "id": peer_id, "text": text})

		_:
			print("Unknown message type from peer %d: %s" % [peer_id, msg])

# ------------------------------
# --- BROADCAST GLOBAL A TODOS ---
# ------------------------------
func _broadcast(msg: Dictionary, exclude: Array = []):
	var json_text = JSON.stringify(msg)
	for peer_id in _peers.keys():
		if peer_id in exclude:
			continue
		var peer = _peers[peer_id]
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			peer.send_text(json_text)

# ------------------------------
# --- DESCONEXIÓN DE PEER ------
# ------------------------------
func _disconnect_peer(peer_id: int, peer: WebSocketPeer):
	_peers.erase(peer_id)
	var leaving_player = players[peer_id]
	players.erase(peer_id)
	print("- Peer %d disconnected." % peer_id)
	
	# Notificar a todos que un jugador se fue
	_broadcast({"type": "player_left", "id": peer_id, "player": leaving_player})
