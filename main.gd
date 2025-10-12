extends Node2D

# -------------------------------
# --- NODOS
# -------------------------------
@onready var player_container = $PlayerContainer
@onready var enemy_container = $EnemyContainer

# UI
@onready var login_ui = $CanvasLayer/Pantalla_Inicial
@onready var chat_ui = $CanvasLayer/ChatUI
@onready var login_button: Button = $"CanvasLayer/Pantalla_Inicial/VBoxContainer2/Button_login"
@onready var username_input: LineEdit = $"CanvasLayer/Pantalla_Inicial/VBoxContainer2/LineEdit_username"
@onready var password_input: LineEdit = $"CanvasLayer/Pantalla_Inicial/VBoxContainer2/LineEdit_password"
@onready var chat_input: LineEdit = $CanvasLayer/ChatUI/LineEdit_chatInput
@onready var chat_send: Button = $CanvasLayer/ChatUI/Button_send
@onready var chat_log: TextEdit = $CanvasLayer/ChatUI/TextEdit_chatLog
@onready var vbox_container_2: VBoxContainer = $CanvasLayer/Pantalla_Inicial/VBoxContainer2
@onready var button: Button = $CanvasLayer/Pantalla_Inicial/VBoxContainer/Button
@onready var vbox_container: VBoxContainer = $CanvasLayer/Pantalla_Inicial/VBoxContainer
@onready var video_stream_player: VideoStreamPlayer = $CanvasLayer/Pantalla_Inicial/VideoStreamPlayer
@onready var label: Label = $CanvasLayer/Pantalla_Inicial/Label
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var vbox_container_3: VBoxContainer = $CanvasLayer/Pantalla_Inicial/VBoxContainer3
@onready var server_ip: LineEdit = $CanvasLayer/Pantalla_Inicial/VBoxContainer3/server_ip
@onready var button_ip: Button = $CanvasLayer/Pantalla_Inicial/VBoxContainer3/Button_ip
@onready var contrl: Control = $CanvasLayer/contrl

# Prefabs
@export var PlayerScene: PackedScene
@export var EnemyScene: PackedScene
@export var ProjectileScene: PackedScene

# -------------------------------
# --- VARIABLES DE JUEGO
# -------------------------------
var players := {} # id:int -> Node2D
var enemies := {} # id:int -> Node2D
var projectiles := {} # id:int -> Node2D

# -------------------------------
# --- INICIO
# -------------------------------
func _ready():
	login_button.pressed.connect(_on_login_pressed)
	chat_send.pressed.connect(_on_chat_send_pressed)
	chat_ui.visible = false
	vbox_container_2.visible = false
	vbox_container_3.visible = false

	button_ip.pressed.connect(_on_button_ip_pressed)

	if not Network.is_connected("login_successful", self._on_login_successful):
		Network.connect("login_successful", self._on_login_successful)
		
	# Conectar señales de proyectiles
	if not Network.is_connected("projectile_created", _on_projectile_created):
		Network.projectile_created.connect(_on_projectile_created)
	if not Network.is_connected("projectile_moved", _on_projectile_moved):
		Network.projectile_moved.connect(_on_projectile_moved)
	if not Network.is_connected("projectile_removed", _on_projectile_removed):
		Network.projectile_removed.connect(_on_projectile_removed)

	print("🎮 Main listo - Esperando conexión...")

