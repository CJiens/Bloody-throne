#Network.gd
extends Node
# -------------------------------
# --- VARIABLES CONFIGURACIÓN
# -------------------------------
@export var websocket_url_base := "ws://"
@export var api_url_base := "http://"

var websocket_url := ""
var api_url := ""
var bases := {}

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
signal enemy_spawned_immediate(enemy_data)
signal login_successful
signal connection_successful
signal connection_failed
signal projectile_created(projectile_data)
signal projectile_removed(projectile_id)
signal projectile_moved(projectile_data)
signal player_joined(player_data)
signal player_left(player_id)
signal game_state_updated
signal rogue_area_attack_effect(x, y, player_id)
# Señales para daño a bases
signal base_hit(team, hp, max_hp)
# SEÑALES NUEVAS PARA SISTEMA DE OLEADAS
signal wave_started(wave_number, enemy_count)
signal wave_ended()
signal boss_spawned(boss_data)
# ✅ CORREGIDO: Cambiar señal currency_updated para incluir player_id
signal currency_updated(player_id, amount)
signal decision_period_started(duration, currency, cards)
signal game_session_started()

signal card_purchased(card_data, new_balance)
signal card_purchase_failed(reason)
signal player_upgraded(player_id, upgrade_type)
# Señal para efecto de ataque de área
signal area_attack_effect(x, y, player_id)
# SEÑALES NUEVAS PARA SISTEMA DE EQUIPOS Y VICTORIA
signal team_update(team_counts, players)
signal team_selected(team, position)
signal team_selection_failed(reason, team_counts)
signal game_starting(countdown)
signal game_start_countdown(countdown)
signal game_started()
signal player_dead(player_id, killer_id, respawn_time)
signal respawn_countdown(player_id, time_left)
signal player_respawned(player_data)
signal game_over(winning_team, reason)
signal game_reset(players, bases)
signal mage_area_attack_effect(x, y, player_id)
# SEÑALES PARA JEFE PERMANENTE
#signal boss_phase_changed(boss_id, phase)
#signal boss_attacked(target_id, damage)
#signal boss_health_updated(hp, max_hp)
#signal boss_died(boss_id)
#
## Añadir junto a las otras señales del boss
#signal boss_animation_updated(boss_id, animation_name)

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
			"enemy_dead":
				enemies.erase(str(data.id))
				print("💀 Enemigo muerto - ID:", data.id, " Por:", data.killer_id)
				if get_tree().current_scene.has_method("_on_enemy_killed"):
					get_tree().current_scene._on_enemy_killed(data.id, data.killer_id, data.enemy_type)
			"enemy_spawned":
				print("👹 ENEMIGO SPAWNEADO INMEDIATAMENTE - ID:", data.enemy.id, " Equipo:", data.enemy.team)
				enemies[str(data.enemy.id)] = {
					"x": data.enemy.x,
					"y": data.enemy.y,
					"type": data.enemy.type,
					"hp": data.enemy.hp,
					"max_hp": data.enemy.max_hp,
					"team": data.enemy.team, # ✅ EQUIPO INCLUIDO INMEDIATAMENTE
					"attack_damage": data.enemy.attack_damage,
					"move_speed": data.enemy.move_speed
					}
				emit_signal("enemy_spawned_immediate", data.enemy)
				print("✅ SEÑAL enemy_spawned_immediate EMITIDA")
			"rogue_area_attack_effect":
				print("💥 EFECTO DE ATAQUE DE ÁREA ROGUE RECIBIDO - Posición:", data.x, data.y, " Jugador:", data.player_id)
				emit_signal("rogue_area_attack_effect", data.x, data.y, data.player_id)
			"mage_area_attack_effect":
				print("💥 EFECTO DE ATAQUE DE ÁREA MAGA RECIBIDO - Posición:", data.x, data.y, " Jugador:", data.player_id)
				emit_signal("mage_area_attack_effect", data.x, data.y, data.player_id)
			"auth_ok":
				player_id = data.player.id
				connected = true
				players[player_id] = data.player
				enemies = data.enemies
				print("✅ Autenticado como:", data.player.username, " ID:", player_id, " Clase:", data.player.classe)
				emit_signal("game_state_updated")
			"area_attack_effect":
				print("💥 EFECTO DE ATAQUE DE ÁREA RECIBIDO - Posición:", data.x, data.y, " Jugador:", data.player_id)
				emit_signal("area_attack_effect", data.x, data.y, data.player_id)

			"auth_error":
				print("❌ Error de autenticación:", data.error)
			"base_hit":
				print("🏰 BASE GOLPEADA - Equipo:", data.team, " HP:", data.hp, "/", data.max_hp)
				emit_signal("base_hit", data.team, data.hp, data.max_hp)

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
				bases.clear()
				if data.has("bases"):
					for team in data.bases.keys():
						var b = data.bases[team]
						bases[team] = {
						"hp": b.hp,
						"maxHp": b.maxHp,
						"team": b.team
						}
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

			
			"wave_started":
				print("🌊 OLEADA INICIADA - Número:", data.wave_number, " Enemigos:", data.enemy_count)
				emit_signal("wave_started", data.wave_number, data.enemy_count)
			
			"wave_ended":
				print("✅ OLEADA TERMINADA")
				emit_signal("wave_ended")
			
			#"boss_spawned":
				#print("👹 JEFE INTERMEDIO APARECE")
				#emit_signal("boss_spawned", data.boss_data)
			
			# ✅ CORREGIDO: Manejar currency_updated con player_id
			"currency_updated":
				print("💰 MONEDAS ACTUALIZADAS - Jugador:", data.player_id, " Cantidad:", data.amount)
				emit_signal("currency_updated", data.player_id, data.amount)
			
			"decision_period_started":
				print("⏰ PERIODO DE DECISIONES RECIBIDO - Duración:", data.duration, " Monedas:", data.currency)
				
				#// ✅ CORREGIDO: Manejo robusto de las cartas
				var cards_array = []
				if data.has("cards"):
					cards_array = data.cards
					if cards_array == null:
						cards_array = []
				else:
					print("⚠️ ADVERTENCIA: Mensaje decision_period_started no tiene campo 'cards'")
					cards_array = []
				
				#// ✅ DEBUG DETALLADO
				print("🃏 CARTAS RECIBIDAS EN NETWORK - Cantidad:", cards_array.size())
				for i in range(cards_array.size()):
					var card = cards_array[i]
					if card is Dictionary:
						print("  [%d] %s (ID: %s, Costo: %d)" % [i, card.get("name", "Sin nombre"), card.get("id", "sin_id"), card.get("cost", 0)])
					else:
						print("  ❌ [%d] Formato incorrecto: %s" % [i, str(card)])
				
				emit_signal("decision_period_started", data.duration, data.currency, cards_array)
			
			"game_session_started":
				print("🎮 SESIÓN DE JUEGO INICIADA")
				emit_signal("game_session_started")
			
			"card_purchased":
				print("✅ COMPRA DE CARTA EXITOSA:", data.card)
				emit_signal("card_purchased", data.card, data.new_balance)
	
			"card_purchase_failed":
				print("❌ FALLO EN COMPRA DE CARTA:", data.reason)
				emit_signal("card_purchase_failed", data.reason)
	
			"player_upgraded":
				print("⬆️ JUGADOR MEJORADO:", data.player_id, " Tipo:", data.upgrade_type)
				emit_signal("player_upgraded", data.player_id, data.upgrade_type)
			
			# NUEVOS MENSAJES PARA SISTEMA DE EQUIPOS Y VICTORIA
			"team_update":
				print("👥 ACTUALIZACIÓN DE EQUIPOS - Equipo 1:", data.team_counts["1"], " Equipo 2:", data.team_counts["2"])
				emit_signal("team_update", data.team_counts, data.players)

			"team_selected":
				print("✅ EQUIPO SELECCIONADO - Equipo:", data.team, " Posición:", data.position)
				emit_signal("team_selected", data.team, data.position)
			
			"team_selection_failed":
				print("❌ ERROR SELECCIÓN EQUIPO:", data.reason)
				emit_signal("team_selection_failed", data.reason, data.team_counts)
			
			"game_starting":
				print("🚀 JUEGO INICIANDO EN:", data.countdown, "segundos")
				emit_signal("game_starting", data.countdown)
			
			"game_start_countdown":
				print("⏰ COUNTDOWN INICIO:", data.countdown)
				emit_signal("game_start_countdown", data.countdown)
			
			"game_started":
				print("🎮 JUEGO INICIADO!")
				emit_signal("game_started")
			
			"player_dead":
				print("💀 JUGADOR MUERTO - ID:", data.id, " Por:", data.by, " Respawn en:", data.respawn_time, "s")
				emit_signal("player_dead", data.id, data.by, data.respawn_time)
			
			"respawn_countdown":
				print("⏳ RESPAWN - Jugador:", data.player_id, " Tiempo:", data.time_left)
				emit_signal("respawn_countdown", data.player_id, data.time_left)
			
			"player_respawned":
				print("🔁 JUGADOR RESPAWNEADO - ID:", data.player.id)
				emit_signal("player_respawned", data.player)
			
			"game_over":
				print("🎯 JUEGO TERMINADO - Equipo ganador:", data.winning_team, " Razón:", data.reason)
				emit_signal("game_over", data.winning_team, data.reason)
			
			"game_reset":
				print("🔄 JUEGO REINICIADO")
				emit_signal("game_reset", data.players, data.bases)
			
			## MENSAJES PARA JEFE PERMANENTE
			#"boss_phase_changed":
				#print("🔥 JEFE CAMBIA FASE - ID:", data.boss_id, " Fase:", data.phase)
				#emit_signal("boss_phase_changed", data.boss_id, data.phase)
			#
			#"boss_attacked":
				#print("💥 JEFE ATACÓ - Target:", data.target_id, " Daño:", data.damage)
				#emit_signal("boss_attacked", data.target_id, data.damage)
			#
			#"boss_health_updated":
				#print("❤️  JEFE ACTUALIZA SALUD - HP:", data.hp, "/", data.max_hp)
				#emit_signal("boss_health_updated", data.hp, data.max_hp)
			#
			#"boss_died":
				#print("💀 JEFE MUERTO - ID:", data.boss_id)
				#emit_signal("boss_died", data.boss_id)
				#
			#"boss_animation_update":
				#print("🎭 ACTUALIZACIÓN ANIMACIÓN BOSS - ID:", data.boss_id, " Animación:", data.animation)
				#emit_signal("boss_animation_updated", data.boss_id, data.animation)
		#
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

