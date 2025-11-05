extends Node2D

# -------------------------------
# --- NODOS
# -------------------------------
@onready var player_container = $PlayerContainer
@onready var enemy_container = $EnemyContainer
@onready var object_container = $ObjectContainer
@onready var base_container = $BaseContainer
@onready var wave_manager = $WaveManager
@onready var decision_system = $DecisionSystem

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
@export var GhostScene: PackedScene
@export var BarrelScene: PackedScene
@export var BossScene: PackedScene
@export var BaseScene: PackedScene

# -------------------------------
# --- VARIABLES DE JUEGO
# -------------------------------
var players := {} # id:int -> Node2D
var enemies := {} # id:int -> Node2D
var projectiles := {} # id:int -> Node2D
var ghosts := {} # id:int -> Node2D
var possessable_objects := {}
var bases := {} # team:int -> Node2D

# Variables de espera
var class_chosen: bool = false
var game_started: bool = false
var countdown_timer: float = 0.0
var countdown_active: bool = false
var minimum_wait_time: float = 10 # Mínimo 10 segundos para elegir clase
var wait_timer: float = 0.0
var loading_complete: bool = false

# NUEVAS VARIABLES PARA SISTEMA DE EQUIPOS Y VICTORIA
var player_teams := {} # id -> team
var team_counts := {1: 0, 2: 0}
var game_start_countdown := 0
var respawn_timers := {} # player_id -> time_left
var local_player_team := 0
var MAX_PLAYERS_PER_TEAM = 2

# -------------------------------
# --- INICIO
# -------------------------------
func _ready():
	# Agregar este nodo al grupo "main" para que los fantasmas puedan encontrarlo
	add_to_group("main")
	
	# Conectar botones UI
	login_button.pressed.connect(_on_login_pressed)
	chat_send.pressed.connect(_on_chat_send_pressed)
	button_ip.pressed.connect(_on_button_ip_pressed)
	
	# Conectar botones de clase
	warrior_button.pressed.connect(_on_warrior_selected)
	mage_button.pressed.connect(_on_mage_selected)
	archer_button.pressed.connect(_on_archer_selected)
	rogue_button.pressed.connect(_on_rogue_selected)

	# ❌ ELIMINADO: Conexión duplicada - Network.decision_period_started.connect(_on_decision_period_started)

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
	Network.on_player_became_ghost.connect(_on_player_became_ghost)
	Network.on_object_destroyed.connect(_on_object_destroyed_sync)
	Network.on_ghost_possession_started.connect(_on_ghost_possession_started)
	Network.on_ghost_possession_ended.connect(_on_ghost_possession_ended)
	Network.on_object_thrown.connect(_on_object_thrown)
	Network.wave_started.connect(_on_wave_started)
	Network.wave_ended.connect(_on_wave_ended)
	Network.boss_spawned.connect(_on_boss_spawned)
	Network.currency_updated.connect(_on_currency_updated)
	
	# ✅ MANTENER SOLO UNA CONEXIÓN:
	Network.decision_period_started.connect(_on_decision_period_started)
		
	# Conectar señales de proyectiles
	Network.projectile_created.connect(_on_projectile_created)
	Network.projectile_moved.connect(_on_projectile_moved)
	Network.projectile_removed.connect(_on_projectile_removed)

	# NUEVAS CONEXIONES PARA SISTEMA DE EQUIPOS Y VICTORIA
	Network.team_update.connect(_on_team_update)
	Network.team_selected.connect(_on_team_selected)
	Network.team_selection_failed.connect(_on_team_selection_failed)
	Network.game_starting.connect(_on_game_starting)
	Network.game_start_countdown.connect(_on_game_start_countdown)
	Network.game_started.connect(_on_game_started)
	Network.player_dead.connect(_on_player_dead)
	Network.respawn_countdown.connect(_on_respawn_countdown)
	Network.player_respawned.connect(_on_player_respawned)
	Network.game_over.connect(_on_game_over)
	Network.game_reset.connect(_on_game_reset)

	# Configurar sala de espera
	_setup_waiting_room()
	
	# Spawnear bases iniciales
	spawn_initial_bases()
	
	print("🎮 Main listo - Esperando conexión...")

