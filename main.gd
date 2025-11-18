#main.gd
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
@export var BossScene: PackedScene
@export var BaseScene: PackedScene

# -------------------------------
# --- VARIABLES DE JUEGO (PUBLICAS)
# -------------------------------

# CONFIGURACIÓN DE SPAWN
@export_group("Configuración de Spawn")
@export var spawn_area_percentage: float = 0.4  # 40% del área central para spawn
@export var base_positions: Dictionary = {      # Posiciones de las bases
	1: Vector2(-1600, -800),
	2: Vector2(1400, 400)
}

# CONFIGURACIÓN DE SALA DE ESPERA
@export_group("Configuración de Sala de Espera")
@export var minimum_wait_time: float = 10.0  # Mínimo 10 segundos para elegir clase
@export var game_start_countdown_time: float = 5.0  # 5 segundos de countdown

# CONFIGURACIÓN DE EQUIPOS
@export_group("Configuración de Equipos")
@export var MAX_PLAYERS_PER_TEAM: int = 2

# CONFIGURACIÓN DE ATAQUES
@export_group("Configuración de Ataques - Cuerpo a Cuerpo")
@export var warrior_attack_range: float = 80.0
@export var warrior_attack_damage: int = 15
@export var warrior_attack_cone_angle: float = 120.0

@export var rogue_attack_range: float = 60.0
@export var rogue_attack_damage: int = 12
@export var rogue_attack_cone_angle: float = 150.0

@export_group("Configuración de Ataques - A Distancia")
@export var mage_attack_damage: int = 10
@export var archer_attack_damage: int = 12
@export var projectile_speed: float = 400.0

# CONFIGURACIÓN DE BASES
@export_group("Configuración de Bases")
@export var base_health: int = 1000
@export var base_max_health: int = 1000

# CONFIGURACIÓN DE EFECTOS VISUALES
@export_group("Configuración de Efectos Visuales")
@export var screen_shake_intensity: float = 25.0
@export var screen_shake_duration: float = 1.0
@export var flash_screen_duration: float = 0.8
@export var flash_screen_color: Color = Color(1, 0.3, 0.3, 0.4)

# CONFIGURACIÓN DE LOADING SCREEN
@export_group("Configuración de Loading Screen")
@export var loading_duration: float = 3.0

# Variables internas del juego
var players := {} # id:int -> Node2D
var enemies := {} # id:int -> Node2D
var projectiles := {} # id:int -> Node2D
var bases := {} # team:int -> Node2D

# Variables de espera
var class_chosen: bool = false
var game_started: bool = false
var countdown_timer: float = 0.0
var countdown_active: bool = false
var wait_timer: float = 0.0
var loading_complete: bool = false

# Variables de equipos y victoria
var player_teams := {} # id -> team
var team_counts := {1: 0, 2: 0}
var game_start_countdown := 0
var respawn_timers := {} # player_id -> time_left
var local_player_team := 0
var bosses := {} # id:int -> Node2D

# -------------------------------
# --- INICIO
# -------------------------------
func _ready():
	# Agregar este nodo al grupo "main" para que los fantasmas puedan encontrarlo
	add_to_group("main")
	
	Network.area_attack_effect.connect(_on_area_attack_effect)
	Network.rogue_area_attack_effect.connect(_on_rogue_area_attack_effect)
	Network.mage_area_attack_effect.connect(_on_mage_area_attack_effect)
	# Conectar botones UI
	login_button.pressed.connect(_on_login_pressed)
	chat_send.pressed.connect(_on_chat_send_pressed)
	button_ip.pressed.connect(_on_button_ip_pressed)
	Network.enemy_spawned_immediate.connect(_on_enemy_spawned_immediate)
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

	Network.wave_started.connect(_on_wave_started)
	Network.wave_ended.connect(_on_wave_ended)
	#Network.boss_spawned.connect(_on_boss_spawned_permanent)
	# ✅ CORREGIDO: Cambiar conexión de currency_updated
	Network.currency_updated.connect(_on_currency_updated_by_id)
	
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
	Network.base_hit.connect(_on_base_hit)
	# Configurar sala de espera
	_setup_waiting_room()
	
	# Spawnear bases iniciales
	spawn_initial_bases()
	
	print("🎮 Main listo - Esperando conexión...")

