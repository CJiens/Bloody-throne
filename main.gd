extends Node2D

# -------------------------------
# --- NODOS
# -------------------------------
@onready var player_container = $PlayerContainer
@onready var enemy_container = $EnemyContainer
@onready var network = $Network

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
# Prefabs
@export var PlayerScene: PackedScene
@export var EnemyScene: PackedScene

# Diccionarios locales
var players := {} # id:int -> Player
var enemies := {} # id:int -> Node2D

# Movimiento
var move_dir := Vector2.ZERO
var speed := 200.0

# Ataque
var attack_held := false
var attack_cooldown := 0.5
var attack_timer := 0.0

# Roll
var is_rolling := false
var roll_speed := 450.0
var roll_duration := 0.35
var roll_cooldown := 1.0
var roll_timer := 0.0
var roll_cooldown_timer := 0.0

# UI
var current_username: String = ""

# -------------------------------
# --- INICIO
# -------------------------------
func _ready():
	login_button.pressed.connect(_on_login_pressed)
	chat_send.pressed.connect(_on_chat_send_pressed)
	chat_ui.visible = false
	vbox_container_2.visible = false

	if not network.is_connected("login_successful", self._on_login_successful):
		network.connect("login_successful", self._on_login_successful)

	# 🎬 Video inicial en loop (pantalla de inicio)
	# video_stream_player.stream = load("res://Video-Login-Loop.ogv")
	# video_stream_player.autoplay = true
	# video_stream_player.loop = true
	# video_stream_player.visible = true
	# video_stream_player.z_index = 0

	set_process(true)
	set_process_input(true)

# -------------------------------
# --- PROCESO PRINCIPAL
# -------------------------------
func _process(delta):
	if not network.connected or network.player_id == -1:
		return

	for key in network.players.keys():
		var id = int(key)
		var data = network.players[key]

		if id in players:
			var player_node = players[id]
			if id != network.player_id:
				player_node.position = Vector2(data.x, data.y)
				player_node.update_animation(Vector2.ZERO, false, false)
			_update_player_hp(player_node, data.hp, id)
		else:
			_spawn_player(id, data.username, Vector2(data.x, data.y), data.hp)

	for key in network.enemies.keys():
		var id = int(key)
		var data = network.enemies[key]
		if id in enemies:
			enemies[id].position = Vector2(data.x, data.y)
		else:
			_spawn_enemy(id, data.type, Vector2(data.x, data.y))

	for id in players.keys():
		if not network.players.has(str(id)):
			players[id].queue_free()
			players.erase(id)

	for id in enemies.keys():
		if not network.enemies.has(str(id)):
			enemies[id].queue_free()
			enemies.erase(id)

	var player = players.get(network.player_id, null)
	if player and player is CharacterBody2D:
		_handle_movement(delta, player)

		var my_data = network.players.get(str(network.player_id), null)
		if my_data:
			_update_player_hp(player, my_data.hp, network.player_id)

	if attack_held:
		attack_timer -= delta
		if attack_timer <= 0:
			attack_timer = attack_cooldown
			_attack_near_target(get_global_mouse_position())

	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
			roll_cooldown_timer = roll_cooldown

	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta

# -------------------------------
# --- MOVIMIENTO
# -------------------------------
func _handle_movement(delta: float, player: CharacterBody2D):
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

	if network.connected:
		network.move_player(player.position.x, player.position.y)

	player.update_animation(move_dir, attack_held, is_rolling)

# -------------------------------
# --- INPUT
# -------------------------------
func _unhandled_input(event):
	if not network.connected or network.player_id == -1:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			attack_held = true
			attack_timer = 0
			_attack_near_target(get_global_mouse_position())
		else:
			attack_held = false

	if event.is_action_pressed("roll") and not is_rolling and roll_cooldown_timer <= 0:
		is_rolling = true
		roll_timer = roll_duration

# -------------------------------
# --- ATAQUE
# -------------------------------
# -------------------------------
# --- ATAQUE AUTOMÁTICO
# -------------------------------
func _attack_near_target(mouse_pos: Vector2) -> void:
	var attack_range: float = 10.0        # distancia máxima del ataque
	var cone_angle: float = deg_to_rad(45) # ángulo del cono (45° a cada lado)
	
	var player_pos: Vector2 = global_position
	var player_facing: Vector2 = (mouse_pos - player_pos).normalized()  # dirección hacia donde apunta el ratón

	# Buscar enemigos dentro del cono frontal
	for enemy_id in enemies.keys():
		var enemy = enemies[enemy_id]
		var to_enemy: Vector2 = enemy.position - player_pos
		var dist: float = to_enemy.length()

		if dist <= attack_range:
			var dir_to_enemy: Vector2 = to_enemy.normalized()
			var angle: float = player_facing.angle_to(dir_to_enemy)

			# Si está dentro del cono (en frente del jugador)
			if abs(angle) <= cone_angle:
				network.attack("enemy", enemy_id, 10)
				return  # solo golpea al primero encontrado

	# Si no golpeó enemigo, buscar jugadores (PvP)
	for player_id in players.keys():
		if player_id == network.player_id:
			continue
		var other = players[player_id]
		var to_player: Vector2 = other.position - player_pos
		var dist_p: float = to_player.length()

		if dist_p <= attack_range:
			var dir_to_player: Vector2 = to_player.normalized()
			var angle_p: float = player_facing.angle_to(dir_to_player)

			if abs(angle_p) <= cone_angle:
				network.attack("player", player_id, 10)
				return


# -------------------------------
# --- SPAWN / HP
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

	if id == network.player_id:
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
		if id == network.player_id and bar.value <= 0:
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
		network.login_user(username, password)

# -------------------------------
# --- LOGIN EXITOSO (VIDEO)
# -------------------------------
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
		network.send_chat(text)
		chat_input.text = ""

# -------------------------------
# --- BOTONES EXTRA
# -------------------------------
func _on_button_pressed() -> void:
	vbox_container.visible = false
	vbox_container_2.visible = true

func _on_button_4_pressed() -> void:
	get_tree().quit()
