extends Node2D

# -------------------------------
# --- NODOS
# -------------------------------
@onready var player_container = $PlayerContainer
@onready var enemy_container = $EnemyContainer

# UI
@onready var login_ui = $CanvasLayer/Pantalla_Inicial
@onready var chat_ui = $CanvasLayer/ChatUI
@onready var class_selection_ui = $CanvasLayer/ClassSelection
@onready var waiting_room_ui: Control = $CanvasLayer/contrl
@onready var titulo_intro: AnimationPlayer = $CanvasLayer/contrl/Titulo_Intro
@onready var loading_screen: Control = $CanvasLayer/LoadingScreen
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

# Botones de clase
@onready var warrior_button: Button = $CanvasLayer/contrl/HBoxContainer3/AspectRatioContainer/MarginContainer/Select
@onready var mage_button: Button = $CanvasLayer/contrl/HBoxContainer3/VBoxContainer3/MarginContainer/Select2
@onready var archer_button: Button = $CanvasLayer/contrl/HBoxContainer3/VBoxContainer/MarginContainer/Select3
@onready var rogue_button: Button = $CanvasLayer/contrl/HBoxContainer3/VBoxContainer2/MarginContainer/Select4

@onready var waiting_label: Button = $CanvasLayer/contrl/Ready

# Nodos dentro de contrl (sala de espera)
var players_list: VBoxContainer
var start_countdown: Label
var room_title: Label

# Nodos de pantalla de carga
@onready var loading_progress: ProgressBar = $CanvasLayer/LoadingScreen/ProgressBar
@onready var loading_text: Label = $CanvasLayer/LoadingScreen/LoadingText
@onready var loading_animation: AnimatedSprite2D = $CanvasLayer/LoadingScreen/AnimatedSprite2D

# -------------------------------
# --- PROYECTILES POR CLASE
# -------------------------------
var class_projectiles := {
	"warrior": preload("res://projectiles/WarriorProjectile.tscn"),
	"mage": preload("res://projectiles/MageProjectile.tscn"),
	"archer": preload("res://projectiles/ArcherProjectile.tscn"),
	"rogue": preload("res://projectiles/RogueProjectile.tscn")
}

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

# Variables de espera
var class_chosen: bool = false
var game_started: bool = false
var countdown_timer: float = 0.0
var countdown_active: bool = false
var minimum_wait_time: float = 10 # Mínimo 10 segundos para elegir clase
var wait_timer: float = 0.0
var loading_complete: bool = false

# -------------------------------
# --- INICIO
# -------------------------------
func _ready():
	# Conectar botones UI
	login_button.pressed.connect(_on_login_pressed)
	chat_send.pressed.connect(_on_chat_send_pressed)
	button_ip.pressed.connect(_on_button_ip_pressed)
	
	# Conectar botones de clase
	warrior_button.pressed.connect(_on_warrior_selected)
	mage_button.pressed.connect(_on_mage_selected)
	archer_button.pressed.connect(_on_archer_selected)
	rogue_button.pressed.connect(_on_rogue_selected)

	# Configurar UI inicial
	chat_ui.visible = false
	vbox_container_2.visible = false
	vbox_container_3.visible = false
	class_selection_ui.visible = false
	waiting_room_ui.visible = false
	loading_screen.visible = false

	# Conectar señales de Network
	Network.login_successful.connect(_on_login_successful)
	Network.connection_successful.connect(_on_connection_successful)
	Network.connection_failed.connect(_on_connection_failed)
	Network.game_state_updated.connect(_on_game_state_updated)
	Network.player_joined.connect(_on_player_joined)
	Network.player_left.connect(_on_player_left)
		
	# Conectar señales de proyectiles
	Network.projectile_created.connect(_on_projectile_created)
	Network.projectile_moved.connect(_on_projectile_moved)
	Network.projectile_removed.connect(_on_projectile_removed)

	# Configurar sala de espera
	_setup_waiting_room()
	
	print("🎮 Main listo - Esperando conexión...")