# -------------------------------
# --- SISTEMA DE BASES
# -------------------------------
# En la función spawn_initial_bases, asegurar el acceso correcto:
func spawn_initial_bases():
	print("🏰 SPAWNEANDO BASES INICIALES...")
	
	# Posiciones fijas para las bases (ajustar según tu mapa)
	var base_positions = {
		1: Vector2(-450, 1900), # Base izquierda - Equipo 1
		2: Vector2(450, -1900) # Base derecha - Equipo 2
	}
	
	for team in [1, 2]:
		if BaseScene:
			var base = BaseScene.instantiate()
			base.position = base_positions[team]
			base.name = "Base_Team_" + str(team)
			
			# Configurar base
			if base.has_method("setup"):
				base.setup(team, 1000, 1000) # team, hp, max_hp
			
			base_container.add_child(base)
			bases[team] = base
			print("🏰 BASE CREADA - Equipo:", team, " Posición:", base_positions[team])
		else:
			push_error("❌ ERROR: BaseScene no asignada en el inspector de main.tscn")

# Función auxiliar para acceder de forma segura a los diccionarios
func get_dict_value_safe(dict: Dictionary, key, default_value = null):
	if dict.has(str(key)):
		return dict[str(key)]
	elif dict.has(key):
		return dict[key]
	else:
		return default_value

# Función para actualizar bases desde datos del servidor
func update_bases_from_server():
	if not Network.bases.is_empty():
		for team_str in Network.bases:
			var team = int(team_str)
			var base_data = Network.bases[team_str]
			
			if team in bases:
				var base_node = bases[team]
				if base_node and base_node.has_method("update_hp"):
					# Usar get() con valores por defecto para evitar errores
					var current_hp = base_data.get("hp", 1000)
					var max_hp = base_data.get("maxHp", base_data.get("max_hp", 1000))
					
					base_node.update_hp(current_hp)
					
					# Mostrar notificación si la base está siendo atacada
					if current_hp < max_hp:
						print("🏰 BASE %d BAJO ATAQUE - HP: %d/%d" % [team, current_hp, max_hp])

# -------------------------------
# --- SISTEMA DE OLEADAS (ACTUALIZADO PARA UI DEL JUGADOR)
# -------------------------------
func _on_wave_started(wave_number: int, enemy_count: int):
	print("🌊 OLEADA INICIADA: %d - Enemigos: %d" % [wave_number, enemy_count])
	
	# Notificar a TODOS los jugadores
	for player_id in players:
		var player = players[player_id]
		if player and player.has_method("update_wave_ui"):
			player.update_wave_ui(wave_number, enemy_count)

func _on_wave_ended():
	print("✅ OLEADA COMPLETADA")
	
	# Ocultar UI de oleada de todos los jugadores
	for player_id in players:
		var player = players[player_id]
		if player and player.has_method("hide_game_ui"):
			player.hide_game_ui()

func _on_boss_spawned(boss_data: Dictionary):
	print("👹 JEFE INTERMEDIO APARECE")
	# El servidor maneja el spawn del jefe, aquí solo mostramos notificación

func _on_currency_updated(amount: int):
	print("💰 MONEDAS ACTUALIZADAS: %d" % amount)
	
	# Actualizar monedas del jugador local
	var local_player = players.get(Network.player_id, null)
	if local_player and local_player.has_method("update_currency"):
		local_player.update_currency(amount)

func _on_decision_period_started(duration: float, currency: int, cards: Array):
	print("⏰ PERIODO DE DECISIONES - Duración: %.1fs, Monedas: %d, Cartas: %d" % [duration, currency, cards.size()])
	
	# Mostrar UI de decisiones al jugador local
	var local_player = players.get(Network.player_id, null)
	if local_player and local_player.has_method("show_decision_period"):
		local_player.show_decision_period(duration, currency, cards)

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

	# Debug del estado del juego
	if Engine.get_frames_drawn() % 180 == 0:
		print("🎮 DEBUG - Game Started:", game_started, " Canvas Visible:", canvas_layer.visible, " Canvas Process:", canvas_layer.process_mode)

	# Manejar countdown si está activo
	if countdown_active:
		countdown_timer -= delta
		if countdown_timer <= 0:
			countdown_active = false
			_start_game()
		else:
			if start_countdown:
				start_countdown.text = "Iniciando en: %d" % ceil(countdown_timer)
		return

	# Si estamos en la sala de espera, actualizar la lista de jugadores
	if waiting_room_ui.visible and not game_started:
		_update_waiting_room()
		_check_start_conditions(delta)

	# Actualizar entidades del juego
	_update_game_entities()

	# Actualizar bases desde datos del servidor
	update_bases_from_server()

	# Limpiar entidades eliminadas
	_cleanup_removed_entities()

	# Actualizar timers de respawn
	for player_id in respawn_timers.keys():
		# Los timers se actualizan principalmente desde el servidor,
		# pero podemos hacer una actualización visual suave aquí si es necesario
		pass

	# Debug de estado
	if Engine.get_frames_drawn() % 180 == 0:
		print("📊 ESTADO - Jugadores:", players.size(), " Enemigos:", enemies.size(), " Proyectiles:", projectiles.size(), " Fantasmas:", ghosts.size(), " Bases:", bases.size())