# -------------------------------
# --- PROCESO PRINCIPAL
# -------------------------------
func _process(_delta):
	if not Network.connected or Network.player_id == -1:
		return

	# Debug de estado
	if Engine.get_frames_drawn() % 180 == 0:  # Cada 3 segundos aproximadamente
		print("📊 ESTADO - Jugadores:", players.size(), " Enemigos:", enemies.size(), " Proyectiles:", projectiles.size())
		print(players)

	# --- Actualizar jugadores desde Network ---
	for key in Network.players.keys():
		var id = int(key)
		var data = Network.players[key]

		if id in players:
			var player_node = players[id]
			var target_pos = Vector2(data.x, data.y)

			if id != Network.player_id:
				# ⚙️ Solo actualiza a los demás jugadores
				player_node.position = target_pos

				# Actualizar animación de otros jugadores
				if data.has("animation_state"):
					var anim_name: String = data.animation_state
					if player_node.has_method("set_remote_animation"):
						player_node.set_remote_animation(anim_name)
			else:
				# ✅ Jugador local: interpolación suave para correcciones del servidor
				var current_pos = player_node.position
				var distance = current_pos.distance_to(target_pos)
				
				# Solo corregir si hay una diferencia significativa
				if distance > 10.0:
					# Interpolación lineal suave
					var correction_speed = 10.0  # Ajusta este valor para mayor/menor suavidad
					var new_pos = current_pos.lerp(target_pos, correction_speed * _delta)
					player_node.position = new_pos
					
					if Engine.get_frames_drawn() % 60 == 0:  # Debug cada segundo aprox
						print("🔄 Corrección posición - Distancia:", distance, " Nueva:", new_pos)

			# Actualizar HP de todos los jugadores
			_update_player_hp(player_node, data.hp, id)
		else:
			print("👤 SPAWNEANDO JUGADOR - ID:", id, " Username:", data.username)
			_spawn_player(id, data.username, Vector2(data.x, data.y), data.hp)

	# --- Actualizar enemigos ---
	for key in Network.enemies.keys():
		var id = int(key)
		var data = Network.enemies[key]
		if id in enemies:
			enemies[id].position = Vector2(data.x, data.y)
		else:
			print("👹 SPAWNEANDO ENEMIGO - ID:", id, " Tipo:", data.type)
			_spawn_enemy(id, data.type, Vector2(data.x, data.y))

	# --- Actualizar proyectiles ---
	for key in Network.projectiles.keys():
		var id = int(key)
		var data = Network.projectiles[key]
		if id not in projectiles:
			# Crear nuevo proyectil
			print("🎯 SPAWNEANDO PROYECTIL DESDE RED - ID:", id, " Owner:", data.owner_id)
			_spawn_projectile(id, data)

	# Los proyectiles remotos se mueven por sí mismos en su _process
	# No necesitamos actualizar su posición manualmente

	# --- Eliminar desconectados ---
	_cleanup_removed_entities()

# -------------------------------
# --- LIMPIEZA DE ENTIDADES ELIMINADAS
# -------------------------------
func _cleanup_removed_entities():
	# Jugadores eliminados
	var players_to_remove := []
	for id in players.keys():
		if not Network.players.has(str(id)):
			players_to_remove.append(id)
	
	for id in players_to_remove:
		print("👤 ELIMINANDO JUGADOR - ID:", id)
		if is_instance_valid(players[id]):
			players[id].queue_free()
		players.erase(id)

	# Enemigos eliminados
	var enemies_to_remove := []
	for id in enemies.keys():
		if not Network.enemies.has(str(id)):
			enemies_to_remove.append(id)
	
	for id in enemies_to_remove:
		print("👹 ELIMINANDO ENEMIGO - ID:", id)
		if is_instance_valid(enemies[id]):
			enemies[id].queue_free()
		enemies.erase(id)

	# Proyectiles eliminados
	var projectiles_to_remove := []
	for id in projectiles.keys():
		if not Network.projectiles.has(str(id)):
			projectiles_to_remove.append(id)
	
	for id in projectiles_to_remove:
		print("🗑️ ELIMINANDO PROYECTIL - ID:", id)
		destroy_projectile(id)

# -------------------------------
# --- DESTRUCCIÓN DE PROYECTILES
# -------------------------------
func destroy_projectile(projectile_id: int):
	if projectile_id in projectiles:
		var projectile = projectiles[projectile_id]
		if is_instance_valid(projectile):
			if projectile.has_method("on_hit_success"):
				projectile.on_hit_success()
			else:
				projectile.queue_free()
		projectiles.erase(projectile_id)
		print("🗑️ PROYECTIL DESTRUIDO - ID:", projectile_id)

# -------------------------------
# --- INPUT
# -------------------------------
func _unhandled_input(event):
	if not Network.connected or Network.player_id == -1:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var player = players.get(Network.player_id, null)
			if player and player.has_method("can_attack") and player.can_attack():
				print("🖱️ CLICK IZQUIERDO - Ataque cuerpo a cuerpo")
				_attack_near_target(get_global_mouse_position())

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			var player = players.get(Network.player_id, null)
			if player and player.has_method("can_attack") and player.can_attack():
				print("🖱️ CLICK DERECHO - Ataque a distancia")
				_attack_ranged_target(get_global_mouse_position())

	if event.is_action_pressed("roll"):
		var player = players.get(Network.player_id, null)
		if player and player.has_method("try_roll"):
			print("🎯 ROLL presionado")
			player.try_roll()