# -------------------------------
# --- PANTALLA DE CARGA
# -------------------------------
func _show_loading_screen():
	print("🔄 Mostrando pantalla de carga...")
	loading_screen.visible = true
	loading_progress.value = 0
	loading_text.text = "Conectando al servidor..."
	
	if loading_animation:
		loading_animation.play("loading")
	
	# Simular progreso de carga
	var tween = create_tween()
	tween.tween_method(_update_loading_progress, 0.0, 100.0, 3.0)
	await tween.finished
	
	loading_complete = true
	loading_screen.visible = false
	print("✅ Carga completada")

func _update_loading_progress(value: float):
	loading_progress.value = value
	if value < 30:
		loading_text.text = "Estableciendo conexión..."
	elif value < 60:
		loading_text.text = "Autenticando..."
	elif value < 90:
		loading_text.text = "Cargando recursos..."
	else:
		loading_text.text = "¡Listo!"

# -------------------------------
# --- CONFIGURACIÓN SALA DE ESPERA
# -------------------------------
func _setup_waiting_room():
	# Buscar o crear nodos necesarios en contrl
	players_list = _get_or_create_node("PlayersList", VBoxContainer)
	start_countdown = _get_or_create_node("StartCountdown", Label)
	room_title = _get_or_create_node("RoomTitle", Label)
	
	# Configurar textos iniciales
	waiting_label.text = "Jugadores listos: 0/4"
	start_countdown.text = "Iniciando en: 5"
	start_countdown.visible = false
	room_title.text = "SALA DE ESPERA - Esperando jugadores"
	
	# Configurar estilos si es necesario
	if room_title is Label:
		room_title.add_theme_font_size_override("font_size", 24)
	if start_countdown is Label:
		start_countdown.add_theme_color_override("font_color", Color.GREEN)
		start_countdown.add_theme_font_size_override("font_size", 20)

func _get_or_create_node(node_name: String, node_type) -> Node:
	var node = waiting_room_ui.get_node_or_null(node_name)
	if node == null:
		print("⚠️ Nodo %s no encontrado en contrl, creando dinámicamente" % node_name)
		node = node_type.new()
		node.name = node_name
		waiting_room_ui.add_child(node)
	return node

# -------------------------------
# --- PROCESO PRINCIPAL
# -------------------------------
func _process(delta):
	if not Network.connected or Network.player_id == -1:
		return

	# Manejar countdown si está activo
	if countdown_active:
		countdown_timer -= delta
		if countdown_timer <= 0:
			countdown_active = false
			_start_game()
		else:
			start_countdown.text = "Iniciando en: %d" % ceil(countdown_timer)
		return

	# Si estamos en la sala de espera, actualizar la lista de jugadores
	if waiting_room_ui.visible and not game_started:
		_update_waiting_room()
		_check_start_conditions(delta)

	# Actualizar entidades del juego
	_update_game_entities()

	# Debug de estado
	if Engine.get_frames_drawn() % 180 == 0:
		print("📊 ESTADO - Jugadores:", Network.players.size(), " Enemigos:", enemies.size(), " Proyectiles:", projectiles.size())

func _update_game_entities():
	# --- Actualizar jugadores desde Network ---
	for key in Network.players.keys():
		var id = int(key)
		var data = Network.players[key]

		if id in players:
			var player_node = players[id]
			
			# ✅ ACTUALIZAR CLASE SI ES NECESARIO
			var current_classe = player_node.classe if "classe" in player_node else "warrior"
			var new_classe = data.get("classe", "warrior")
			
			if current_classe != new_classe and player_node.has_method("set_classe"):
				print("🔄 ACTUALIZANDO CLASE - Jugador:", id, " De:", current_classe, " A:", new_classe)
				player_node.set_classe(new_classe)

			if id != Network.player_id:
				# Solo actualiza a los demás jugadores
				player_node.position = Vector2(data.x, data.y)

				# Actualizar animación de otros jugadores
				if data.has("animation_state"):
					var anim_name: String = data.animation_state
					if player_node.has_method("set_remote_animation"):
						player_node.set_remote_animation(anim_name)

			# Actualizar HP de todos los jugadores
			_update_player_hp(player_node, data.hp, id)
		else:
			print("👤 SPAWNEANDO JUGADOR - ID:", id, " Username:", data.username, " Clase:", data.get("classe", "warrior"))
			_spawn_player(id, data.username, Vector2(data.x, data.y), data.hp, data.get("classe", "warrior"))

	# --- Actualizar enemigos ---
	for key in Network.enemies.keys():
		var id = int(key)
		var data = Network.enemies[key]
		if id in enemies:
			enemies[id].position = Vector2(data.x, data.y)
			# Actualizar HP de enemigos
			if data.has("hp") and enemies[id].has_method("update_hp"):
				enemies[id].update_hp(data.hp)
		else:
			print("👹 SPAWNEANDO ENEMIGO - ID:", id, " Tipo:", data.type)
			# _spawn_enemy(id, data.type, Vector2(data.x, data.y))

	# --- Actualizar proyectiles ---
	for key in Network.projectiles.keys():
		var id = int(key)
		var data = Network.projectiles[key]
		if id not in projectiles:
			# Crear nuevo proyectil
			print("🎯 SPAWNEANDO PROYECTIL DESDE RED - ID:", id, " Owner:", data.owner_id, " Clase:", data.get("classe", "warrior"))
			_spawn_projectile(id, data)

	# --- Eliminar desconectados ---
	_cleanup_removed_entities()