# -------------------------------
# --- ACTUALIZACIÓN DE ENTIDADES DEL JUEGO
# -------------------------------
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
			_spawn_enemy(id, data.type, Vector2(data.x, data.y))

	# --- Verificar enemigos eliminados ---
	_check_enemy_deaths()

	# --- Actualizar proyectiles ---
	for key in Network.projectiles.keys():
		var id = int(key)
		var data = Network.projectiles[key]
		if id not in projectiles:
			# Crear nuevo proyectil
			print("🎯 SPAWNEANDO PROYECTIL DESDE RED - ID:", id, " Owner:", data.owner_id, " Clase:", data.get("classe", "warrior"))
			_spawn_projectile(id, data)

# NUEVO: Verificar muertes de enemigos
func _check_enemy_deaths():
	# Buscar enemigos que estaban pero ya no están en Network.enemies
	for enemy_id in enemies.keys():
		if not Network.enemies.has(str(enemy_id)):
			var enemy = enemies[enemy_id]
			if enemy and is_instance_valid(enemy):
				# El enemigo fue eliminado, verificar quién lo mató
				_process_enemy_death(enemy_id, enemy)

# En main.gd, modificar _process_enemy_death:
func _process_enemy_death(enemy_id: int, enemy: Node):
	# ❌ ELIMINAR: No dar recompensa grupal aquí
	# El servidor ahora maneja las recompensas individuales
	var enemy_type = enemy.get_enemy_type() if enemy.has_method("get_enemy_type") else "grunt"
	print("💀 PROCESANDO MUERTE DE ENEMIGO - ID:", enemy_id, " Tipo:", enemy_type)
	
	# ❌ ELIMINADO: Recompensa grupal
	# El servidor ahora da recompensa solo al asesino

# -------------------------------
# --- SPAWN DE ENEMIGOS
# -------------------------------
func _spawn_enemy(id: int, type: String, pos: Vector2):
	var instance = EnemyScene.instantiate()
	instance.position = pos
	instance.name = str(id)
	
	if instance.has_method("set_enemy_id"):
		instance.set_enemy_id(id)
	if instance.has_method("set_enemy_type"):
		instance.set_enemy_type(type)
	
	enemy_container.add_child(instance)
	enemies[id] = instance
	print("👹 ENEMIGO CREADO - ID:", id, " Tipo:", type, " Pos:", pos)

# -------------------------------
# --- SISTEMA DE VISIBILIDAD DE FANTASMAS
# -------------------------------
func is_local_player_ghost() -> bool:
	return Network.player_id in ghosts

func update_all_ghosts_visibility():
	for ghost_id in ghosts:
		var ghost = ghosts[ghost_id]
		if ghost and ghost.has_method("_update_visibility"):
			ghost._update_visibility()

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
			waiting_label.text = "Esperando jugadores... 0/2"
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
			if player_data.classe != "warrior" and player_data.classe != "":
				class_label.text = player_data.classe.capitalize()
				ready_count += 1
			else:
				class_label.text = "Eligiendo..."
			class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			var status_label = Label.new()
			if player_data.classe != "warrior" and player_data.classe != "":
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
	
	# CONDICIÓN PRINCIPAL: Mínimo 2 jugadores listos y tiempo cumplido
	var can_start = (ready_players == 2 and
					total_players == 2 and
					wait_timer >= minimum_wait_time and
					not countdown_active and
					not game_started)
	
	if can_start:
		_start_countdown()
	elif countdown_active and (ready_players < 2 or total_players < 2):
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
# --- INICIO DEL JUEGO (CORREGIDO)
# -------------------------------
func _start_game():
	print("🎮 INICIANDO JUEGO CON %d JUGADORES!" % Network.players.size())
	game_started = true
	countdown_active = false
	waiting_room_ui.visible = false
	
	# ✅ CORREGIDO: Ocultar completamente la UI de sala de espera
	if waiting_room_ui:
		waiting_room_ui.visible = false
		waiting_room_ui.process_mode = Node.PROCESS_MODE_DISABLED
	
	# ✅ CORREGIDO: Reproducir video de introducción y luego iniciar juego
	await _play_intro_video()
	
	# Notificar al servidor que el juego puede comenzar
	Network.start_game_session()