# -------------------------------
# --- ATAQUE
# -------------------------------
func _attack_near_target(mouse_pos: Vector2) -> void:
	var player = players.get(Network.player_id, null)
	if player == null:
		print("❌ ATAQUE FALLIDO - Jugador no encontrado")
		return

	var player_pos: Vector2 = player.global_position
	var player_facing: Vector2 = (mouse_pos - player_pos).normalized()
	var hit_something := false

	print("💥 INICIANDO ATAQUE CUERPO A CUERPO - Pos:", player_pos, " Mouse:", mouse_pos)

	# Ejecutar ataque del jugador
	if player.has_method("execute_attack"):
		player.execute_attack(mouse_pos)

	# Obtener propiedades de ataque del jugador
	var attack_range = 40.0
	var attack_cone_angle = deg_to_rad(45.0)
	var attack_damage = 10
	
	# Si el jugador tiene estas propiedades, usarlas
	if "attack_range" in player:
		attack_range = player.attack_range
	if "attack_cone_angle" in player:
		attack_cone_angle = player.attack_cone_angle
	if "attack_damage" in player:
		attack_damage = player.attack_damage

	# Detección de golpes
	for enemy_id in enemies.keys():
		var enemy = enemies[enemy_id]
		var to_enemy: Vector2 = enemy.position - player_pos
		var dist: float = to_enemy.length()

		if dist <= attack_range:
			var dir_to_enemy: Vector2 = to_enemy.normalized()
			var angle: float = player_facing.angle_to(dir_to_enemy)
			if abs(angle) <= attack_cone_angle:
				print("🎯 GOLPE A ENEMIGO - ID:", enemy_id, " Distancia:", dist)
				Network.attack("enemy", enemy_id, attack_damage)
				hit_something = true
				break

	if not hit_something:
		for player_id in players.keys():
			if player_id == Network.player_id:
				continue
			var other = players[player_id]
			var to_player: Vector2 = other.position - player_pos
			var dist_p: float = to_player.length()
			if dist_p <= attack_range:
				var dir_to_player: Vector2 = to_player.normalized()
				var angle_p: float = player_facing.angle_to(dir_to_player)
				if abs(angle_p) <= attack_cone_angle:
					print("🎯 GOLPE A JUGADOR - ID:", player_id, " Distancia:", dist_p)
					Network.attack("player", player_id, attack_damage)
					break


func _attack_ranged_target(mouse_pos: Vector2) -> void:
	# Verificar que estamos conectados y tenemos un ID válido
	if not Network.connected or Network.player_id == -1:
		print("❌ ATAQUE DISTANCIA FALLIDO - No conectado")
		return

	# Obtener el jugador local con verificación
	var player = players.get(Network.player_id, null)
	if player == null:
		print("❌ ATAQUE DISTANCIA FALLIDO - Jugador local no encontrado")
		return

	print("🎯 INICIANDO ATAQUE A DISTANCIA - Jugador ID:", Network.player_id)
	
	var player_pos: Vector2 = player.global_position
	var player_facing: Vector2 = (mouse_pos - player_pos).normalized()

	# Ejecutar animación de ataque
	if player.has_method("execute_attack"):
		player.execute_attack(mouse_pos)

	var attack_damage = 8
	if "attack_damage" in player:
		attack_damage = player.attack_damage

	_create_projectile(player, player_facing, attack_damage)

func _create_projectile(player: Node2D, direction: Vector2, damage: int):
	# Verificaciones exhaustivas
	if player == null:
		push_error("❌ Error: player es null")
		return
	
	if not player.is_inside_tree():
		push_error("❌ Error: player no está en el árbol de escena")
		return
	
	print("🚀 CREANDO PROYECTIL - Player:", Network.player_id, " Pos:", player.global_position, " Dir:", direction)
	
	# Enviar creación del proyectil al servidor
	Network.create_projectile(
		player.global_position.x, 
		player.global_position.y, 
		direction, 
		damage, 
		Network.player_id,
		400.0  # velocidad
	)

# -------------------------------
# --- SPAWN Y HP
# -------------------------------
func _spawn_player(id: int, username: String, pos: Vector2, hp: int = 100):
	var instance = PlayerScene.instantiate()
	
	# Generar posición aleatoria dentro de la pantalla
	var screen_size = get_viewport().get_visible_rect().size
	var random_x = randf_range(100, screen_size.x - 100) # Margen de 100 píxeles
	var random_y = randf_range(100, screen_size.y - 100)
	
	instance.position = Vector2(random_x, random_y)
	instance.name = str(id)
	
	# Asignar propiedades usando métodos
	if instance.has_method("set_player_id"):
		instance.set_player_id(id)
	elif "id" in instance:
		instance.id = id
	
	player_container.add_child(instance)
	players[id] = instance

	var name_label = instance.get_node_or_null("nombre")
	if name_label:
		name_label.text = username

	if id == Network.player_id:
		var cam = instance.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()
		print("🎯 JUGADOR LOCAL CREADO - ID:", id, " Pos:", instance.position)
	
	var bar = instance.get_node_or_null("ProgressBar")
	if bar:
		bar.max_value = 100
		bar.value = hp
		bar.queue_redraw()

