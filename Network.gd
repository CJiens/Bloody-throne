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
var projectiles := {}
var ws_ready := false

# -------------------------------
# --- SEÑALES
# -------------------------------
signal login_successful
signal projectile_created(projectile_data)
signal projectile_removed(projectile_id)
signal projectile_moved(projectile_data)

# -------------------------------
# --- FUNCIÓN DE INICIO CON IP
# -------------------------------
func connect_with_ip(ip: String):
	websocket_url = "%s%s:3000" % [websocket_url_base, ip]
	api_url = "%s%s:3000/api" % [api_url_base, ip]

	print("🌐 Intentando conectar con:", websocket_url)

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

		print("📥 MENSAJE RECIBIDO - Tipo:", data.type)

		match data.type:
			"auth_ok":
				player_id = data.player.id
				connected = true
				enemies = data.enemies
				print("✅ Autenticado como:", data.player.username, " ID:", player_id)

			"auth_error":
				print("❌ Error de autenticación:", data.error)

			"join":
				players[data.player.id] = {
					"x": data.player.x,
					"y": data.player.y,
					"username": data.player.username,
					"hp": data.player.hp,
					"animation_state": data.player.get("animation_state", "Idle"),
					"classe": data.player.get("classe", "warrior")
				}
				print("👤 Jugador se unió:", data.player.username, " ID:", data.player.id, " Clase:", data.player.get("classe", "warrior"))

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
					print("💥 Enemigo golpeado - ID:", data.id, " HP:", data.hp)

			"enemy_dead":
				enemies.erase(data.id)
				print("💀 Enemigo muerto - ID:", data.id)

			"player_hit":
				if data.id in players:
					players[data.id].hp = data.hp
					print("💥 Jugador golpeado - ID:", data.id, " HP:", data.hp)

			"player_dead":
				if data.id in players:
					players[data.id].hp = 0
					print("💀 Jugador muerto - ID:", data.id)

			"player_state_update":
				var player_id_str = str(int(data.id))
				if players.has(player_id_str):
					players[player_id_str].animation_state = data.state
					print("🎭 Estado jugador actualizado - ID:", data.id, " Estado:", data.state)

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
						"animation_state": p.get("animation_state", "Idle"),
						"classe": p.get("classe", "warrior")
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
				# Actualizar proyectiles
				projectiles.clear()
				if data.has("projectiles"):
					for pid in data.projectiles.keys():
						var proj = data.projectiles[pid]
						projectiles[pid] = {
							"x": proj.x,
							"y": proj.y,
							"direction_x": proj.direction_x,
							"direction_y": proj.direction_y,
							"damage": proj.damage,
							"owner_id": proj.owner_id,
							"speed": proj.speed,
							"classe": proj.get("classe", "warrior")
						}
					print("📊 Estado - Proyectiles:", projectiles.size())

			"projectile_created":
				projectiles[data.id] = {
					"x": data.x,
					"y": data.y,
					"direction_x": data.direction_x,
					"direction_y": data.direction_y,
					"damage": data.damage,
					"owner_id": data.owner_id,
					"speed": data.speed,
					"classe": data.get("classe", "warrior")
				}
				emit_signal("projectile_created", projectiles[data.id])
				print("🎯 PROYECTIL CREADO EN RED - ID:", data.id, " Owner:", data.owner_id, " Clase:", data.get("classe", "warrior"), " Pos:", data.x, ",", data.y)
				
			"projectile_moved":
				if data.id in projectiles:
					projectiles[data.id].x = data.x
					projectiles[data.id].y = data.y
					emit_signal("projectile_moved", projectiles[data.id])
					print("🔄 Proyectil movido - ID:", data.id, " Pos:", data.x, ",", data.y)
				
			"projectile_removed":
				projectiles.erase(data.id)
				emit_signal("projectile_removed", data.id)
				print("🗑️ Proyectil removido - ID:", data.id)

			"player_state_response":
				players = data.players
				print("🔄 Estado de jugadores actualizado")

			"player_update":
				if data.player.id in players:
					# Actualizar datos del jugador específico
					players[data.player.id] = {
						"x": data.player.x,
						"y": data.player.y,
						"username": data.player.username,
						"hp": data.player.hp,
						"animation_state": data.player.get("animation_state", "Idle"),
						"classe": data.player.get("classe", "warrior")
					}
					print("🔄 Jugador actualizado - ID:", data.player.id, " Clase:", data.player.get("classe", "warrior"))

# -------------------------------
# --- ENVÍO DE MENSAJES
# -------------------------------
func auth(token_str: String):
	token = token_str
	if ws_ready:
		print("🔐 Enviando autenticación...")
		socket.send_text(JSON.stringify({
			"type": "auth",
			"token": token
		}))

func move_player(x: float, y: float):
	if connected:
		socket.send_text(JSON.stringify({
			"type": "move",
			"x": x,
			"y": y,
		}))

func attack(target_type: String, target_id: int, damage: int = 10):
	if connected:
		print("💥 ENVIANDO ATAQUE - Target:", target_type, target_id, " Damage:", damage)
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

# MODIFICADO: Agregar parámetro de clase al crear proyectil
func create_projectile(x: float, y: float, direction: Vector2, damage: int, owner_id: int, speed: float = 400.0, classe: String = "warrior"):
	if connected:
		print("🚀 ENVIANDO PROYECTIL - Owner:", owner_id, " Clase:", classe)
		socket.send_text(JSON.stringify({
			"type": "create_projectile",
			"x": x,
			"y": y,
			"direction_x": direction.x,
			"direction_y": direction.y,
			"damage": damage,
			"owner_id": owner_id,
			"speed": speed,
			"classe": classe # Nueva información
		}))

func remove_projectile(projectile_id: int):
	if connected:
		print("🗑️ Enviando remoción proyectil - ID:", projectile_id)
		socket.send_text(JSON.stringify({
			"type": "remove_projectile",
			"id": projectile_id
		}))

func update_projectile_position(projectile_id: int, x: float, y: float):
	if connected:
		socket.send_text(JSON.stringify({
			"type": "update_projectile_position",
			"id": projectile_id,
			"x": x,
			"y": y
		}))

# -------------------------------
# --- NUEVAS FUNCIONES PARA COLISIONES LOCALES
# -------------------------------
func projectile_hit_player(projectile_id: int, player_id: int, damage: int):
	if connected:
		print("💥 ENVIANDO COLISIÓN PROYECTIL-JUGADOR - Proyectil:", projectile_id, " Jugador:", player_id, " Daño:", damage)
		socket.send_text(JSON.stringify({
			"type": "projectile_hit",
			"projectile_id": projectile_id,
			"player_id": player_id,
			"damage": damage
		}))

func choose_class(classe: String):
	if connected:
		print("🎯 ENVIANDO ELECCIÓN DE CLASE - Clase:", classe)
		socket.send_text(JSON.stringify({
			"type": "choose_class",
			"classe": classe
		}))

# -------------------------------
# --- LOGIN API
# -------------------------------
func login_user(username: String, password: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	print("🔐 Iniciando login...")
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

# Agregar esta función para forzar sincronización
func request_player_update():
	if connected:
		socket.send_text(JSON.stringify({
			"type": "get_player_state"
		}))