# -------------------------------
# --- SISTEMA DE BASES
# -------------------------------
func spawn_initial_bases():
	print("🏰 SPAWNEANDO BASES INICIALES...")
	
	for team in [1, 2]:
		if BaseScene:
			var base = BaseScene.instantiate()
			base.position = base_positions[team]
			base.name = "Base_Team_" + str(team)
			
			# Configurar base usando variables públicas
			if base.has_method("setup"):
				base.setup(team, base_health, base_max_health)
			
			base_container.add_child(base)
			bases[team] = base
			print("🏰 BASE CREADA - Equipo:", team, " Posición:", base_positions[team])
		else:
			push_error("❌ ERROR: BaseScene no asignada en el inspector de main.tscn")

func update_bases_from_server():
	if not Network.bases.is_empty():
		for team_str in Network.bases:
			var team = int(team_str)
			var base_data = Network.bases[team_str]
			
			if team in bases:
				var base_node = bases[team]
				if base_node and base_node.has_method("update_hp"):
					# Usar get() con valores por defecto para evitar errores
					var current_hp = base_data.get("hp", base_health)
					var max_hp = base_data.get("maxHp", base_data.get("max_hp", base_max_health))
					
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

# ✅ CORREGIDO: Nueva función para manejar currency_updated con player_id
func _on_currency_updated_by_id(player_id: int, amount: int):
	# Solo procesar si es el jugador local
	if player_id == Network.player_id:
		print("💰 MONEDAS ACTUALIZADAS EN MAIN - Jugador:", player_id, " Cantidad:", amount)
		# Actualizar el jugador local
		var local_player = players.get(Network.player_id, null)
		if local_player and local_player.has_method("update_currency"):
			local_player.update_currency(amount)

func _on_decision_period_started(duration: float, currency: int, cards: Array):
	print("⏰ PERIODO DE DECISIONES - Duración: %.1fs, Monedas: %d, Cartas: %d" % [duration, currency, cards.size()])
	
	# Mostrar UI de decisiones al jugador local
	var local_player = players.get(Network.player_id, null)
	if local_player and local_player.has_method("show_decision_period"):
		local_player.show_decision_period(duration, currency, cards)
		
func _print_node_structure(node: Node, indent: int = 0):
	if not node:
		return
		
	var indent_str = "  ".repeat(indent)
	print(indent_str + "📁 " + node.name + " (" + node.get_class() + ")")
	
	# Propiedades importantes para sprites
	if node is AnimatedSprite2D:
		var sprite = node as AnimatedSprite2D
		print(indent_str + "  🎭 AnimatedSprite2D")
		print(indent_str + "  👀 Visible:", sprite.visible)
		print(indent_str + "  🎨 Modulate:", sprite.modulate)
		print(indent_str + "  📏 Position:", sprite.position)
		
		if sprite.sprite_frames:
			var anim_names = sprite.sprite_frames.get_animation_names()
			print(indent_str + "  📋 SpriteFrames - Animaciones:", anim_names)
			print(indent_str + "  🔄 Animación actual:", sprite.animation)
			print(indent_str + "  ▶️ Reproduciendo:", sprite.is_playing())
		else:
			print(indent_str + "  ❌ NO TIENE SPRITE_FRAMES")
	
	# Recursión para hijos
	for child in node.get_children():
		_print_node_structure(child, indent + 1)

