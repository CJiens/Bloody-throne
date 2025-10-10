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
var players := {} # id:int -> Node2D
var enemies := {} # id:int -> Node2D

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

# -------------------------------
# --- PROCESO PRINCIPAL
# -------------------------------
# -------------------------------
# --- PROCESO PRINCIPAL
# -------------------------------
func _process(_delta):
	if not Network.connected or Network.player_id == -1:
		return

	# --- Actualizar jugadores desde Network ---
	for key in Network.players.keys():
		var id = int(key)
		var data = Network.players[key]

		if id in players:
			var player_node = players[id]

			if id != Network.player_id:
				# ⚙️ Solo actualiza a los demás jugadores
				player_node.position = Vector2(data.x, data.y)

				# Actualizar animación de otros jugadores
				if data.has("animation_state"):
					var anim_name: String = data.animation_state
					if player_node.has_method("set_remote_animation"):
						player_node.set_remote_animation(anim_name)

			# Actualizar HP de todos los jugadores
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
				_attack_near_target(get_global_mouse_position())

	if event.is_action_pressed("roll"):
		var player = players.get(Network.player_id, null)
		if player and player.has_method("try_roll"):
			player.try_roll()

# -------------------------------
# --- ATAQUE
# -------------------------------
func _attack_near_target(mouse_pos: Vector2) -> void:
	var player = players.get(Network.player_id, null)
	if player == null:
		return

	var player_pos: Vector2 = player.global_position
	var player_facing: Vector2 = (mouse_pos - player_pos).normalized()
	var hit_something := false

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
	var instance = PlayerScene.instantiate()
	instance.position = pos
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
	
	var bar = instance.get_node_or_null("ProgressBar")
	if bar:
		bar.max_value = 100
		bar.value = hp
		bar.queue_redraw()

	# # Actualizar HP
	# if instance.has_method("update_hp"):
	# 	instance.update_hp(hp)

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
# --- LOGIN
# -------------------------------
func _on_login_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	if username != "" and password != "":
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
