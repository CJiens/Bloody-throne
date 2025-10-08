extends Node

# -------------------------------
# --- VARIABLES CONFIGURACIÓN
# -------------------------------
@export var websocket_url_base := "ws://"
@export var api_url_base := "http://"

var websocket_url := ""
var api_url := ""

# -------------------------------
# --- VARIABLES DE RED
# -------------------------------
var socket: WebSocketPeer = WebSocketPeer.new()
var player_id: int = -1
var connected := false
var token: String = ""
var players := {}
var enemies := {}
var ws_ready := false

# -------------------------------
# --- SEÑALES
# -------------------------------
signal login_successful

# -------------------------------
# --- FUNCIÓN DE INICIO CON IP
# -------------------------------
func connect_with_ip(ip: String):
	websocket_url = "%s%s:3000" % [websocket_url_base, ip]
	api_url = "%s%s:3000/api" % [api_url_base, ip]

	print("Intentando conectar con:", websocket_url)

	var err = socket.connect_to_url(websocket_url)
	if err == OK:
		set_process(true)
	else:
		push_error("❌ No se pudo iniciar conexión WS a " + websocket_url)
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
				print("✅ WS Conexión abierta:", websocket_url)
				if token != "":
					auth(token)
			_receive_messages()
		WebSocketPeer.STATE_CLOSING:
			print("🔸 WS cerrando conexión...")
		WebSocketPeer.STATE_CLOSED:
			print("🔴 WS cerrada")
			set_process(false)

# -------------------------------
# --- RECEPCIÓN DE MENSAJES
# -------------------------------
func _receive_messages():
	while socket.get_available_packet_count() > 0:
		var packet = socket.get_packet()
		if not socket.was_string_packet():
			continue

		var text = packet.get_string_from_utf8()
		var json = JSON.new()
		if json.parse(text) != OK:
			continue
		var data = json.get_data()

		match data.type:
			"auth_ok":
				player_id = data.player.id
				connected = true
				enemies = data.enemies
				print("✅ Autenticado como:", data.player.username)

			"auth_error":
				print("❌ Error de autenticación:", data.error)

			"join":
				players[data.player.id] = {
					"x": data.player.x,
					"y": data.player.y,
					"username": data.player.username,
					"hp": data.player.hp,
					"animation_state": data.player.get("animation_state", "Idle")
				}
				print("👤 Jugador se unió:", data.player.username)

			"leave":
				players.erase(data.id)
				print("🚪 Jugador salió:", data.id)

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

			"player_state_update":
				if data.id in players:
					players[data.id].animation_state = data.state

			"chat":
				print("[CHAT]", data.from, ":", data.text)

			"state":
				players.clear()
				for pid in data.players.keys():
					var p = data.players[pid]
					players[pid] = {
						"x": p.x,
						"y": p.y,
						"username": p.username,
						"hp": p.get("hp", 100),
						"animation_state": p.get("animation_state", "Idle")
					}
				enemies.clear()
				for eid in data.enemies.keys():
					var e = data.enemies[eid]
					enemies[eid] = {
						"x": e.x,
						"y": e.y,
						"type": e.type,
						"hp": e.get("hp", 100)
					}

# -------------------------------
# --- ENVÍO DE MENSAJES
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

func send_player_state(state: String):
	if connected:
		socket.send_text(JSON.stringify({
			"type": "player_state",
			"state": state
		}))

# -------------------------------
# --- LOGIN API
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

func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return
	var data = json.get_data()
	if data.ok:
		print("✅ Login exitoso:", data.user.username)
		auth(data.token)
		emit_signal("login_successful")
	else:
		print("❌ Error en login:", data.error)