func _play_intro_video():
	print("🎬 Reproduciendo video de introducción...")
	
	# ✅ CORREGIDO: Configurar y mostrar el video correctamente
	video_stream_player.stop()
	video_stream_player.stream = load("res://Segunda-Parte-video-por-frame.ogv")
	video_stream_player.loop = false
	video_stream_player.autoplay = false
	video_stream_player.visible = true
	
	# Ocultar otros elementos de UI
	label.visible = false
	login_ui.visible = false
	waiting_room_ui.visible = false
	
	# Reproducir video
	video_stream_player.play()
	
	# Esperar a que termine el video
	# await video_stream_player.finished
	
	# print("✅ Video de introducción terminado")
	
	# ✅ CORREGIDO: Ocultar el canvas layer COMPLETAMENTE después del video
	canvas_layer.visible = false
	canvas_layer.process_mode = Node.PROCESS_MODE_DISABLED
	
	# ✅ CORREGIDO: Asegurar que el juego esté listo
	_set_game_ready(true)

func _set_game_ready(ready: bool):
	print("🎯 JUEGO %s" % ("LISTO" if ready else "EN ESPERA"))
	
	if ready:
		# Habilitar controles del juego
		chat_ui.visible = true
		
		# Asegurar que el jugador local pueda moverse y atacar
		var local_player = players.get(Network.player_id, null)
		if local_player and local_player.has_method("set_game_started"):
			local_player.set_game_started(true)
	else:
		# Deshabilitar controles del juego
		chat_ui.visible = false

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
	
	# Mostrar selección de equipo después del login
	_update_team_selection_ui()
	
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
	_select_class("warrior")

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

	# Limpiar fantasmas
	_cleanup_ghosts_improved()
	
	var objects_to_remove = []
	for object_id in possessable_objects.keys():
		var object = possessable_objects[object_id]
		if not is_instance_valid(object):
			objects_to_remove.append(object_id)
	for object_id in objects_to_remove:
		possessable_objects.erase(object_id)

func _cleanup_ghosts_improved():
	var ghosts_to_remove = []
	for ghost_id in ghosts.keys():
		# Mantener al fantasma local incluso si no está en Network.players
		if ghost_id == Network.player_id:
			continue
		
		# Remover fantasmas cuyos jugadores ya no están conectados
		if not is_instance_valid(ghosts[ghost_id]) or not Network.players.has(str(ghost_id)):
			ghosts_to_remove.append(ghost_id)
	
	for ghost_id in ghosts_to_remove:
		print("👻 ELIMINANDO FANTASMA - ID:", ghost_id)
		if is_instance_valid(ghosts[ghost_id]):
			ghosts[ghost_id].queue_free()
		ghosts.erase(ghost_id)

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
# --- INPUT (CORREGIDO PARA ATAQUES)
# -------------------------------
func _unhandled_input(event):
	if not Network.connected or Network.player_id == -1 or not game_started:
		return

	# CLICK IZQUIERDO - Ataque según clase
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var player = players.get(Network.player_id, null)
		if player and player.has_method("can_attack") and player.can_attack():
			var player_classe = player.classe if "classe" in player else "warrior"
			
			# Warrior y Rogue - Ataque cuerpo a cuerpo
			if player_classe == "warrior" or player_classe == "rogue":
				print("🖱️ CLICK IZQUIERDO - Ataque cuerpo a cuerpo (" + player_classe + ")")
				_attack_near_target(get_global_mouse_position())
			
			# Mage y Archer - Ataque a distancia
			elif player_classe == "mage" or player_classe == "archer":
				print("🖱️ CLICK IZQUIERDO - Ataque a distancia (" + player_classe + ")")
				_attack_ranged_target(get_global_mouse_position())

	if event.is_action_pressed("roll"):
		var player = players.get(Network.player_id, null)
		if player and player.has_method("try_roll"):
			print("🎯 ROLL presionado")
			player.try_roll()