func _init_boss_ui(boss: Node):
	# Crear UI de salud del jefe si no existe
	var boss_health_ui = preload("res://ui/boss/BossHealthUI.tscn")
	if boss_health_ui and not has_node("BossHealthUI"):
		var ui_instance = boss_health_ui.instantiate()
		ui_instance.name = "BossHealthUI"
		canvas_layer.add_child(ui_instance)
		ui_instance.visible = false
		
		print("✅ UI DEL JEFE INICIALIZADA")

func _show_boss_victory_effects():
	print("🎊 VICTORIA CONTRA EL JEFE!")
	
	# Efectos visuales/sonoros por derrotar al jefe
	_flash_screen(Color(0, 1, 0, 0.3), 1.5)
	_screen_shake(0.8, 20)
	
	# Mostrar mensaje de victoria
	_show_boss_message("¡JEFE DERROTADO!")

func _screen_shake(duration: float, intensity: float):
	# Implementar screen shake básico
	var camera = get_viewport().get_camera_2d()
	if camera:
		var original_offset = camera.offset
		var tween = create_tween()
		for i in range(int(duration * 10)):
			var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensity
			tween.tween_property(camera, "offset", original_offset + random_offset, 0.1)
			tween.tween_property(camera, "offset", original_offset, 0.1)

func _flash_screen(color: Color, duration: float):
	# Crear un overlay temporal para efectos de pantalla
	var flash = ColorRect.new()
	flash.color = color
	flash.size = get_viewport().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	canvas_layer.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "color", Color(color.r, color.g, color.b, 0), duration)
	tween.tween_callback(flash.queue_free)

func _show_boss_message(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.position = Vector2(get_viewport().size.x / 2 - 150, 100)
	
	canvas_layer.add_child(label)
	
	var tween = create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 50, 2.0)
	tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), 2.0)
	tween.tween_callback(label.queue_free)

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
	
	# Simular progreso de carga usando variable pública
	var tween = create_tween()
	tween.tween_method(_update_loading_progress, 0.0, 100.0, loading_duration)
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
# --- PROCESO PRINCIPAL (CORREGIDO)
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
		print("📊 ESTADO - Jugadores:", players.size(), " Enemigos:", enemies.size(), " Bosses:", bosses.size(), " Proyectiles:", projectiles.size(), " Bases:", bases.size())

# -------------------------------
# --- ACTUALIZACIÓN DE ENTIDADES DEL JUEGO (CORREGIDO)
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

	# --- Actualizar enemigos y bosses ---
	print("🔄 ACTUALIZANDO ENEMIGOS - Total en Network:", Network.enemies.size())
	for key in Network.enemies.keys():
		var id = int(key)
		var data = Network.enemies[key]
		
		# ✅ DETECCIÓN MEJORADA DE BOSSES
		var is_boss = (
			data.get("type") == "final_boss" or
			data.get("is_permanent") == true or
			data.get("type") == "boss_wave" or
			str(id) == "999" # ID específico del boss permanente
		)
		
		print("   Enemigo ID:", id, " Tipo:", data.get("type"), " Es boss?", is_boss, " Razón: type=", data.get("type"), ", is_permanent=", data.get("is_permanent"))
		
		if is_boss:
			print("🎯 ENEMIGO ES BOSS - ID:", id, " Datos:", data)
			if bosses.has(id):
				# Actualizar boss existente
				if data.has("x") and data.has("y"):
					bosses[id].position = Vector2(data.x, data.y)
				if data.has("hp") and bosses[id].has_method("update_hp"):
					bosses[id].update_hp(data.hp)
				
				# Sincronizar animación si está disponible
				if data.has("animation_state") and bosses[id].has_method("play_animation"):
					bosses[id].play_animation(data.animation_state)
				elif bosses[id].has_method("play_animation"):
					# Si no hay animación específica, usar una por defecto
					bosses[id].play_animation("idle")
		else:
			# Enemigos normales
			if id in enemies:
				enemies[id].position = Vector2(data.x, data.y)
				if data.has("hp") and enemies[id].has_method("update_hp"):
						enemies[id].update_hp(data.hp)
				# ✅ NUEVO: Actualizar equipo si es necesario
				if data.has("team") and enemies[id].has_method("set_team"):
					enemies[id].set_team(data.team)
			else:
				 #✅ Pasar el equipo si está disponible en los datos
				var enemy_team = data.get("team", 0)
				if enemy_team == 0:
					# Si no viene team en los datos, asignar basado en ID
					enemy_team = 1 if id <= 3 else 2
					print("⚠️ ENEMIGO SIN TEAM - Asignando por ID:", id, " -> Team:", enemy_team)
				_spawn_enemy(id, data.type, Vector2(data.x, data.y), enemy_team)
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

	# --- Actualizar posición de proyectiles existentes ---
	for projectile_id in projectiles:
		if Network.projectiles.has(str(projectile_id)):
			var proj_data = Network.projectiles[str(projectile_id)]
			var projectile_node = projectiles[projectile_id]
			
			if is_instance_valid(projectile_node):
				# ✅ CORREGIDO: Verificación más segura para proyectiles remotos
				var is_remote = true
				
				# Verificar si el proyectil es del jugador local
				if proj_data.has("owner_id"):
					is_remote = (proj_data.owner_id != Network.player_id)
				
				# Solo actualizar proyectiles remotos (no los del jugador local)
				if is_remote:
					projectile_node.position = Vector2(proj_data.x, proj_data.y)

	# --- Actualizar bases desde datos del servidor ---
	update_bases_from_server()

	# --- Limpiar entidades eliminadas ---
	_cleanup_removed_entities()