# -------------------------------
# --- SALA DE ESPERA MEJORADA
# -------------------------------
func _update_waiting_room():
	# Limpiar lista actual
	if players_list:
		for child in players_list.get_children():
			child.queue_free()
	
	# Agregar jugadores a la lista
	var ready_count = 0
	var total_players = Network.players.size()
	
	if total_players == 0:
		if waiting_label:
			waiting_label.text = "Esperando jugadores... 0/4"
		return
	
	for player_id in Network.players:
		var player_data = Network.players[player_id]
		
		if players_list:
			var player_item = HBoxContainer.new()
			player_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var name_label = Label.new()
			name_label.text = player_data.username
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			var class_label = Label.new()
			if player_data.classe == "warrior" and player_data.classe != "":
				class_label.text = player_data.classe.capitalize()
				ready_count += 1
			else:
				class_label.text = "Eligiendo..."
			class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			var status_label = Label.new()
			if player_data.classe == "warrior" and player_data.classe != "":
				status_label.text = "✅ Listo"
				status_label.add_theme_color_override("font_color", Color.GREEN)
			else:
				# Mostrar tiempo restante para elegir
				var time_left = max(0, minimum_wait_time - wait_timer)
				status_label.text = "⏳ %ds" % ceil(time_left)
				status_label.add_theme_color_override("font_color", Color.YELLOW)
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			
			player_item.add_child(name_label)
			player_item.add_child(class_label)
			player_item.add_child(status_label)
			players_list.add_child(player_item)
	
	# Actualizar texto de espera
	if waiting_label:
		var time_left = max(0, minimum_wait_time - wait_timer)
		if total_players >= 2:
			waiting_label.text = "Jugadores listos: %d/%d\nTiempo mínimo: %ds" % [ready_count, total_players, ceil(time_left)]
		else:
			waiting_label.text = "Esperando más jugadores... %d/2" % total_players
	
	# Mostrar información del countdown si está activo
	if start_countdown:
		start_countdown.visible = countdown_active
	
	if room_title:
		if countdown_active:
			room_title.text = "¡SALA LLENA! Iniciando partida..."
		elif total_players >= 2:
			room_title.text = "SALA LLENA - Esperando que todos elijan clase"
		else:
			room_title.text = "SALA DE ESPERA - Esperando %d/2 jugadores" % (2 - total_players)

func _check_start_conditions(delta: float):
	if waiting_room_ui.visible and not game_started:
		wait_timer += delta
	
	var ready_players = 0
	var total_players = Network.players.size()
	
	if total_players == 0:
		return
	
	# Contar jugadores con clase elegida
	for player_id in Network.players:
		var player_data = Network.players[player_id]
		if player_data.classe != "warrior" and player_data.classe != "":
			ready_players += 1
	
	# Debug cada 2 segundos
	if Engine.get_frames_drawn() % 120 == 0:
		print("🔍 Verificando inicio - Listos: %d/%d - Tiempo: %.1f/%.1f" % [ready_players, total_players, wait_timer, minimum_wait_time])
	
	# CONDICIÓN PRINCIPAL: Mínimo 4 jugadores listos y tiempo cumplido
	var can_start = (ready_players == 2 and
					total_players == 2 and
					wait_timer >= minimum_wait_time and
					not countdown_active and
					not game_started)
	
	if can_start:
		_start_countdown()
	elif countdown_active and (ready_players < 5 or total_players < 5):
		# Cancelar countdown si ya no se cumplen las condiciones
		countdown_active = false
		if start_countdown:
			start_countdown.visible = false
		print("❌ Countdown cancelado - No hay suficientes jugadores listos")