# -------------------------------
# --- ATAQUE CUERPO A CUERPO (CORREGIDO)
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

	# Ejecutar animación de ataque
	if player.has_method("execute_attack"):
		player.execute_attack(mouse_pos)

	# Propiedades de ataque específicas por clase
	var attack_range = 60.0 # AUMENTADO para mejor detección
	var attack_cone_angle = deg_to_rad(90.0) # AUMENTADO para mejor detección
	var attack_damage = 10
	
	# Ajustar propiedades según clase
	match player_classe:
		"warrior":
			attack_range = 80.0 # AUMENTADO
			attack_damage = 15
			attack_cone_angle = deg_to_rad(120.0) # AUMENTADO
		"rogue":
			attack_range = 60.0 # AUMENTADO
			attack_damage = 12
			attack_cone_angle = deg_to_rad(150.0) # AUMENTADO

	# DEBUG: Dibujar área de ataque (opcional)
	_draw_debug_attack_area(player_pos, player_facing, attack_range, attack_cone_angle)

	# Detección de golpes - PRIMERO enemigos
	for enemy_id in enemies.keys():
		var enemy = enemies[enemy_id]
		if not is_instance_valid(enemy):
			continue
			
		var to_enemy: Vector2 = enemy.position - player_pos
		var dist: float = to_enemy.length()

		if dist <= attack_range:
			var dir_to_enemy: Vector2 = to_enemy.normalized()
			var angle: float = player_facing.angle_to(dir_to_enemy)
			if abs(angle) <= attack_cone_angle:
				print("🎯 GOLPE A ENEMIGO - ID:", enemy_id, " Distancia:", dist, " Ángulo:", rad_to_deg(angle))
				Network.attack("enemy", enemy_id, attack_damage)
				hit_something = true
				# Solo un golpe por ataque
				break

	# Si no golpeó enemigos, buscar jugadores
	if not hit_something:
		for player_id in players.keys():
			if player_id == Network.player_id:
				continue
				
			var other = players[player_id]
			if not is_instance_valid(other):
				continue
				
			var to_player: Vector2 = other.position - player_pos
			var dist_p: float = to_player.length()
			if dist_p <= attack_range:
				var dir_to_player: Vector2 = to_player.normalized()
				var angle_p: float = player_facing.angle_to(dir_to_player)
				if abs(angle_p) <= attack_cone_angle:
					print("🎯 GOLPE A JUGADOR - ID:", player_id, " Distancia:", dist_p)
					Network.attack("player", player_id, attack_damage)
					hit_something = true
					break

	if not hit_something:
		print("❌ ATAQUE CUERPO A CUERPO NO GOLPEÓ NADA - Rango:", attack_range)

# Función de debug para visualizar el área de ataque
func _draw_debug_attack_area(center: Vector2, direction: Vector2, range: float, angle: float):
	# Esta función es opcional, ayuda a debuggear el área de ataque
	if not OS.is_debug_build():
		return
		
	# Crear líneas para visualizar el cono de ataque
	var points = PackedVector2Array()
	points.push_back(center)
	points.push_back(center + direction.rotated(angle) * range)
	points.push_back(center + direction.rotated(-angle) * range)
	points.push_back(center)
	
	# Dibujar temporalmente (esto requiere un nodo para dibujar)
	print("🔺 CONO DE ATAQUE - Centro:", center, " Dirección:", direction, " Rango:", range, " Ángulo:", rad_to_deg(angle))

# -------------------------------
# --- ATAQUE A DISTANCIA (CORREGIDO)
# -------------------------------
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
# --- CONVERSIÓN JUGADOR -> FANTASMA
# -------------------------------
func _on_player_became_ghost(player_id: int):
	print("👻 EVENTO: Jugador se convirtió en fantasma - ID:", player_id)
	replace_player_with_ghost(player_id)

func replace_player_with_ghost(player_id: int):
	# Verificar si el jugador existe
	if not player_id in players:
		print("❌ No se puede convertir a fantasma - Jugador no encontrado:", player_id)
		return
	if player_id in ghosts:
		print("⚠️ El jugador ya es un fantasma - ID:", player_id)
		return
	var player_node = players[player_id]
	var ghost_position = player_node.position
	
	# Eliminar jugador
	players.erase(player_id)
	if is_instance_valid(player_node):
		player_node.queue_free()
	
	# Crear fantasma
	var ghost = GhostScene.instantiate()
	ghost.position = ghost_position
	ghost.name = "Ghost_" + str(player_id)
	ghost.set_ghost_id(player_id)
	
	# Si es el jugador local, configurar como controlable
	if player_id == Network.player_id:
		ghost.set_is_local(true)
		print("🎮 FANTASMA LOCAL CREADO - ID:", player_id)
	
	player_container.add_child(ghost)
	ghosts[player_id] = ghost
	
	# Actualizar visibilidad de todos los fantasmas
	update_all_ghosts_visibility()
	
	print("👻 FANTASMA CREADO - ID:", player_id, " Posición:", ghost_position)