# NUEVO: Verificar muertes de enemigos
func _check_enemy_deaths():
	# Buscar enemigos que estaban pero ya no están en Network.enemies
	for enemy_id in enemies.keys():
		if not Network.enemies.has(str(enemy_id)):
			var enemy = enemies[enemy_id]
			if enemy and is_instance_valid(enemy):
				# El enemigo fue eliminado, verificar quién lo mató
				_process_enemy_death(enemy_id, enemy)

func _process_enemy_death(enemy_id: int, enemy: Node):
	var enemy_type = enemy.get_enemy_type() if enemy.has_method("get_enemy_type") else "grunt"
	print("💀 PROCESANDO MUERTE DE ENEMIGO - ID:", enemy_id, " Tipo:", enemy_type)
	
	# El servidor ahora maneja las recompensas individuales

# -------------------------------
# --- SPAWN DE ENEMIGOS
# -------------------------------
func _spawn_enemy(id: int, type: String, pos: Vector2, team: int = 0):
	# ✅ VERIFICAR DUPLICADOS
	if id in enemies:
		print("❌ ENEMIGO DUPLICADO - ID:", id, " Ya existe!")
		return
	
	print("✅ SPAWNEANDO ENEMIGO - ID:", id, " Tipo:", type, " Equipo:", team)
	
	var instance = EnemyScene.instantiate()
	instance.position = pos
	instance.name = str(id)
	# ✅ ASIGNAR EQUIPO INMEDIATAMENTE - INCLUYENDO NEUTRALES (0)
	if instance.has_method("set_team"):
		instance.set_team(team)
		print("🎨 COLOR ASIGNADO INMEDIATAMENTE - Enemigo:", id, " Equipo:", team)
	
	# ✅ ASIGNAR ID Y TIPO DESPUÉS DEL EQUIPO
	if instance.has_method("set_enemy_id"):
		instance.set_enemy_id(id)
	if instance.has_method("set_enemy_type"):
		instance.set_enemy_type(type)
	
	enemy_container.add_child(instance)
	enemies[id] = instance
