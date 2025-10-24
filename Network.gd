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
signal connection_successful
signal connection_failed
signal projectile_created(projectile_data)
signal projectile_removed(projectile_id)
signal projectile_moved(projectile_data)
signal player_joined(player_data)
signal player_left(player_id)
signal game_state_updated
signal on_player_became_ghost(player_id)
signal on_ghost_possession_started(player_id, object_id)
signal on_ghost_possession_ended(player_id, object_id) 
signal on_object_thrown(object_id, direction)
signal on_object_destroyed(object_id)
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
		print("✅ Conexión WS iniciada correctamente")
	else:
		push_error("❌ No se pudo iniciar conexión WS a " + websocket_url)
		emit_signal("connection_failed")
		set_process(false)

# -------------------------------
# --- CICLO PRINCIPAL
# -------------------------------
func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()

	match state:
		WebSocketPeer.STATE_CONNECTING:
			print("🔷 Conectando...")
		WebSocketPeer.STATE_OPEN:
			if not ws_ready:
				ws_ready = true
				print("✅ WS Conexión abierta:", websocket_url)
				emit_signal("connection_successful")
				if token != "":
					auth(token)
			_receive_messages()
		WebSocketPeer.STATE_CLOSING:
			print("🔸 WS cerrando conexión...")
		WebSocketPeer.STATE_CLOSED:
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			print("🔴 WS cerrada - Código:", code, " Razón:", reason)
			connected = false
			ws_ready = false
			set_process(false)
			emit_signal("connection_failed")

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
			print("❌ Error parseando JSON:", text)
			continue
		var data = json.get_data()

		print("📥 MENSAJE RECIBIDO - Tipo:", data.type)

		match data.type:
			"auth_ok":
				player_id = data.player.id
				connected = true
				players[player_id] = data.player
				enemies = data.enemies
				print("✅ Autenticado como:", data.player.username, " ID:", player_id, " Clase:", data.player.classe)
				emit_signal("game_state_updated")

			"object_destroyed":
				print("💥 OBJETO DESTRUIDO RECIBIDO - ID:", data.object_name)
				emit_signal("on_object_destroyed", data.object_name	)

			"auth_error":
				print("❌ Error de autenticación:", data.error)

			"join":
				players[data.player.id] = {
					"x": data.player.x,
					"y": data.player.y,
					"username": data.player.username,
					"hp": data.player.hp,
					"max_hp": data.player.max_hp,
					"animation_state": data.player.get("animation_state", "Idle"),
					"classe": data.player.get("classe", "warrior")
				}
				print("👤 Jugador se unió:", data.player.username, " ID:", data.player.id, " Clase:", data.player.get("classe", "warrior"))
				emit_signal("player_joined", players[data.player.id])
				emit_signal("game_state_updated")

			"leave":
				players.erase(data.id)
				print("🚪 Jugador salió:", data.id)
				emit_signal("player_left", data.id)
				emit_signal("game_state_updated")

			"player_moved":
				if str(data.player.id) in players:
					players[str(data.player.id)].x = data.player.x
					players[str(data.player.id)].y = data.player.y

			"enemy_hit":
				if str(data.id) in enemies:
					enemies[str(data.id)].hp = data.hp
					print("💥 Enemigo golpeado - ID:", data.id, " HP:", data.hp)

			"enemy_dead":
				enemies.erase(str(data.id))
				print("💀 Enemigo muerto - ID:", data.id)

			"player_hit":
				if str(data.id) in players:
					players[str(data.id)].hp = data.hp
					print("💥 Jugador golpeado - ID:", data.id, " HP:", data.hp)
					emit_signal("game_state_updated")

			"player_dead":
				if str(data.id) in players:
					players[str(data.id)].hp = 0
					print("💀 Jugador muerto - ID:", data.id)
					emit_signal("game_state_updated")

			"player_state_update":
				var player_id_str = str(data.id)
				if players.has(player_id_str):
					players[player_id_str].animation_state = data.state
					print("🎭 Estado jugador actualizado - ID:", data.id, " Estado:", data.state)

			"chat":
				print("[CHAT]", data.fromUsername, ":", data.text)

			"state":
				players.clear()
				for pid in data.players.keys():
					var p = data.players[pid]
					players[pid] = {
						"x": p.x,
						"y": p.y,
						"username": p.username,
						"hp": p.get("hp", 100),
						"max_hp": p.get("max_hp", 100),
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
						"hp": e.get("hp", 100),
						"max_hp": e.get("max_hp", 100)
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
				print("📊 Estado sincronizado - Jugadores:", players.size(), " Enemigos:", enemies.size(), " Proyectiles:", projectiles.size())
				emit_signal("game_state_updated")

			"projectile_created":
				projectiles[str(data.id)] = {
					"x": data.x,
					"y": data.y,
					"direction_x": data.direction_x,
					"direction_y": data.direction_y,
					"damage": data.damage,
					"owner_id": data.owner_id,
					"speed": data.speed,
					"classe": data.get("classe", "warrior")
				}
				emit_signal("projectile_created", projectiles[str(data.id)])
				print("🎯 PROYECTIL CREADO EN RED - ID:", data.id, " Owner:", data.owner_id, " Clase:", data.get("classe", "warrior"))
				
			"projectile_moved":
				var proj_id = str(data.id)
				if proj_id in projectiles:
					projectiles[proj_id].x = data.x
					projectiles[proj_id].y = data.y
					emit_signal("projectile_moved", projectiles[proj_id])
				
			"projectile_removed":
				var proj_id = str(data.id)
				projectiles.erase(proj_id)
				emit_signal("projectile_removed", data.id)
				print("🗑️ Proyectil removido - ID:", data.id)

			"player_state_response":
				players = data.players
				print("🔄 Estado de jugadores actualizado")
				emit_signal("game_state_updated")

			"player_update":
				var player_id_str = str(data.player.id)
				if players.has(player_id_str):
					# Actualizar datos del jugador específico
					var old_classe = players[player_id_str].get("classe", "warrior")
					var new_classe = data.player.get("classe", "warrior")
					
					players[player_id_str] = {
						"x": data.player.x,
						"y": data.player.y,
						"username": data.player.username,
						"hp": data.player.hp,
						"max_hp": data.player.max_hp,
						"animation_state": data.player.get("animation_state", "Idle"),
						"classe": new_classe
					}
					
					if old_classe != new_classe:
						print("🔄 CLASE ACTUALIZADA - ID:", data.player.id, " Nueva clase:", new_classe)
					else:
						print("🔄 Jugador actualizado - ID:", data.player.id, " Clase:", new_classe)
					
					emit_signal("game_state_updated")

			"all_players_ready":
				print("🚀 TODOS LOS JUGADORES LISTOS - Iniciando juego...")
				# Esta señal será manejada por main.gd

			# NUEVOS MENSAJES PARA FANTASMAS Y OBJETOS
			"player_became_ghost":
				print("👻 Jugador se convirtió en fantasma - ID:", data.player_id)
				emit_signal("on_player_became_ghost", data.player_id)
			
			"ghost_possession_started":
				print("🎯 Fantasma poseyendo objeto - Player:", data.player_id, " Objeto:", data.object_name)
				emit_signal("on_ghost_possession_started", data.player_id, data.object_name)
			
			"ghost_possession_ended":
				print("🎯 Fantasma liberó objeto - Player:", data.player_id, " Objeto:", data.object_id)
				emit_signal("on_ghost_possession_ended", data.player_id, data.object_id)

			"object_thrown":
				print("🚀 Objeto lanzado - Objeto:", data.object_name, " Dirección:", Vector2(data.direction_x, data.direction_y))
				emit_signal("on_object_thrown", data.object_name, Vector2(data.direction_x, data.direction_y))
			
			"ghost_moved":
				# Podemos manejar el movimiento de fantasmas remotos si es necesario
				pass
		
			_:
				print("📨 Mensaje no manejado:", data.type)
				

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
			"classe": classe
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
		print("❌ Error parseando respuesta del servidor")
		return
		
	var data = json.get_data()
	if data and data.ok:
		print("✅ Login exitoso:", data.user.username)
		auth(data.token)
		emit_signal("login_successful")
	else:
		print("❌ Error en login:", data.error if data else "Respuesta vacía")

# Agregar esta función para forzar sincronización
func request_player_update():
	if connected:
		socket.send_text(JSON.stringify({
			"type": "get_player_state"
		}))

func disconnect_from_server():
	if connected:
		socket.close()
		connected = false
		ws_ready = false
		player_id = -1
		players.clear()
		enemies.clear()
		projectiles.clear()
		set_process(false)
		print("🔌 Desconectado del servidor")

# CORREGIDO: Cambiar nombre de la función que entraba en conflicto
func is_server_connected() -> bool:
	return connected and ws_ready

# -------------------------------
# --- NUEVAS FUNCIONES PARA FANTASMAS Y OBJETOS
# -------------------------------
func player_became_ghost(player_id: int):
	if connected and ws_ready:
		print("👻 ENVIANDO CONVERSIÓN A FANTASMA - Player:", player_id)
		socket.send_text(JSON.stringify({
			"type": "player_became_ghost",
			"player_id": player_id
		}))
	else:
		print("❌ No conectado - No se puede enviar conversión a fantasma")

# CORREGIR todas las funciones de envío para verificar conexión completa
func ghost_possession_started(player_id: int, object_name: String):
	if connected and ws_ready:  # ✅ VERIFICACIÓN COMPLETA
		print("🎯 ENVIANDO POSESIÓN INICIADA - Player:", player_id, " Object:", object_name)
		socket.send_text(JSON.stringify({
			"type": "ghost_possession_started", 
			"player_id": player_id,
			"object_name": object_name
			}))
	else:
		print("❌ No conectado - No se puede enviar posesión")

func ghost_possession_ended(player_id: int, object_name: String):
	if connected and ws_ready:  # ✅ VERIFICACIÓN COMPLETA
		print("🎯 ENVIANDO POSESIÓN TERMINADA - Player:", player_id, " Object:", object_name)
		socket.send_text(JSON.stringify({
			"type": "ghost_possession_ended",
			"player_id": player_id, 
			"object_name": object_name
			}))
	else:
		print("❌ No conectado - No se puede enviar fin de posesión")

func throw_object(object_name: String, direction: Vector2):
	if connected and ws_ready:  # ✅ VERIFICACIÓN COMPLETA
		print("🚀 ENVIANDO OBJETO LANZADO - Object:", object_name, " Direction:", direction)
		socket.send_text(JSON.stringify({
			"type": "object_thrown",
			"object_name": object_name,
			"direction_x": direction.x,
			"direction_y": direction.y
			}))
	else:
		print("❌ No conectado - No se puede enviar lanzamiento")

# AGREGAR función move_ghost que falta
func move_ghost(x: float, y: float):
	if connected and ws_ready:
		socket.send_text(JSON.stringify({
			"type": "move",  # ✅ Reutilizamos "move" para ambos
			"x": x,
			"y": y
		}))
func sync_object_destruction(object_name: String):
	if connected and ws_ready:
		socket.send_text(JSON.stringify({
			"type": "object_destroyed",
			"object_name": object_name
		}))