func is_server_connected() -> bool:
	return connected and ws_ready


func start_game_session():
	if connected and ws_ready:
		print("🎮 SOLICITANDO INICIO DE SESIÓN DE JUEGO")
		socket.send_text(JSON.stringify({
			"type": "start_game_session"
		}))

func request_currency_update(amount: int):
	if connected and ws_ready:
		print("💰 SOLICITANDO ACTUALIZACIÓN DE MONEDAS:", amount)
		socket.send_text(JSON.stringify({
			"type": "request_currency_update",
			"amount": amount
		}))

func make_decision(decision_type: String, target: String, cost: int):
	if connected and ws_ready:
		print("🎯 ENVIANDO DECISIÓN - Tipo:", decision_type, " Objetivo:", target, " Costo:", cost)
		socket.send_text(JSON.stringify({
			"type": 'player_decision',
			"decision_type": decision_type,
			"target": target,
			"cost": cost
		}))

func purchase_card(card_id: String):
	if connected and ws_ready:
		print("🃏 ENVIANDO COMPRA DE CARTA - ID:", card_id)
		socket.send_text(JSON.stringify({
			"type": "purchase_card",
			"card_id": card_id
		}))

# NUEVAS FUNCIONES PARA SISTEMA DE EQUIPOS
func select_team(team: int):
	if connected and ws_ready:
		print("🎯 SELECCIONANDO EQUIPO - Equipo:", team)
		socket.send_text(JSON.stringify({
			"type": "select_team",
			"team": team
		}))