func _on_enemy_spawned_immediate(enemy_data: Dictionary):
	var id = enemy_data.id
	var type = enemy_data.type
	var pos = Vector2(enemy_data.x, enemy_data.y)
	var team = enemy_data.team
	
	print("⚡ SPAWN INMEDIATO - Enemigo ID:", id, " Tipo:", type, " Equipo:", team)
	
	# Usar la función _spawn_enemy existente pero con el equipo
	#_spawn_enemy(id, type, pos, team)



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
	countdown_timer = game_start_countdown_time # Usar variable pública
	if start_countdown:
		start_countdown.visible = true
		start_countdown.text = "Iniciando en: %d" % game_start_countdown_time

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
	
	# Definir área de spawn usando variable pública
	var spawn_width = screen_size.x * spawn_area_percentage
	var spawn_height = screen_size.y * spawn_area_percentage
	
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
	
	# Configuración básica del proyectil
	var direction = Vector2(data.direction_x, data.direction_y)
	
	print("🎯 CONFIGURANDO PROYECTIL - ID:", id, " Clase:", classe, " Owner:", data.owner_id)
	
	# Configuración según el tipo de proyectil
	if projectile.has_method("initialize"):
		var is_remote = (data.owner_id != Network.player_id)
		projectile.initialize(id, direction, data.damage, data.owner_id, is_remote)
	else:
		# Configuración estándar para proyectiles simples
		projectile.set("projectile_id", id)
		projectile.set("projectile_direction", direction.normalized())
		projectile.set("projectile_damage", data.damage)
		projectile.set("projectile_owner_id", data.owner_id)
		projectile.set("projectile_speed", data.speed if data.has("speed") else projectile_speed)
	
	add_child(projectile)
	projectiles[id] = projectile
	
	print("✅ PROYECTIL CREADO - ID:", id, " Tipo:", classe)

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
# --- LIMPIEZA DE ENTIDADES ELIMINADAS (CORREGIDO)
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

	# Enemigos normales eliminados
	var enemies_to_remove := []
	for id in enemies.keys():
		if not Network.enemies.has(str(id)):
			enemies_to_remove.append(id)
	
	for id in enemies_to_remove:
		print("👹 ELIMINANDO ENEMIGO - ID:", id)
		if is_instance_valid(enemies[id]):
			enemies[id].queue_free()
		enemies.erase(id)

	# Bosses eliminados - SOLO si no están en Network.enemies
	var bosses_to_remove := []
	for id in bosses.keys():
		if not Network.enemies.has(str(id)):
			bosses_to_remove.append(id)
	
	for id in bosses_to_remove:
		print("👹 ELIMINANDO BOSS - ID:", id)
		if is_instance_valid(bosses[id]):
			bosses[id].queue_free()
		bosses.erase(id)

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

	# CLICK DERECHO - Ataque de área según clase
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var player = players.get(Network.player_id, null)
		if player:
			var player_classe = player.classe if "classe" in player else "warrior"
			
			if player_classe == "archer" and player.has_method("execute_area_attack"):
				print("🖱️ CLICK DERECHO - Ataque de área (Archer)")
				player.execute_area_attack(get_global_mouse_position())
			elif player_classe == "rogue" and player.has_method("execute_rogue_area_attack"):
				print("🖱️ CLICK DERECHO - Ataque de área (Rogue)")
				player.execute_rogue_area_attack(get_global_mouse_position())
			elif player_classe == "mage" and player.has_method("execute_mage_area_attack"):
				print("🖱️ CLICK DERECHO - Ataque de área (Mage)")
				player.execute_mage_area_attack()

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

	# Propiedades de ataque específicas por clase - USANDO VARIABLES PÚBLICAS
	var attack_range = 60.0
	var attack_cone_angle = deg_to_rad(90.0)
	var attack_damage = 10
	
	# Ajustar propiedades según clase usando variables públicas
	match player_classe:
		"warrior":
			attack_range = warrior_attack_range
			attack_damage = warrior_attack_damage
			attack_cone_angle = deg_to_rad(warrior_attack_cone_angle)
		"rogue":
			attack_range = rogue_attack_range
			attack_damage = rogue_attack_damage
			attack_cone_angle = deg_to_rad(rogue_attack_cone_angle)
	

	# Detección de golpes - PRIMERO enemigos
	for enemy_id in enemies.keys():
		var enemy = enemies[enemy_id]
		if not is_instance_valid(enemy):
			continue
			
		# ✅ NUEVO: Verificar que el enemigo sea de equipo contrario
		if enemy.team == player.team:
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

	# Daño específico por clase usando variables públicas
	var attack_damage = 8
	match player_classe:
		"mage":
			attack_damage = mage_attack_damage
		"archer":
			attack_damage = archer_attack_damage

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
		projectile_speed, # Usar variable pública
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