func _start_countdown():
	print("🚀 %d JUGADORES LISTOS - Iniciando countdown..." % Network.players.size())
	countdown_active = true
	countdown_timer = 5.0 # 5 segundos
	if start_countdown:
		start_countdown.visible = true
		start_countdown.text = "Iniciando en: 5"

# -------------------------------
# --- INICIO DEL JUEGO
# -------------------------------
func _start_game():
	print("🎮 INICIANDO JUEGO CON %d JUGADORES!" % Network.players.size())
	game_started = true
	countdown_active = false
	waiting_room_ui.visible = false
	
	# Reproducir video de introducción y comenzar el juego
	_play_intro_video()

func _play_intro_video():
	print("🎬 Reproduciendo video de introducción...")
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
	chat_ui.visible = true
	
	# Habilitar controles del juego
	_set_game_ready(true)

func _set_game_ready(ready: bool):
	print("🎯 JUEGO %s" % ("LISTO" if ready else "EN ESPERA"))
	# Aquí puedes agregar lógica adicional para habilitar/deshabilitar controles

# -------------------------------
# --- LOGIN Y CONEXIÓN
# -------------------------------
func _on_login_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	if username != "" and password != "":
		print("🔐 Iniciando login con usuario:", username)
		# Mostrar pantalla de carga antes del login
		_show_loading_screen()
		await loading_complete
		Network.login_user(username, password)

func _on_login_successful():
	print("✅ Login exitoso, mostrando selección de clase...")
	vbox_container.visible = false
	vbox_container_2.visible = false
	waiting_room_ui.visible = true
	titulo_intro.play()
	await titulo_intro.animation_finished
	# Reiniciar timer cuando un jugador se conecta
	wait_timer = 0.0
	class_chosen = false
	
	# Forzar sincronización de estado después de un breve delay
	await get_tree().create_timer(1.0).timeout
	Network.request_player_update()

func _on_connection_successful():
	print("✅ Conexión WebSocket establecida")

func _on_connection_failed():
	print("❌ Falló la conexión al servidor")
	loading_screen.visible = false
	# Mostrar mensaje de error al usuario

func _on_game_state_updated():
	# Esta función se llama cuando el estado del juego cambia
	pass

func _on_player_joined(player_data):
	print("👤 Jugador unido desde señal:", player_data.username)

func _on_player_left(player_id):
	print("🚪 Jugador salió desde señal:", player_id)

# -------------------------------
# --- SELECCIÓN DE CLASE
# -------------------------------
func _on_warrior_selected():
	_select_class("knight")

func _on_mage_selected():
	_select_class("mage")

func _on_archer_selected():
	_select_class("archer")

func _on_rogue_selected():
	_select_class("rogue")

func _select_class(classe: String):
	if class_chosen:
		return
	
	print("🎯 Clase seleccionada:", classe)
	class_chosen = true
	Network.choose_class(classe)
	
	# Mostrar confirmación
	if waiting_label:
		waiting_label.text = "¡Clase %s seleccionada!\nEsperando otros jugadores..." % classe.capitalize()

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