# -------------------------------
# --- MANEJO DE POSESIÓN DE OBJETOS
# -------------------------------
func _on_ghost_possession_started(player_id: int, object_name: String):
	print("🎯 POSESIÓN SINCRONIZADA - Ghost:", player_id, " Object:", object_name)
	var object = object_container.get_node_or_null(object_name)
	# Buscar objeto por nombre en lugar de ID de instancia
	if object and object.has_method("_start_possession_effect"):
		object._start_possession_effect()

func _on_ghost_possession_ended(player_id: int, object_name: String):
	print("🎯 POSESIÓN TERMINADA - Ghost:", player_id, " Object:", object_name)
	# Aquí podrías agregar efectos visuales o sonidos

func _on_object_thrown(object_name: String, direction: Vector2):
	print("🚀 OBJETO LANZADO SINCRONIZADO - Object:", object_name)
	var object = object_container.get_node_or_null(object_name)
	if object and object.has_method("throw"):
		if not object.is_possessed:
			object.throw(direction)

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

func _find_object_by_id(object_id: int) -> Node:
	"""Busca un objeto por su ID de instancia en el object_container"""
	if not object_container:
		return null
	for child in object_container.get_children():
		if child.get_instance_id() == object_id:
			return child
	return null

func _on_object_destroyed_sync(object_name: String):
	print("🗑️ DESTRUYENDO OBJETO SINCRONIZADO - Nombre:", object_name)
	var object = object_container.get_node_or_null(object_name)
	if object and is_instance_valid(object):
		object.queue_free()

# -------------------------------
# --- SISTEMA DE RECOMPENSAS POR KILLS
# -------------------------------
func _on_enemy_killed(enemy_id: int, killer_id: int, enemy_type: String):
	print("🎯 ENEMIGO ELIMINADO - ID:", enemy_id, " Por:", killer_id, " Tipo:", enemy_type)
	
	# Verificar si el asesino es un jugador
	if killer_id in players:
		var killer = players[killer_id]
		if killer and killer.has_method("add_currency_for_kill"):
			# Dar recompensa al jugador
			killer.add_currency_for_kill(enemy_type)
			
			print("💰 RECOMPENSA ENTREGADA - Jugador:", killer_id, " Mató:", enemy_type)

# -------------------------------
# --- NUEVAS FUNCIONES PARA SISTEMA DE EQUIPOS Y VICTORIA
# -------------------------------

func _on_team_update(new_team_counts: Dictionary, players_data: Array):
	team_counts = {
		1: safe_dict_access(new_team_counts, 1, 0),
		2: safe_dict_access(new_team_counts, 2, 0)
	}
	player_teams.clear()
	
	for player_data in players_data:
		player_teams[player_data.id] = player_data.team
	
	print("👥 EQUIPOS ACTUALIZADOS - Equipo 1:", team_counts[1], " Equipo 2:", team_counts[2])
	
	# Actualizar UI de selección de equipo si está visible
	if waiting_room_ui.visible:
		_update_team_selection_ui()

func _on_team_selected(team: int, position: Dictionary):
	local_player_team = team
	print("✅ EQUIPO LOCAL ASIGNADO - Equipo:", team, " Posición:", position)
	
	# Mover jugador local a la posición de la base
	if Network.player_id in players:
		players[Network.player_id].position = Vector2(position.x, position.y)

func _on_team_selection_failed(reason: String, team_counts: Dictionary):
	print("❌ ERROR AL SELECCIONAR EQUIPO:", reason)
	# Mostrar mensaje de error al usuario
	show_error_message("No se pudo unir al equipo: " + reason)

func _update_team_selection_ui():
	# Buscar o crear nodos para selección de equipo
	var team_selection_ui = waiting_room_ui.get_node_or_null("TeamSelection")
	if not team_selection_ui:
		team_selection_ui = VBoxContainer.new()
		team_selection_ui.name = "TeamSelection"
		waiting_room_ui.add_child(team_selection_ui)
	
	# Limpiar UI anterior
	for child in team_selection_ui.get_children():
		child.queue_free()
	
	# Crear botones de equipo
	var title = Label.new()
	title.text = "SELECCIONA TU EQUIPO"
	title.add_theme_font_size_override("font_size", 20)
	team_selection_ui.add_child(title)
	
	for team in [1, 2]:
		var team_button = Button.new()
		team_button.text = "EQUIPO %d (%d/%d)" % [team, team_counts.get(team, 0), MAX_PLAYERS_PER_TEAM]
		team_button.pressed.connect(_on_team_button_pressed.bind(team))
		
		# Deshabilitar si el equipo está lleno
		if team_counts.get(team, 0) >= MAX_PLAYERS_PER_TEAM:
			team_button.disabled = true
		
		team_selection_ui.add_child(team_button)

