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

# Prefabs
@export var PlayerScene: PackedScene
@export var EnemyScene: PackedScene

# -------------------------------
# --- VARIABLES DE JUEGO
# -------------------------------
var players := {} # id:int -> Player
var enemies := {} # id:int -> Node2D

# Movimiento
var move_dir := Vector2.ZERO
var speed := 200.0

# Ataque
var attack_range: float = 40.0
var attack_cone_angle: float = deg_to_rad(45.0)
var attack_damage: int = 10
var attack_cooldown: float = 0.2
var attack_timer: float = 0.0
var can_attack: bool = true

# Roll
var is_rolling := false
var roll_speed := 450.0
var roll_duration := 0.35
var roll_cooldown := 1.0
var roll_timer := 0.0
var roll_cooldown_timer := 0.0

# UI
var current_username: String = ""

# Estado de animación actual
var current_animation: String = "Idle"

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

	set_process(true)
	set_process_input(true)

# -------------------------------
# --- PROCESO PRINCIPAL
# -------------------------------
func _process(delta):
	if not Network.connected or Network.player_id == -1:
		return

	# --- Actualizar jugadores desde Network ---
	for key in Network.players.keys():
		var id = int(key)
		var data = Network.players[key]

		if id in players:
			var player_node = players[id]
			if id != Network.player_id:
				player_node.position = Vector2(data.x, data.y)

				# 🔥 ANIMACIONES SIN ERRORES 🔥
				if player_node.has_node("AnimatedSprite2D"):
					var anim_sprite: AnimatedSprite2D = player_node.get_node("AnimatedSprite2D")
					if data.has("animation_state"):
						var anim_name: String = data.animation_state
						if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
							if anim_sprite.animation != anim_name:
								anim_sprite.play(anim_name)
						else:
							print("⚠️ Animación inexistente: ", anim_name, " en jugador ", id)
			_update_player_hp(player_node, data.hp, id)
		else:
			_spawn_player(id, data.username, Vector2(data.x, data.y), data.hp)

	# --- Actualizar enemigos ---
	for key in Network.enemies.keys():
		var id = int(key)
		var data = Network.enemies[key]
		if id in enemies:
			enemies[id].position = Vector2(data.x, data.y)
		else:
			_spawn_enemy(id, data.type, Vector2(data.x, data.y))

	# --- Eliminar desconectados ---
	for id in players.keys():
		if not Network.players.has(str(id)):
			players[id].queue_free()
			players.erase(id)

	for id in enemies.keys():
		if not Network.enemies.has(str(id)):
			enemies[id].queue_free()
			enemies.erase(id)

	# --- Actualizar jugador local ---
	var player = players.get(Network.player_id, null)
	if player and player is CharacterBody2D:
		_handle_movement(delta, player)
		var my_data = Network.players.get(str(Network.player_id), null)
		if my_data:
			_update_player_hp(player, my_data.hp, Network.player_id)

	# --- Cooldown de ataque ---
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	# --- Rodar ---
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
			roll_cooldown_timer = roll_cooldown

	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta

# -------------------------------
# --- MOVIMIENTO Y ANIMACIÓN (LOCAL)
# -------------------------------
func _handle_movement(_delta: float, player: CharacterBody2D):
	# Restauré las entradas de movimiento que faltaban (solo aquí)
	move_dir = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		move_dir.x += 1
	if Input.is_action_pressed("move_left"):
		move_dir.x -= 1
	if Input.is_action_pressed("move_down"):
		move_dir.y += 1
	if Input.is_action_pressed("move_up"):
		move_dir.y -= 1

	if move_dir != Vector2.ZERO:
		move_dir = move_dir.normalized()

	var velocity = Vector2.ZERO
	if is_rolling:
		velocity = move_dir * roll_speed
	else:
		velocity = move_dir * speed

	player.velocity = velocity
	player.move_and_slide()

	if Network.connected:
		Network.move_player(player.position.x, player.position.y)

	# Mantengo la actualización de animación local como estaba originalmente:
	# Si tu Player.tscn tiene un método `update_animation(move_dir, ..., is_rolling)` lo llamamos (preservando tu lógica de direcciones/frames).
	if player.has_method("update_animation"):
		player.update_animation(move_dir, false, is_rolling)
	# Si no existe ese método, aplico un fallback seguro usando AnimatedSprite2D:
	elif player.has_node("AnimatedSprite2D"):
		var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
		var new_state := "Idle"
		if is_rolling:
			new_state = "Roll"
		elif move_dir != Vector2.ZERO:
			new_state = "Walk"
		else:
			new_state = "Idle"

		# Verificar existencia para evitar errores (si el nombre no existe, no tocar)
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(new_state):
			if sprite.animation != new_state:
				sprite.play(new_state)

# -------------------------------
# --- INPUT
# -------------------------------
func _unhandled_input(event):
	if not Network.connected or Network.player_id == -1:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if can_attack:
				_attack_near_target(get_global_mouse_position())

	if event.is_action_pressed("roll") and not is_rolling and roll_cooldown_timer <= 0:
		is_rolling = true
		roll_timer = roll_duration

# -------------------------------
# --- ATAQUE
# -------------------------------
func _attack_near_target(mouse_pos: Vector2) -> void:
	if not can_attack:
		return

	can_attack = false
	attack_timer = attack_cooldown

	var player = players.get(Network.player_id, null)
	if player == null:
		return

	# var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	# sprite.play("Attack")
	# Network.send_player_state("Attack")

	var player_pos: Vector2 = player.global_position
	var player_facing: Vector2 = (mouse_pos - player_pos).normalized()
	var hit_something := false

	for enemy_id in enemies.keys():
		var enemy = enemies[enemy_id]
		var to_enemy: Vector2 = enemy.position - player_pos
		var dist: float = to_enemy.length()

		if dist <= attack_range:
			var dir_to_enemy: Vector2 = to_enemy.normalized()
			var angle: float = player_facing.angle_to(dir_to_enemy)
			if abs(angle) <= attack_cone_angle:
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
					Network.attack("player", player_id, attack_damage)
					break

# -------------------------------
# --- SPAWN Y HP
# -------------------------------
func _spawn_player(id: int, username: String, pos: Vector2, hp: int = 100):
	var instance: Player = PlayerScene.instantiate()
	instance.position = pos
	instance.name = str(id)
	player_container.add_child(instance)
	players[id] = instance

	var name_label = instance.get_node_or_null("nombre")
	if name_label:
		name_label.text = username

	if id == Network.player_id:
		var cam = instance.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()

	var bar = instance.get_node_or_null("ProgressBar")
	if bar:
		bar.max_value = 100
		bar.value = hp

func _spawn_enemy(id: int, _enemy_type: String, pos: Vector2):
	var instance = EnemyScene.instantiate()
	instance.position = pos
	instance.name = str(id)
	enemy_container.add_child(instance)
	enemies[id] = instance

func update_player_hp(id: int, hp_value: int):
	var player = players.get(id, null)
	if not player:
		return
	var bar = player.get_node_or_null("ProgressBar")
	if bar:
		bar.value = clamp(hp_value, 0, 100)
		if id == Network.player_id and bar.value <= 0:
			print("[GAME OVER] Jugador muerto.")
			get_tree().quit()

func _update_player_hp(player: Node2D, hp_value: int, id: int):
	update_player_hp(id, hp_value)

# -------------------------------
# --- LOGIN
# -------------------------------
func _on_login_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	if username != "" and password != "":
		current_username = username
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