func _spawn_enemy(id: int, _enemy_type: String, pos: Vector2):
	var instance = EnemyScene.instantiate()
	instance.position = pos
	instance.name = str(id)
	enemy_container.add_child(instance)
	enemies[id] = instance

func _spawn_projectile(id: int, data: Dictionary):
	if ProjectileScene == null:
		push_error("❌ ProjectileScene no asignada")
		return
	
	var projectile = ProjectileScene.instantiate()
	if projectile == null:
		push_error("❌ Error al instanciar proyectil")
		return
	
	projectile.name = str(id)
	projectile.position = Vector2(data.x, data.y)
	
	# DETERMINAR SI ES LOCAL O REMOTO MEJORADO
	var is_local_projectile = (data.owner_id == Network.player_id)
	var direction = Vector2(data.direction_x, data.direction_y)
	
	print("🎯 CONFIGURANDO PROYECTIL - ID:", id, " Owner:", data.owner_id, " LocalPlayer:", Network.player_id, " IsLocal:", is_local_projectile, " Dir:", direction)
	
	if projectile.has_method("initialize"):
		projectile.initialize(id, direction, data.damage, data.owner_id, not is_local_projectile)
	else:
		# Si no tiene método initialize, configurar propiedades directamente
		projectile.set("projectile_id", id)
		projectile.set("projectile_direction", direction.normalized())
		projectile.set("projectile_damage", data.damage)
		projectile.set("projectile_owner_id", data.owner_id)
		projectile.set("is_remote", not is_local_projectile)
		projectile.set("projectile_speed", data.speed if data.has("speed") else 400.0)
	
	add_child(projectile)
	projectiles[id] = projectile
	
	print("✅ PROYECTIL CREADO - ID:", id, " Owner:", data.owner_id, " Remote:", not is_local_projectile, " Speed:", projectile.get("projectile_speed"))

func update_player_hp(id: int, hp_value: int):
	var player = players.get(id, null)
	if not player:
		return

	var bar = player.get_node_or_null("ProgressBar")
	if bar:
		bar.value = clamp(hp_value, 0, 100)
		bar.queue_redraw()
		if id == Network.player_id and bar.value <= 0:
			print("[GAME OVER] Jugador muerto. Cerrando juego...")
			get_tree().quit()

func _update_player_hp(player: Node2D, hp_value: int, id: int):
	update_player_hp(id, hp_value)
	if id == Network.player_id:
		print("[HP UPDATE] Jugador local HP:", hp_value)
	else:
		print("[HP UPDATE] Jugador", id, "HP:", hp_value)

# -------------------------------
# --- MANEJO DE PROYECTILES
# -------------------------------
func _on_projectile_created(projectile_data):
	print("📡 Señal: Proyectil creado recibido del servidor")

func _on_projectile_moved(projectile_data):
	print("📡 Señal: Proyectil movido recibido del servidor")

func _on_projectile_removed(projectile_id):
	print("📡 Señal: Proyectil removido recibido del servidor:", projectile_id)
	destroy_projectile(projectile_id)

# -------------------------------
# --- LOGIN
# -------------------------------
func _on_login_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	if username != "" and password != "":
		print("🔐 Iniciando login con usuario:", username)
		Network.login_user(username, password)

func _on_login_successful():
	print("✅ Login exitoso, iniciando video de introducción...")
	vbox_container.visible = false
	vbox_container_2.visible = false
	video_stream_player.stop()
	video_stream_player.stream = load("res://Segunda-Parte-video-por-frame.ogv")
	video_stream_player.loop = false
	video_stream_player.autoplay = false
	video_stream_player.visible = true
	label.visible = false
	video_stream_player.play()
	await video_stream_player.finished
	video_stream_player.visible = false
	canvas_layer.visible = false
	canvas_layer.process_mode = Node.PROCESS_MODE_DISABLED

# -------------------------------
# --- CHAT
# -------------------------------
func _on_chat_send_pressed():
	var text = chat_input.text.strip_edges()
	if text != "":
		Network.send_chat(text)
		chat_input.text = ""

# -------------------------------
# --- BOTONES EXTRA
# -------------------------------
func _on_button_pressed() -> void:
	vbox_container.visible = false
	vbox_container_2.visible = true

func _on_button_4_pressed() -> void:
	get_tree().quit()

func _on_button_3_pressed() -> void:
	vbox_container.visible = false
	vbox_container_3.visible = true

# -------------------------------
# --- CONEXIÓN POR IP
# -------------------------------
func _on_button_ip_pressed() -> void:
	var ip = server_ip.text.strip_edges()
	if ip == "":
		print("⚠️ Debes ingresar una IP antes de conectar.")
		return
	print("🌐 Intentando conectar a:", ip)
	Network.connect_with_ip(ip)
	vbox_container.visible = true
	vbox_container_3.visible = false