func _on_team_button_pressed(team: int):
	print("🎯 SELECCIONANDO EQUIPO:", team)
	Network.select_team(team)

# FUNCIONES PARA MANEJAR INICIO DEL JUEGO
func _on_game_starting(countdown: int):
	game_start_countdown = countdown
	print("🚀 JUEGO INICIANDO EN:", countdown, "segundos")
	
	# Mostrar countdown en UI
	if start_countdown:
		start_countdown.visible = true
		start_countdown.text = "Iniciando en: %d" % countdown

func _on_game_start_countdown(countdown: int):
	game_start_countdown = countdown
	if start_countdown:
		start_countdown.text = "Iniciando en: %d" % countdown

func _on_game_started():
	print("🎮 JUEGO INICIADO!")
	game_started = true
	waiting_room_ui.visible = false
	
	# Ocultar selección de equipos
	var team_selection_ui = waiting_room_ui.get_node_or_null("TeamSelection")
	if team_selection_ui:
		team_selection_ui.visible = false

# FUNCIONES PARA SISTEMA DE RESPAWN
func _on_player_dead(player_id: int, killer_id: int, respawn_time: int):
	print("💀 JUGADOR MUERTO - ID:", player_id, " Respawn en:", respawn_time, "s")
	
	if player_id == Network.player_id:
		# Mostrar UI de respawn para jugador local
		show_respawn_ui(respawn_time)
	
	# Iniciar timer de respawn
	respawn_timers[player_id] = respawn_time

func _on_respawn_countdown(player_id: int, time_left: int):
	respawn_timers[player_id] = time_left
	
	if player_id == Network.player_id:
		# Actualizar UI de respawn
		update_respawn_ui(time_left)

func _on_player_respawned(player_data: Dictionary):
	var player_id = player_data.id
	respawn_timers.erase(player_id)
	
	if player_id in players:
		# Actualizar posición y estado del jugador
		players[player_id].position = Vector2(player_data.x, player_data.y)
		players[player_id].hp = player_data.hp
		
		if player_id == Network.player_id:
			# Ocultar UI de respawn
			hide_respawn_ui()

# FUNCIONES PARA FIN DEL JUEGO - CORREGIDAS
func _on_game_over(winning_team: int, reason: String):
	print("🎯 JUEGO TERMINADO - Ganador: Equipo", winning_team, " Razón:", reason)
	game_started = false
	
	# Mostrar pantalla de victoria/derrota
	show_game_over_screen(winning_team, reason)
	
	# Programar regreso a la sala de espera después de 5 segundos
	await get_tree().create_timer(5.0).timeout
	_return_to_waiting_room()

func _on_game_reset(players_data: Dictionary, bases_data: Dictionary):
	print("🔄 JUEGO REINICIADO - Regresando a sala de espera")
	game_started = false
	
	# Limpiar entidades del juego
	_cleanup_all_entities()
	
	# Ocultar pantalla de game over si está visible
	hide_game_over_screen()
	
	# Volver a la sala de espera
	_return_to_waiting_room()

# NUEVAS FUNCIONES PARA LIMPIEZA Y REINICIO
func _cleanup_all_entities():
	print("🧹 LIMPIANDO TODAS LAS ENTIDADES...")
	
	# Limpiar jugadores
	for id in players:
		if is_instance_valid(players[id]):
			players[id].queue_free()
	players.clear()
	
	# Limpiar enemigos
	for id in enemies:
		if is_instance_valid(enemies[id]):
			enemies[id].queue_free()
	enemies.clear()
	
	# Limpiar proyectiles
	for id in projectiles:
		if is_instance_valid(projectiles[id]):
			projectiles[id].queue_free()
	projectiles.clear()
	
	# Limpiar fantasmas
	for id in ghosts:
		if is_instance_valid(ghosts[id]):
			ghosts[id].queue_free()
	ghosts.clear()
	
	# Resetear timers
	respawn_timers.clear()
	
	print("✅ TODAS LAS ENTIDADES LIMPIADAS")

func _return_to_waiting_room():
	print("🚪 REGRESANDO A SALA DE ESPERA")
	
	# Mostrar UI de sala de espera
	waiting_room_ui.visible = true
	waiting_room_ui.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Ocultar canvas de juego
	canvas_layer.visible = true
	canvas_layer.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Ocultar chat durante la espera
	chat_ui.visible = false
	
	# Resetear variables de juego
	game_started = false
	countdown_active = false
	class_chosen = false
	wait_timer = 0.0
	
	# Actualizar UI de sala de espera
	_update_waiting_room()
	
	print("✅ EN SALA DE ESPERA - Listo para nueva partida")