# -------------------------------
# --- SPAWN DE ENTIDADES
# -------------------------------
func _spawn_player(id: int, username: String, pos: Vector2, hp: int = 100, classe: String = "warrior"):
	var instance = PlayerScene.instantiate()
	
	# Tamaño de la pantalla
	var screen_size = get_viewport().get_visible_rect().size
	var center = screen_size / 2
	
	# Definir área de spawn reducida (ej: 40% del tamaño de pantalla)
	var spawn_width = screen_size.x * 0.4
	var spawn_height = screen_size.y * 0.4
	
	# Calcular posición aleatoria dentro del área central
	var random_x = randf_range(center.x - spawn_width / 2, center.x + spawn_width / 2)
	var random_y = randf_range(center.y - spawn_height / 2, center.y + spawn_height / 2)
	
	instance.position = Vector2(random_x, random_y)
	instance.name = str(id)
	
	# Resto del código igual...
	
	# Asignar propiedades usando métodos
	if instance.has_method("set_player_id"):
		instance.set_player_id(id)
	
	# ASIGNAR CLASE PRIMERO antes de agregar a la escena
	if instance.has_method("set_classe"):
		instance.set_classe(classe)
		print("🎯 CLASE ASIGNADA AL JUGADOR - ID:", id, " Clase:", classe)
	
	player_container.add_child(instance)
	players[id] = instance

	var name_label = instance.get_node_or_null("nombre")
	if name_label:
		name_label.text = username

	if id == Network.player_id:
		var cam = instance.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()
		print("🎯 JUGADOR LOCAL CREADO - ID:", id, " Pos:", instance.position, " Clase:", classe)
	else:
		print("👤 JUGADOR REMOTO CREADO - ID:", id, " Clase:", classe)
	
	# Configurar barra de vida
	_update_player_hp(instance, hp, id)

# func _spawn_enemy(id: int, _enemy_type: String, pos: Vector2):
#   var instance = EnemyScene.instantiate()
#   instance.position = pos
#   instance.name = str(id)
#   enemy_container.add_child(instance)
#   enemies[id] = instance

func _spawn_projectile(id: int, data: Dictionary):
	var projectile_scene: PackedScene
	
	# Determinar qué proyectil instanciar basado en la clase
	var classe = data.get("classe", "warrior")
	if class_projectiles.has(classe):
		projectile_scene = class_projectiles[classe]
		print("🎯 Usando proyectil específico para clase:", classe)
	else:
		projectile_scene = ProjectileScene # Fallback
		print("⚠️ Usando proyectil por defecto para clase:", classe)

	if projectile_scene == null:
		push_error("❌ ProjectileScene no asignada para clase:", classe)
		return
	
	var projectile = projectile_scene.instantiate()
	if projectile == null:
		push_error("❌ Error al instanciar proyectil")
		return
	
	projectile.name = str(id)
	projectile.position = Vector2(data.x, data.y)
	
	var is_local_projectile = (data.owner_id == Network.player_id)
	var direction = Vector2(data.direction_x, data.direction_y)
	
	print("🎯 CONFIGURANDO PROYECTIL - ID:", id, " Clase:", classe, " Owner:", data.owner_id, " IsLocal:", is_local_projectile)
	
	if projectile.has_method("initialize"):
		projectile.initialize(id, direction, data.damage, data.owner_id, not is_local_projectile)
	else:
		# Configuración estándar
		projectile.set("projectile_id", id)
		projectile.set("projectile_direction", direction.normalized())
		projectile.set("projectile_damage", data.damage)
		projectile.set("projectile_owner_id", data.owner_id)
		projectile.set("is_remote", not is_local_projectile)
		projectile.set("projectile_speed", data.speed if data.has("speed") else 400.0)
	
	add_child(projectile)
	projectiles[id] = projectile
	
	print("✅ PROYECTIL CREADO - ID:", id, " Tipo:", classe, " Remote:", not is_local_projectile)

# -------------------------------
# --- SISTEMA DE VIDA
# -------------------------------
func update_player_hp(id: int, hp_value: int):
	var player = players.get(id, null)
	if not player:
		return

	if player.has_method("update_hp"):
		player.update_hp(hp_value)
	else:
		var bar = player.get_node_or_null("ProgressBar")
		if bar:
			var max_hp = player.max_hp if "max_hp" in player else 100
			bar.max_value = max_hp
			bar.value = clamp(hp_value, 0, max_hp)
			bar.queue_redraw()
			
	if id == Network.player_id and hp_value <= 0:
		print("[GAME OVER] Jugador muerto. Cerrando juego...")
		get_tree().quit()