func _find_object_by_id(object_id: int) -> Node:
	"""Busca un objeto por su ID de instancia en el object_container"""
	if not object_container:
		return null
	for child in object_container.get_children():
		if child.get_instance_id() == object_id:
			return child
	return null



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
func debug_boss():
	print("🐛 ===== DEBUG COMPLETO DEL BOSS =====")
	print("Bosses en escena:", bosses.size())
	
	for boss_id in bosses:
		var boss = bosses[boss_id]
		print("\n🔍 BOSS ID:", boss_id)
		print("   Válido:", is_instance_valid(boss))
		
		if boss:
			print("   Posición:", boss.position)
			print("   En árbol:", boss.is_inside_tree())
			print("   Visible:", boss.visible)
			print("   Modulate:", boss.modulate)
			
			if boss.has_method("play_animation"):
				print("   Tiene método play_animation: ✅ SÍ")
			else:
				print("   Tiene método play_animation: ❌ NO")
			
			# Buscar AnimatedSprite2D
			var sprite = boss.get_node_or_null("AnimatedSprite2D")
			if sprite:
				print("   AnimatedSprite2D encontrado: ✅")
				print("   Sprite visible:", sprite.visible)
				print("   Sprite modulate:", sprite.modulate)
				print("   Tiene SpriteFrames:", sprite.sprite_frames != null)
				
				if sprite.sprite_frames:
					print("   Animaciones disponibles:", sprite.sprite_frames.get_animation_names())
					print("   Animación actual:", sprite.animation)
					print("   Reproduciendo:", sprite.is_playing())
			else:
				print("   AnimatedSprite2D: ❌ NO ENCONTRADO")
				# Buscar recursivamente
				var found_sprite = _find_node_recursive(boss, "AnimatedSprite2D")
				if found_sprite:
					print("   Encontrado recursivamente: ✅")
				else:
					print("   No encontrado en toda la jerarquía: ❌")
	
	print("===== FIN DEBUG =====")