# NUEVAS FUNCIONES PARA JEFE PERMANENTE
func request_boss_respawn():
	if connected and ws_ready:
		print("🔄 SOLICITANDO RESPawN DEL JEFE")
		socket.send_text(JSON.stringify({
			"type": "request_boss_respawn"
		}))

func request_boss_spawn():
	if connected and ws_ready:
		print("🎯 SOLICITANDO SPAWN DEL JEFE")
		socket.send_text(JSON.stringify({
			"type": "request_boss_spawn"
		}))

# -------------------------------
# --- FUNCIONES DE UTILIDAD
# -------------------------------
func get_player_count() -> int:
	return players.size()

func get_enemy_count() -> int:
	return enemies.size()

func get_projectile_count() -> int:
	return projectiles.size()

func get_player_by_id(player_id: int) -> Dictionary:
	return players.get(str(player_id), {})

func get_enemy_by_id(enemy_id: int) -> Dictionary:
	return enemies.get(str(enemy_id), {})

func get_projectile_by_id(projectile_id: int) -> Dictionary:
	return projectiles.get(str(projectile_id), {})

# En Network.gd, agregar esta función para forzar el spawn del boss
func request_boss_force_spawn():
	if connected and ws_ready:
		print("🎯 SOLICITANDO SPAWN FORZADO DEL JEFE")
		socket.send_text(JSON.stringify({
			"type": "request_boss_spawn"
		}))