func _update_player_hp(player: Node2D, hp_value: int, id: int):
	update_player_hp(id, hp_value)
	if id == Network.player_id:
		print("[HP UPDATE] Jugador local HP:", hp_value)
	else:
		print("[HP UPDATE] Jugador", id, "HP:", hp_value)

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
# --- INPUT (MODIFICADO PARA CLASES)
# -------------------------------
func _unhandled_input(event):
	if not Network.connected or Network.player_id == -1 or not game_started:
		return
	

	print("TEST")
	print(players.get(Network.player_id, null))

	# CLICK IZQUIERDO - Ataque según clase
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var player = players.get(Network.player_id, null)
		if player and player.has_method("can_attack") and player.can_attack():
			var player_classe = player.classe if "classe" in player else "warrior"
			
			# Warrior y Rogue - Ataque cuerpo a cuerpo
			if player_classe == "warrior" or player_classe == "rogue" or player_classe == "knight":
				print("🖱️ CLICK IZQUIERDO - Ataque cuerpo a cuerpo (" + player_classe + ")")
				_attack_near_target(get_global_mouse_position())
			
			# Mage y Archer - Ataque a distancia
			elif player_classe == "mage" or player_classe == "archer":
				print("🖱️ CLICK IZQUIERDO - Ataque a distancia (" + player_classe + ")")
				_attack_ranged_target(get_global_mouse_position())

	# ELIMINAR el click derecho para ataques (opcional - puedes mantenerlo para otra función)
	# if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
	#     if event.pressed:
	#         var player = players.get(Network.player_id, null)
	#         if player and player.has_method("can_attack") and player.can_attack():
	#             print("🖱️ CLICK DERECHO - Función alternativa")
	#             # Aquí puedes poner otra función como habilidad especial, etc.

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
		print("❌ ATAQUE CUERPO A CUERPO FALLIDO - Jugador no encontrado")
		return

	var player_classe = player.classe if "classe" in player else "warrior"
	var player_pos: Vector2 = player.global_position
	var player_facing: Vector2 = (mouse_pos - player_pos).normalized()
	var hit_something := false

	print("💥 ATAQUE CUERPO A CUERPO - Clase: " + player_classe + " Pos:", player_pos)

	# Ejecutar ataque del jugador
	if player.has_method("execute_attack"):
		player.execute_attack(mouse_pos)

	# Propiedades de ataque específicas por clase
	var attack_range = 40.0
	var attack_cone_angle = deg_to_rad(45.0)
	var attack_damage = 10
	
	# Ajustar propiedades según clase
	match player_classe:
		"warrior":
			attack_range = 50.0
			attack_damage = 15
			attack_cone_angle = deg_to_rad(60.0)
		"rogue":
			attack_range = 35.0
			attack_damage = 12
			attack_cone_angle = deg_to_rad(90.0) # Más ángulo para rogue

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
	if not Network.connected or Network.player_id == -1 or not game_started:
		print("❌ ATAQUE DISTANCIA FALLIDO - No conectado o juego no iniciado")
		return

	var player = players.get(Network.player_id, null)
	if player == null:
		print("❌ ATAQUE DISTANCIA FALLIDO - Jugador local no encontrado")
		return

	var player_classe = player.classe if "classe" in player else "mage"
	print("🎯 ATAQUE A DISTANCIA - Clase: " + player_classe + " Jugador ID:", Network.player_id)
	
	var player_pos: Vector2 = player.global_position
	var player_facing: Vector2 = (mouse_pos - player_pos).normalized()

	# Ejecutar animación de ataque
	if player.has_method("execute_attack"):
		player.execute_attack(mouse_pos)

	# Daño específico por clase
	var attack_damage = 8
	match player_classe:
		"mage":
			attack_damage = 10
		"archer":
			attack_damage = 12

	_create_projectile(player, player_facing, attack_damage)

func _create_projectile(player: Node2D, direction: Vector2, damage: int):
	if player == null:
		push_error("❌ Error: player es null")
		return
	
	if not player.is_inside_tree():
		push_error("❌ Error: player no está en el árbol de escena")
		return
	
	# Obtener la clase del jugador para determinar el proyectil
	var player_classe = "warrior"
	if "classe" in player:
		player_classe = player.classe
	
	print("🚀 CREANDO PROYECTIL - Player:", Network.player_id, " Clase:", player_classe, " Pos:", player.global_position, " Dir:", direction)
	
	# Enviar creación del proyectil al servidor (incluyendo la clase)
	Network.create_projectile(
		player.global_position.x,
		player.global_position.y,
		direction,
		damage,
		Network.player_id,
		400.0,
		player_classe
	)

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
