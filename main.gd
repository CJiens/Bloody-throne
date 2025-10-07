extends Node2D

# -------------------------------
# --- NODOS
# -------------------------------
@onready var player_container = $PlayerContainer
@onready var enemy_container = $EnemyContainer
@onready var network = $Network

# UI
@onready var login_ui = $CanvasLayer/LoginUI
@onready var chat_ui = $CanvasLayer/ChatUI
@onready var login_button: Button = $CanvasLayer/LoginUI/Button_login
@onready var username_input: LineEdit = $CanvasLayer/LoginUI/LineEdit_username
@onready var password_input: LineEdit = $CanvasLayer/LoginUI/LineEdit_password 
@onready var chat_input: LineEdit = $CanvasLayer/ChatUI/LineEdit_chatInput
@onready var chat_send: Button = $CanvasLayer/ChatUI/Button_send
@onready var chat_log: TextEdit = $CanvasLayer/ChatUI/TextEdit_chatLog

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

	if not network.is_connected("login_successful", self._on_login_successful):
		network.connect("login_successful", self._on_login_successful)

	set_process(true)
	set_process_input(true)

# -------------------------------
# --- PROCESO PRINCIPAL
# -------------------------------
func _process(delta):
	if not network.connected or network.player_id == -1:
		return

	# ⚙️ ACTUALIZAR OTROS JUGADORES (pero no el local)
	for key in network.players.keys():
		var id = int(key)
		var data = network.players[key]

		if id in players:
			var player_node = players[id]

			if id != network.player_id:
				# ⚙️ Solo actualiza a los demás jugadores
				player_node.position = Vector2(data.x, data.y)
				player_node.update_animation(Vector2.ZERO, false, false)

			_update_player_hp(player_node, data.hp, id)
		else:
			_spawn_player(id, data.username, Vector2(data.x, data.y), data.hp)

	# Enemigos
	for key in network.enemies.keys():
		var id = int(key)
		var data = network.enemies[key]
		if id in enemies:
			enemies[id].position = Vector2(data.x, data.y)
		else:
			_spawn_enemy(id, data.type, Vector2(data.x, data.y))

	# Limpiar desconectados
	for id in players.keys():
		if not network.players.has(str(id)):
			players[id].queue_free()
			players.erase(id)

	for id in enemies.keys():
		if not network.enemies.has(str(id)):
			enemies[id].queue_free()
			enemies.erase(id)

	# ⚙️ MOVIMIENTO LOCAL CON FÍSICA
	var player = players.get(network.player_id, null)
	if player and player is CharacterBody2D:
		_handle_movement(delta, player)

		var my_data = network.players.get(str(network.player_id), null)
		if my_data:
			_update_player_hp(player, my_data.hp, network.player_id)

	# Ataque continuo
	if attack_held:
		attack_timer -= delta
		if attack_timer <= 0:
			attack_timer = attack_cooldown
			_attack_near_target(get_global_mouse_position())

	# Roll timers
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
			roll_cooldown_timer = roll_cooldown

	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta

# -------------------------------
# --- MOVIMIENTO (ahora con colisiones)
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

	# ⚙️ Movimiento con colisiones reales
	var velocity = Vector2.ZERO
	if is_rolling:
		velocity = move_dir * roll_speed
	else:
		velocity = move_dir * speed

	player.velocity = velocity
	player.move_and_slide()  # ⚙️ física de Godot

	# Enviar posición al servidor (solo del jugador local)
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
func _attack_near_target(mouse_pos: Vector2):
	for enemy_id in enemies.keys():
		var enemy = enemies[enemy_id]
		if enemy.position.distance_to(mouse_pos) < 30:
			network.attack("enemy", enemy_id, 10)
			return

	for player_id in players.keys():
		if player_id == network.player_id:
			continue
		var other = players[player_id]
		if other.position.distance_to(mouse_pos) < 30:
			network.attack("player", player_id, 10)
			return

# -------------------------------
# --- SPAWN JUGADOR
# -------------------------------
func _spawn_player(id: int, username: String, pos: Vector2, hp: int = 100):
	var instance: Player = PlayerScene.instantiate()
	instance.position = pos
	instance.name = str(id)
	player_container.add_child(instance)
	players[id] = instance

	# Nombre
	var name_label = instance.get_node_or_null("nombre")
	if name_label:
		name_label.text = username

	# Cámara
	if id == network.player_id:
		var cam = instance.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()

	# HP
	var bar = instance.get_node_or_null("ProgressBar")
	if bar:
		bar.max_value = 100
		bar.value = hp
		bar.queue_redraw()

	# Sprite
	var sprite = instance.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.animation = "Idle"
		sprite.play()

	# Collider
	var collider = instance.get_node_or_null("CollisionShape2D")
	if collider:
		collider.disabled = false
		if collider.shape == null:
			collider.shape = RectangleShape2D.new()

		collider.position = Vector2(-3, 27)
		collider.scale = Vector2(2, 3.5)
		collider.shape.extents = Vector2(10, 10)
		print("[SPAWN] ✅ CollisionShape2D configurado en pos", collider.position, "y escala", collider.scale)
	else:
		print("[SPAWN] ❌ No se encontró CollisionShape2D en el Player")

	if instance is CharacterBody2D:
		instance.collision_layer = 1
		instance.collision_mask = 5
		
	print("[SPAWN] Jugador", username, "spawned at", pos)

# -------------------------------
# --- ENEMIGOS / HP / UI
# -------------------------------
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
		if id == network.player_id and bar.value <= 0:
			print("[GAME OVER] Jugador muerto. Cerrando juego...")
			get_tree().quit()

func _update_player_hp(player: Node2D, hp_value: int, id: int):
	update_player_hp(id, hp_value)
	if id == network.player_id:
		print("[HP UPDATE] Jugador local HP:", hp_value)
	else:
		print("[HP UPDATE] Jugador", id, "HP:", hp_value)

func _on_login_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	if username != "" and password != "":
		current_username = username
		network.login_user(username, password)

func _on_chat_send_pressed():
	var text = chat_input.text.strip_edges()
	if text != "":
		network.send_chat(text)
		chat_input.text = ""

func _on_login_successful():
	login_ui.visible = false
	chat_ui.visible = true
	chat_log.clear()