func show_game_over_screen(winning_team: int, reason: String):
	# Ocultar el juego
	canvas_layer.visible = true
	canvas_layer.process_mode = Node.PROCESS_MODE_INHERIT
	
	var game_over_ui = get_node_or_null("CanvasLayer/GameOverUI")
	if not game_over_ui:
		game_over_ui = Panel.new()
		game_over_ui.name = "GameOverUI"
		game_over_ui.size = Vector2(400, 300)
		game_over_ui.position = get_viewport().get_visible_rect().size / 2 - Vector2(200, 150)
		
		# Crear estilo para el panel
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0, 0, 0, 0.8)
		style_box.border_color = Color.GOLD
		style_box.border_width_left = 4
		style_box.border_width_right = 4
		style_box.border_width_top = 4
		style_box.border_width_bottom = 4
		game_over_ui.add_theme_stylebox_override("panel", style_box)
		
		var vbox = VBoxContainer.new()
		vbox.size = Vector2(380, 280)
		vbox.position = Vector2(10, 10)
		
		var title = Label.new()
		title.name = "Title"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 32)
		
		var reason_label = Label.new()
		reason_label.name = "Reason"
		reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason_label.add_theme_font_size_override("font_size", 18)
		
		var countdown_label = Label.new()
		countdown_label.name = "Countdown"
		countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		countdown_label.add_theme_font_size_override("font_size", 16)
		countdown_label.text = "Regresando a sala de espera en 5 segundos..."
		
		vbox.add_child(title)
		vbox.add_child(reason_label)
		vbox.add_child(countdown_label)
		game_over_ui.add_child(vbox)
		canvas_layer.add_child(game_over_ui)
	
	game_over_ui.visible = true
	
	# Mostrar mensaje de victoria/derrota
	var title = game_over_ui.get_node("VBoxContainer/Title")
	var reason_label = game_over_ui.get_node("VBoxContainer/Reason")
	
	if winning_team == local_player_team:
		title.text = "¡VICTORIA!"
		title.add_theme_color_override("font_color", Color.GOLD)
		print("🎉 VICTORIA DEL EQUIPO LOCAL")
	else:
		title.text = "¡DERROTA!"
		title.add_theme_color_override("font_color", Color.RED)
		print("💀 DERROTA DEL EQUIPO LOCAL")
	
	reason_label.text = reason

func hide_game_over_screen():
	var game_over_ui = get_node_or_null("CanvasLayer/GameOverUI")
	if game_over_ui:
		game_over_ui.visible = false
		game_over_ui.queue_free()

# FUNCIONES DE UI AUXILIARES
func show_respawn_ui(time: int):
	# Crear o mostrar UI de respawn
	var respawn_ui = get_node_or_null("CanvasLayer/RespawnUI")
	if not respawn_ui:
		respawn_ui = Panel.new()
		respawn_ui.name = "RespawnUI"
		respawn_ui.size = Vector2(300, 100)
		respawn_ui.position = Vector2(200, 200)
		
		var label = Label.new()
		label.name = "CountdownLabel"
		label.text = "Reapareciendo en: %d" % time
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		respawn_ui.add_child(label)
		
		canvas_layer.add_child(respawn_ui)
	
	respawn_ui.visible = true

func update_respawn_ui(time_left: int):
	var respawn_ui = get_node_or_null("CanvasLayer/RespawnUI")
	if respawn_ui:
		# Actualizar texto del countdown
		var label = respawn_ui.get_node_or_null("CountdownLabel")
		if label:
			label.text = "Reapareciendo en: %d" % time_left

func hide_respawn_ui():
	var respawn_ui = get_node_or_null("CanvasLayer/RespawnUI")
	if respawn_ui:
		respawn_ui.visible = false

func show_error_message(message: String):
	# Implementación básica de mensaje de error
	print("❌ ERROR:", message)
	# Aquí podrías mostrar un popup o mensaje en la UI

func safe_dict_access(dict: Dictionary, key, default_value = null):
	# Primero intentar con el tipo original
	if dict.has(key):
		return dict[key]
	# Luego intentar con string
	elif dict.has(str(key)):
		return dict[str(key)]
	# Finalmente devolver valor por defecto
	else:
		return default_value
