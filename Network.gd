extends Node

# -------------------------------
# --- CONFIGURACIÓN DEL SERVIDOR
# -------------------------------
@export var websocket_url := "ws://localhost:3000"  # URL WebSocket
@export var api_url := "http://localhost:3000/api"  # URL base API REST

# -------------------------------
# --- VARIABLES DE RED
# -------------------------------
var socket: WebSocketPeer = WebSocketPeer.new()
var player_id: int = -1  # ID del jugador logueado
var connected := false
var token: String = ""  # JWT obtenido tras login
var players := {}  # id:int -> {x, y, username, hp}
var enemies := {}  # id:int -> {x, y, type, hp}
var ws_ready := false  # WS abierto y listo

# -------------------------------
# --- SEÑALES
# -------------------------------
signal login_successful

# -------------------------------
# --- INICIO
# -------------------------------
func _ready():
	print("Iniciando conexión WS a %s..." % websocket_url)
	var err = socket.connect_to_url(websocket_url)
	if err == OK:
		set_process(true)
	else:
		push_error("No se pudo iniciar conexión WS")
		set_process(false)

# -------------------------------
# --- CICLO PRINCIPAL
# -------------------------------
func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()

	match state:
		WebSocketPeer.STATE_CONNECTING:
			pass
		WebSocketPeer.STATE_OPEN:
			if not ws_ready:
				ws_ready = true
				print("WS: Conexión abierta ✅")
				if token != "":
					auth(token)  # Enviar token al abrir WS
			_receive_messages()
		WebSocketPeer.STATE_CLOSING:
			print("WS: Cerrando conexión...")
		WebSocketPeer.STATE_CLOSED:
			print("WS: Cerrada")
			set_process(false)

# -------------------------------
# --- RECEPCIÓN DE MENSAJES WS
# -------------------------------
func _receive_messages():
	while socket.get_available_packet_count() > 0:
		var packet = socket.get_packet()
		if not socket.was_string_packet():
			continue

		var text = packet.get_string_from_utf8()
		print("[WS RECEIVED]", text)

		var json = JSON.new()
		var err = json.parse(text)
		if err != OK:
			print("Error parseando JSON:", json.get_error_message())
			continue
		var data = json.get_data()

		match data.type:
			"auth_ok":
				player_id = data.player.id
				connected = true
				enemies = data.enemies
				print("Autenticado como:", data.player.username)
			"auth_error":
				print("Error de autenticación:", data.error)
			"join":
				players[data.player.id] = {
					"x": data.player.x,
					"y": data.player.y,
					"username": data.player.username,
					"hp": data.player.hp if data.player.has("hp") else 100
				}
				print("Jugador se unió:", data.player.username)
			"leave":
				players.erase(data.id)
				print("Jugador salió:", data.id)
			"player_moved":
				if data.player.id in players:
					players[data.player.id].x = data.player.x
					players[data.player.id].y = data.player.y
			"enemy_hit":
				if data.id in enemies:
					enemies[data.id].hp = data.hp
			"enemy_dead":
				enemies.erase(data.id)
			"player_hit":
				if data.id in players:
					players[data.id].hp = data.hp
			"player_dead":
				if data.id in players:
					players[data.id].hp = 0
			"chat":
				print("[CHAT]", data.from, ":", data.text)
			"state":
				# Sobrescribir todos los players/enemies
				players.clear()
				for pid in data.players.keys():
					var p = data.players[pid]
					players[pid] = {
						"x": p.x,
						"y": p.y,
						"username": p.username,
						"hp": p.hp if p.has("hp") else 100
					}
				enemies.clear()
				for eid in data.enemies.keys():
					var e = data.enemies[eid]
					enemies[eid] = {
						"x": e.x,
						"y": e.y,
						"type": e.type,
						"hp": e.hp if e.has("hp") else 100
					}
			_:
				print("Mensaje WS desconocido:", data)

# -------------------------------
# --- ENVÍO DE MENSAJES WS
# -------------------------------
func auth(token_str: String):
	token = token_str
	if ws_ready:
		socket.send_text(JSON.stringify({
			"type": "auth",
			"token": token
		}))
	else:
		print("WS aún no listo, auth pendiente...")

func move_player(x: float, y: float):
	if connected:
		socket.send_text(JSON.stringify({
			"type": "move",
			"x": x,
			"y": y
		}))

func attack(target_type: String, target_id: int, damage: int = 10):
	if connected:
		socket.send_text(JSON.stringify({
			"type": "attack",
			"targetType": target_type,
			"targetId": target_id,
			"damage": damage
		}))

func send_chat(text: String):
	if connected:
		socket.send_text(JSON.stringify({
			"type": "chat",
			"text": text
		}))

# -------------------------------
# --- LOGIN CON PARÁMETROS
# -------------------------------
func login_user(username: String, password: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	
	var err = http.request(
		api_url + "/login",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"username": username,
			"password": password
		})
	)
	if err != OK:
		print("❌ Error al enviar petición HTTP:", err)


# -------------------------------
# --- CALLBACK RESPUESTA HTTP
# -------------------------------
func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		print("Error parseando JSON HTTP:", json.get_error_message())
		return

	var data = json.get_data()

	if data.ok:
		print("✅ Login exitoso:", data.user.username)
		auth(data.token)  # Enviamos token al WebSocket
		emit_signal("login_successful")
	else:
		print("❌ Error en login:", data.error)