func _find_node_recursive(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	
	for child in root.get_children():
		var found = _find_node_recursive(child, node_name)
		if found:
			return found
	
	return null

# Función para forzar visibilidad (debug)
func force_boss_visibility():
	print("🔧 FORZANDO VISIBILIDAD DE TODOS LOS BOSSES")
	
	for boss_id in bosses:
		var boss = bosses[boss_id]
		if boss:
			print("👹 Aplicando a boss:", boss_id)
			
			# Forzar propiedades de visibilidad
			boss.visible = true
			boss.modulate = Color.WHITE
			boss.z_index = 100 # Asegurar que esté por encima
			
			# Si el boss tiene el método force_visibility, usarlo
			if boss.has_method("force_visibility"):
				boss.force_visibility()
			
			# Buscar y forzar visibilidad del sprite
			var sprite = boss.get_node_or_null("AnimatedSprite2D")
			if sprite:
				sprite.visible = true
				sprite.modulate = Color.WHITE
				sprite.z_index = 101
				print("   ✅ Sprite forzado a visible")
			else:
				print("   ❌ No se encontró sprite")
			
			boss.queue_redraw()
	
	print("✅ Visibilidad forzada para", bosses.size(), "bosses")
func _on_area_attack_effect(x: float, y: float, player_id: int):
	print("💥 CREANDO EFECTO DE ATAQUE DE ÁREA - Jugador:", player_id, " Posición:", Vector2(x, y))
	
	# VERIFICAR SI LA ESCENA EXISTE ← NUEVO
	var area_projectile_scene = preload("res://projectiles/ArcherAreaProjectile.tscn")
	if not area_projectile_scene:
		print("❌ ERROR: No se pudo cargar ArcherAreaProjectile.tscn")
		return
	
	# CREAR EFECTO INMEDIATAMENTE ← CORREGIDO
	var area_projectile = area_projectile_scene.instantiate()
	
	# VERIFICAR QUE SE INSTANCIÓ CORRECTAMENTE
	if not area_projectile:
		print("❌ ERROR: No se pudo instanciar ArcherAreaProjectile")
		return
	
	# POSICIONAR CORRECTAMENTE
	area_projectile.position = Vector2(x, y)
	
	# ORIENTAR EL EFECTO SEGÚN LA DIRECCIÓN DEL JUGADOR ← NUEVO
	if player_id in players:
		var attacker = players[player_id]
		if attacker and attacker.has_method("get_last_direction"):
			# Si el jugador tiene método para obtener dirección, usarlo
			var direction = attacker.get_last_direction()
			_orient_area_effect(area_projectile, direction)
	
	# Agregar a la escena INMEDIATAMENTE
	enemy_container.add_child(area_projectile)
	
	print("✅ EFECTO DE ÁREA CREADO INMEDIATAMENTE - Posición:", Vector2(x, y))
func _on_mage_area_attack_effect(x: float, y: float, player_id: int):
	print("💥 EFECTO DE ATAQUE DE ÁREA MAGA - Jugador:", player_id, " Posición:", Vector2(x, y))
	
	# Cargar la escena del proyectil de área de la maga
	var mage_area_projectile_scene = preload("res://projectiles/MageAreaProjectile.tscn")
	if not mage_area_projectile_scene:
		print("❌ ERROR: No se pudo cargar MageAreaProjectile.tscn")
		return
	
	var area_projectile = mage_area_projectile_scene.instantiate()
	if not area_projectile:
		print("❌ ERROR: No se pudo instanciar MageAreaProjectile")
		return
	
	# Posicionar y configurar Z-index para que esté DEBAJO
	area_projectile.position = Vector2(x, y)
	area_projectile.z_index = -1  # ← IMPORTANTE: debajo de los personajes
	
	# Agregar a ObjectContainer (para efectos visuales)
	if object_container:
		object_container.add_child(area_projectile)
		print("✅ EFECTO DE ÁREA MAGA CREADO EN CLIENTE - Posición:", Vector2(x, y))
	else:
		print("❌ No se encontró object_container")
# NUEVA FUNCIÓN PARA ORIENTAR EL EFECTO DE ÁREA ← AGREGAR ESTA FUNCIÓN
func _orient_area_effect(effect: Node, direction: Vector2):
	if effect.has_node("AnimatedSprite2D"):
		var sprite = effect.get_node("AnimatedSprite2D")
		# Ajustar la orientación según la dirección
		if direction.x > 0:
			sprite.flip_h = false
		elif direction.x < 0:
			sprite.flip_h = true
		print("🧭 EFECTO ORIENTADO - Dirección:", direction)
# Nueva función para manejar daño a basess
func _on_base_hit(team: int, hp: int, max_hp: int):
	print("🏰 ACTUALIZANDO BASE - Equipo:", team, " HP:", hp, "/", max_hp)
	
	if bases.has(team):
		var base_node = bases[team]
		if base_node and base_node.has_method("update_hp"):
			base_node.update_hp(hp)
func _on_rogue_area_attack_effect(x: float, y: float, player_id: int):
	print("💥 EFECTO DE ATAQUE DE ÁREA ROGUE - Jugador:", player_id, " Posición:", Vector2(x, y))
