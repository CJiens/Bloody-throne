extends CharacterBody2D
class_name Player

# -------------------------------
# --- PROPIEDADES DEL JUGADOR
# -------------------------------
var id: int
var hp: int = 100
var max_hp: int = 100
var animation_state: String = "Idle"
var classe: String = "warrior"
var team: int = 1

# Movimiento
var move_dir := Vector2.ZERO
var speed := 200.0
var speed_multiplier: float = 1.0

# Ataque - CONFIGURACIÓN POR CLASE
var attack_range: float = 40.0
var attack_cone_angle: float = deg_to_rad(45.0)
var attack_damage: int = 10
var attack_cooldown: float = 0.5
var attack_timer: float = 0.0
var can_attack_var: bool = true
var is_ranged: bool = false

# Estadísticas mejoradas por cartas
var gold_bonus: int = 0
var attack_speed_bonus: int = 0
var critical_chance: int = 0

# Roll
var is_rolling := false
var roll_speed := 450.0
var roll_duration := 0.35
var roll_cooldown := 1.0
var roll_timer: float = 0.0
var roll_cooldown_timer: float = 0.0

# Nodos
@onready var hp_bar: ProgressBar = $ProgressBar
@onready var hitbox_area: Area2D = $HitboxArea
@onready var hitbox_collision: CollisionShape2D = $HitboxArea/CollisionShape2D
@onready var hplabel: Label = $Camera2D/PlayerInfoUI/HPLabel
# AnimatedSprites por clase
@onready var warrior_sprite: AnimatedSprite2D = $WarriorSprite
@onready var mage_sprite: AnimatedSprite2D = $MageSprite
@onready var archer_sprite: AnimatedSprite2D = $ArcherSprite
@onready var rogue_sprite: AnimatedSprite2D = $RogueSprite

# Sprite activo actualmente
var current_sprite: AnimatedSprite2D

# Proyectil por clase
var projectile_scene: PackedScene

# Configuraciones por clase
var class_configs := {
	"warrior": {
		"hp": 150,
		"speed": 180,
		"attack_damage": 15,
		"attack_range": 50,
		"is_ranged": false,
		"attack_cooldown": 0.6,
		"sprite": null,
		"projectile": preload("res://projectiles/WarriorProjectile.tscn")
	},
	"mage": {
		"hp": 80,
		"speed": 160,
		"attack_damage": 12,
		"attack_range": 300,
		"is_ranged": true,
		"attack_cooldown": 0.8,
		"sprite": null,
		"projectile": preload("res://projectiles/MageProjectile.tscn")
	},
	"archer": {
		"hp": 100,
		"speed": 200,
		"attack_damage": 10,
		"attack_range": 250,
		"is_ranged": true,
		"attack_cooldown": 0.5,
		"sprite": null,
		"projectile": preload("res://projectiles/ArcherProjectile.tscn")
	},
	"rogue": {
		"hp": 90,
		"speed": 220,
		"attack_damage": 12,
		"attack_range": 45,
		"is_ranged": false,
		"attack_cooldown": 0.4,
		"sprite": null,
		"projectile": preload("res://projectiles/RogueProjectile.tscn")
	}
}

# -------------------------------
# --- NUEVO: UI DEL JUGADOR (ACTUALIZADO)
# -------------------------------
@onready var wave_ui: Control = $Camera2D/WaveUI
@onready var decision_ui: Control = $Camera2D/DecisionUI
@onready var player_info_ui: Control = $Camera2D/PlayerInfoUI
@onready var stats_ui: Control = $Camera2D/StatsUI
@onready var wave_label: Label = $Camera2D/WaveUI/WaveLabel
@onready var enemy_count_label: Label = $Camera2D/WaveUI/EnemyCountLabel
@onready var currency_label: Label = $Camera2D/DecisionUI/HBoxContainer/CurrencyLabel

# NUEVO: Elementos del PlayerInfoUI básico
@onready var player_currency_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer/Monedas
@onready var player_hp_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer/Monedas
@onready var player_class_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer/ClassLabel

# NUEVO: Elementos del StatsUI (detallado)
@onready var stats_hp_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer/StatsHPLabel
@onready var stats_damage_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer2/StatsDamageLabel
@onready var stats_speed_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer3/StatsSpeedLabel
@onready var stats_attack_speed_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer2/StatsAttackSpeedLabel
@onready var stats_critical_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer2/StatsCriticalLabel
@onready var stats_gold_bonus_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer3/StatsGoldBonusLabel
@onready var stats_kills_label: Label = $Camera2D/StatsUI/Panel/MarginContainer/HBoxContainer/GridContainer2/StatsKillsLabel

# NUEVO: Nodos para las tarjetas
@onready var card_1: Control = $Camera2D/DecisionUI/HBoxContainer2/Card1
@onready var card_2: Control = $Camera2D/DecisionUI/HBoxContainer2/Card2
@onready var card_3: Control = $Camera2D/DecisionUI/HBoxContainer2/Card3

# Variables para controlar UI
var current_wave: int = 0
var enemies_remaining: int = 0
var player_currency: int = 0
var in_decision_period: bool = false
var decision_time_remaining: float = 0.0

# NUEVO: Variables para tarjetas
var available_cards: Array = []
var card_ui_nodes: Array = []

# NUEVO: Estadísticas del jugador
var enemies_killed: int = 0
var damage_dealt: int = 0
var show_detailed_stats: bool = false

# -------------------------------
# --- MÉTODOS DE ACCESO
# -------------------------------
func set_player_id(new_id: int) -> void:
	id = new_id

func get_player_id() -> int:
	return id

func set_classe(new_classe: String) -> void:
	classe = new_classe
	_apply_class_config()

func set_team(new_team: int) -> void:
	team = new_team

# -------------------------------
# --- CONFIGURACIÓN DE CLASE
# -------------------------------
func _apply_class_config():
	var config = class_configs.get(classe, class_configs["warrior"])
	
	hp = config.hp
	max_hp = config.hp
	speed = config.speed
	attack_damage = config.attack_damage
	attack_range = config.attack_range
	is_ranged = config.is_ranged
	attack_cooldown = config.attack_cooldown
	projectile_scene = config.projectile
	
	_setup_class_sprite()
	
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	_update_player_info()
	
	print("🎯 CLASE CONFIGURADA - ", classe, " HP:", hp, " Rango:", attack_range, " Ranged:", is_ranged)

# -------------------------------
# --- CONFIGURACIÓN DE SPRITES POR CLASE
# -------------------------------
func _setup_class_sprite():
	if warrior_sprite:
		warrior_sprite.visible = false
	if mage_sprite:
		mage_sprite.visible = false
	if archer_sprite:
		archer_sprite.visible = false
	if rogue_sprite:
		rogue_sprite.visible = false
	
	match classe:
		"warrior":
			current_sprite = warrior_sprite
		"mage":
			current_sprite = mage_sprite
		"archer":
			current_sprite = archer_sprite
		"rogue":
			current_sprite = rogue_sprite
		_:
			current_sprite = warrior_sprite
	
	if current_sprite:
		current_sprite.visible = true
		print("👤 SPRITE ACTIVADO - Clase:", classe, " Sprite:", current_sprite.name)

func get_projectile_scene() -> PackedScene:
	return projectile_scene

# -------------------------------
# --- PROCESO DEL JUGADOR
# -------------------------------
func _ready():
	if hitbox_area:
		hitbox_area.set_collision_layer_value(6, true)
		hitbox_area.set_collision_mask_value(3, true)
		
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hplabel.text = str(hp) + "/" + str(max_hp)
	add_to_group("players")
	
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, true)
	set_collision_mask_value(5, false)
	
	var collision_shape = $CollisionShape2D
	if collision_shape:
		collision_shape.disabled = false
	
	if hitbox_area:
		hitbox_area.set_collision_layer_value(6, true)
		hitbox_area.set_collision_mask_value(3, true)
		hitbox_area.set_collision_mask_value(1, false)
		hitbox_area.set_collision_mask_value(2, false)
		hitbox_area.set_collision_mask_value(4, false)
		hitbox_area.set_collision_mask_value(5, false)
		
		if not hitbox_area.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox_area.area_entered.connect(_on_hitbox_area_entered)
		
		if hitbox_collision:
			hitbox_collision.disabled = false
	
	_setup_player_ui()
	_setup_cards_ui()
	
	if not Network.card_purchased.is_connected(_on_card_purchased):
		Network.card_purchased.connect(_on_card_purchased)

	
	# ✅ CORREGIDO: Conectar señal currency_updated con player_id
	if not Network.currency_updated.is_connected(_on_currency_updated):
		Network.currency_updated.connect(_on_currency_updated)
	
	_apply_class_config()
	print("👤 JUGADOR LISTO - ID:", id, " Clase:", classe, " Hitbox: ACTIVADO")
	

func _process(delta):
	print("Esta es la pocision de la x => " + str(get_local_mouse_position().x) + "Esta es la pocision de la y =>" + str(get_local_mouse_position().y))
	_handle_cooldowns(delta)
	
	if in_decision_period:
		decision_time_remaining -= delta
		if decision_time_remaining <= 0:
			in_decision_period = false
			hide_game_ui()

func _physics_process(delta):
	if id == Network.player_id:
		_handle_local_movement(delta)
		_handle_input()

# -------------------------------
# --- NUEVO: MANEJO DE INPUT PARA ESTADÍSTICAS
# -------------------------------
func _handle_input():
	if id != Network.player_id:
		return
	
	# Tecla Tab para mostrar/ocultar estadísticas detalladas
	if Input.is_action_just_pressed("show_stats"):
		_toggle_detailed_stats()

func _toggle_detailed_stats():
	show_detailed_stats = !show_detailed_stats
	
	if stats_ui:
		stats_ui.visible = show_detailed_stats
	
	if show_detailed_stats:
		print("📊 MOSTRANDO ESTADÍSTICAS DETALLADAS")
		_update_detailed_stats()
	else:
		print("📊 OCULTANDO ESTADÍSTICAS DETALLADAS")

# -------------------------------
# --- SISTEMA DE UI DEL JUGADOR (ACTUALIZADO)
# -------------------------------
func _setup_player_ui():
	if wave_ui:
		wave_ui.visible = false
	if decision_ui:
		decision_ui.visible = false
	if player_info_ui:
		player_info_ui.visible = true
	if stats_ui:
		stats_ui.visible = false # Inicialmente oculto
	
	_update_player_info()

func _setup_cards_ui():
	card_ui_nodes = [card_1, card_2, card_3]
	for card_ui in card_ui_nodes:
		if card_ui:
			card_ui.visible = false
			var buy_button = card_ui.get_node_or_null("Panel/VBoxContainer/HBoxContainer/BuyButton")
			if buy_button and not buy_button.pressed.is_connected(_on_card_buy_pressed):
				buy_button.pressed.connect(_on_card_buy_pressed.bind(card_ui))

# NUEVO: Actualizar información básica del jugador
func _update_player_info():
	if player_info_ui:
		if player_currency_label:
			player_currency_label.text = "Monedas: %d" % player_currency
		if player_hp_label:
			player_hp_label.text = "HP: %d/%d" % [hp, max_hp]
		if player_class_label:
			player_class_label.text = "Clase: %s" % classe.capitalize()

# NUEVO: Actualizar estadísticas detalladas
func _update_detailed_stats():
	if not stats_ui or not show_detailed_stats:
		return
	
	# Calcular velocidad real con multiplicadores
	var real_speed = speed * speed_multiplier
	
	# Calcular cooldown de ataque real con bonus
	var real_attack_cooldown = attack_cooldown * (1.0 - (attack_speed_bonus / 100.0))
	if real_attack_cooldown < 0.1: # Límite mínimo
		real_attack_cooldown = 0.1
	
	if stats_hp_label:
		stats_hp_label.text = "Vida: %d/%d" % [hp, max_hp]
	if stats_damage_label:
		stats_damage_label.text = "Daño: %d" % attack_damage
	if stats_speed_label:
		stats_speed_label.text = "Velocidad: %d (x%.1f)" % [real_speed, speed_multiplier]
	if stats_attack_speed_label:
		stats_attack_speed_label.text = "Vel. Ataque: %.1fs (-%d%%)" % [real_attack_cooldown, attack_speed_bonus]
	if stats_critical_label:
		stats_critical_label.text = "Crítico: %d%%" % critical_chance
	if stats_gold_bonus_label:
		stats_gold_bonus_label.text = "Bonus Oro: +%d%%" % gold_bonus
	if stats_kills_label:
		stats_kills_label.text = "Enemigos Eliminados: %d" % enemies_killed
	
	print("📊 ESTADÍSTICAS ACTUALIZADAS:")
	print("  - Vida: %d/%d" % [hp, max_hp])
	print("  - Daño: %d" % attack_damage)
	print("  - Velocidad: %d (x%.1f)" % [real_speed, speed_multiplier])
	print("  - Vel. Ataque: %.1fs (-%d%%)" % [real_attack_cooldown, attack_speed_bonus])
	print("  - Crítico: %d%%" % critical_chance)
	print("  - Bonus Oro: +%d%%" % gold_bonus)
	print("  - Eliminados: %d" % enemies_killed)

func add_currency_for_kill(enemy_type: String, amount: int = 0):
	var base_reward = 0
	
	match enemy_type:
		"grunt":
			base_reward = 5
		"archer":
			base_reward = 8
		"mage":
			base_reward = 10
		"boss":
			base_reward = 50
		_:
			base_reward = 5
	
	# Aplicar bonus de oro
	var reward = amount if amount > 0 else base_reward
	if gold_bonus > 0:
		var bonus_amount = int(reward * (gold_bonus / 100.0))
		reward += bonus_amount
		print("💰 BONUS DE ORO APLICADO: +%d (%d%%)" % [bonus_amount, gold_bonus])
	
	player_currency += reward
	enemies_killed += 1
	
	print("💰 JUGADOR %d GANÓ %d MONEDAS POR MATAR %s - Total: %d" % [id, reward, enemy_type, player_currency])
	
	_update_player_info()
	if show_detailed_stats:
		_update_detailed_stats()
	
	if id == Network.player_id:
		Network.request_currency_update(player_currency)

func update_wave_ui(wave_number: int, enemy_count: int):
	current_wave = wave_number
	enemies_remaining = enemy_count
	in_decision_period = false
	
	if wave_label:
		wave_label.text = "OLEADA %d" % wave_number
	if enemy_count_label:
		enemy_count_label.text = "Enemigos: %d" % enemy_count
	
	if wave_ui:
		wave_ui.visible = true
	if decision_ui:
		decision_ui.visible = false
	
	print("🌊 UI ACTUALIZADA - Oleada:", wave_number, " Enemigos:", enemy_count)

# -------------------------------
# --- SISTEMA DE DECISIONES Y CARTAS
# -------------------------------
func show_decision_period(duration: float, currency: int = 0, cards: Array = []):
	player_currency = currency
	in_decision_period = true
	decision_time_remaining = duration
	available_cards = cards
	
	print("🃏 RECIBIENDO CARTAS EN CLIENTE - Jugador:", id, " Cantidad:", cards.size())
	
	if cards.size() == 0:
		print("❌ ADVERTENCIA: Array de cartas vacío recibido en Player.gd")
	else:
		for i in range(cards.size()):
			var card = cards[i]
			if card is Dictionary:
				print("  ✅ Carta %d: %s - %s (%d monedas)" % [i, card.get("name", "Sin nombre"), card.get("description", "Sin descripción"), card.get("cost", 0)])
			else:
				print("  ❌ Carta %d tiene formato incorrecto: %s" % [i, str(card)])
	
	if currency_label:
		currency_label.text = "Monedas: %d" % currency
	
	_display_available_cards()
	
	if wave_ui:
		wave_ui.visible = false
	if decision_ui:
		decision_ui.visible = true
	
	print("⏰ PERIODO DE DECISIONES - Duración:", duration, "s, Monedas:", currency, " Cartas:", cards.size())

func _display_available_cards():
	for i in range(card_ui_nodes.size()):
		var card_ui = card_ui_nodes[i]
		if card_ui and i < available_cards.size():
			var card_data = available_cards[i]
			_setup_card_ui(card_ui, card_data)
			card_ui.visible = true
		elif card_ui:
			card_ui.visible = false

func _setup_card_ui(card_ui: Control, card_data: Dictionary):
	var name_label = card_ui.get_node_or_null("Panel/VBoxContainer/CardName")
	var desc_label = card_ui.get_node_or_null("Panel/VBoxContainer/CardDescription")
	var cost_label = card_ui.get_node_or_null("Panel/VBoxContainer/CardCost")
	var buy_button = card_ui.get_node_or_null("Panel/HBoxContainer/HBoxContainer/BuyButton")
	
	if name_label:
		name_label.text = card_data.get("name", "Carta Sin Nombre")
	if desc_label:
		desc_label.text = card_data.get("description", "Sin descripción")
	if cost_label:
		cost_label.text = "Costo: %d" % card_data.get("cost", 0)
	if buy_button:
		buy_button.disabled = player_currency < card_data.get("cost", 0)
		buy_button.text = "Comprar (%d)" % card_data.get("cost", 0)

func _on_card_buy_pressed(card_ui: Control):
	if not in_decision_period:
		return
		
	var card_index = card_ui_nodes.find(card_ui)
	if card_index == -1 or card_index >= available_cards.size():
		return
		
	var card_data = available_cards[card_index]
	
	if player_currency >= card_data.get("cost", 0) and id == Network.player_id:
		print("🃏 COMPRANDO CARTA:", card_data.get("name", "Sin nombre"))
		Network.purchase_card(card_data.get("id", ""))
	else:
		print("❌ NO SE PUEDE COMPRAR CARTA - Fondos insuficientes o no es jugador local")

func _on_card_purchased(card_data: Dictionary, new_balance: int):
	print("✅ CARTA COMPRADA EXITOSAMENTE:", card_data.get("name", "Sin nombre"))
	player_currency = new_balance
	
	# Aplicar efecto de la carta localmente
	_apply_card_effect(card_data)
	
	_update_player_info()
	if show_detailed_stats:
		_update_detailed_stats()
	
	_show_card_purchase_effect(card_data)
	
	for i in range(available_cards.size()):
		if available_cards[i].get("id", "") == card_data.get("id", ""):
			if i < card_ui_nodes.size() and card_ui_nodes[i]:
				card_ui_nodes[i].visible = false
			break

# ✅ CORREGIDO: Nueva función para manejar actualización de monedas con player_id
func _on_currency_updated(target_player_id: int, amount: int):
	# Solo actualizar si es para este jugador
	if target_player_id == id:
		print("💰 ACTUALIZANDO MONEDAS LOCALES - Jugador:", id, " Cantidad:", amount)
		update_currency(amount)

# NUEVO: Aplicar efecto de carta localmente
func _apply_card_effect(card_data: Dictionary):
	var card_type = card_data.get("type", "")
	var card_value = card_data.get("value", 0)
	
	match card_type:
		"damage":
			attack_damage += card_value
			print("⚔️ DAÑO AUMENTADO: %d -> %d" % [attack_damage - card_value, attack_damage])
		"health":
			max_hp += card_value
			hp += card_value
			print("❤️ VIDA AUMENTADA: %d -> %d" % [max_hp - card_value, max_hp])
		"gold_bonus":
			gold_bonus += card_value
			print("💰 BONUS ORO: +%d%%" % gold_bonus)
		"speed":
			speed_multiplier += card_value / 100.0
			print("🏃 VELOCIDAD AUMENTADA: x%.2f" % speed_multiplier)
		"attack_speed":
			attack_speed_bonus += card_value
			print("⚡ VEL. ATAQUE AUMENTADA: -%d%%" % attack_speed_bonus)
		"critical":
			critical_chance += card_value
			print("🎯 PROB. CRÍTICO: %d%%" % critical_chance)

func _show_card_purchase_effect(card_data: Dictionary):
	modulate = Color(0.5, 1, 0.5)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	
	_show_floating_text("+ " + card_data.get("name", "Mejora"), Color.GOLD)

func _show_floating_text(text: String, color: Color = Color.WHITE):
	var floating_text = Label.new()
	floating_text.text = text
	floating_text.add_theme_color_override("font_color", color)
	floating_text.add_theme_font_size_override("font_size", 16)
	floating_text.position = Vector2(-30, -50)
	add_child(floating_text)
	
	var tween = create_tween()
	tween.parallel().tween_property(floating_text, "position", Vector2(-30, -100), 1.0)
	tween.parallel().tween_property(floating_text, "modulate", Color(1, 1, 1, 0), 1.0)
	tween.tween_callback(floating_text.queue_free)

func hide_game_ui():
	if wave_ui:
		wave_ui.visible = false
	if decision_ui:
		decision_ui.visible = false
	
	for card_ui in card_ui_nodes:
		if card_ui:
			card_ui.visible = false
		
	in_decision_period = false
	available_cards.clear()
	print("🎮 UI DE DECISIONES OCULTADA")

func update_currency(amount: int):
	player_currency = amount
	if currency_label and decision_ui and decision_ui.visible:
		currency_label.text = "Monedas: %d" % amount
	
	_update_player_info()
	
	if in_decision_period:
		_update_card_buttons_state()
	
	print("💰 MONEDAS ACTUALIZADAS - Jugador %d: %d" % [id, amount])

func _update_card_buttons_state():
	for i in range(card_ui_nodes.size()):
		var card_ui = card_ui_nodes[i]
		if card_ui and card_ui.visible and i < available_cards.size():
			var buy_button = card_ui.get_node_or_null("Panel/HBoxContainer/HBoxContainer/BuyButton")
			var card_data = available_cards[i]
			if buy_button and card_data:
				buy_button.disabled = player_currency < card_data.get("cost", 0)

# -------------------------------
# --- MOVIMIENTO LOCAL
# -------------------------------
func _handle_local_movement(delta: float):
	if is_rolling:
		velocity = move_dir * roll_speed * speed_multiplier
	else:
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
			velocity = move_dir * speed * speed_multiplier
		else:
			velocity = Vector2.ZERO

	var last_position = position
	set_velocity(velocity)
	set_up_direction(Vector2.UP)
	move_and_slide()

	if position == last_position and velocity != Vector2.ZERO:
		print("🧱 COLISIÓN LOCAL CON PARED - Jugador:", id)
		modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		modulate = Color.WHITE

	if Network.connected and id == Network.player_id and velocity != Vector2.ZERO:
		Network.move_player(position.x, position.y)

	update_animation(move_dir, false, is_rolling)

# -------------------------------
# --- SISTEMA DE ATAQUE UNIFICADO
# -------------------------------
func execute_attack(mouse_pos: Vector2):
	if not can_attack_var:
		return

	print("🎯 ATAQUE EJECUTADO - Jugador:", id, " Clase:", classe, " Ranged:", is_ranged)
	
	can_attack_var = false
	
	# Aplicar bonus de velocidad de ataque
	var actual_cooldown = attack_cooldown * (1.0 - (attack_speed_bonus / 100.0))
	if actual_cooldown < 0.1:
		actual_cooldown = 0.1
	
	attack_timer = actual_cooldown
	
	# Verificar golpe crítico
	var actual_damage = attack_damage
	var is_critical = false
	if critical_chance > 0 and randf() * 100 < critical_chance:
		actual_damage *= 2
		is_critical = true
		print("🎯 ¡GOLPE CRÍTICO! Daño: %d" % actual_damage)
	
	var attack_dir = (mouse_pos - global_position).normalized()
	var anim_name = _get_direction_animation(attack_dir.angle(), "attack")
	
	if current_sprite and current_sprite.sprite_frames and current_sprite.sprite_frames.has_animation(anim_name):
		print("🎬 Reproduciendo animación: ", anim_name)
		current_sprite.animation = anim_name
		animation_state = anim_name
		if id == Network.player_id:
			Network.send_player_state(anim_name)
		current_sprite.play()
	else:
		print("❌ Animación no encontrada: ", anim_name, " en sprite:", current_sprite.name)

func can_attack() -> bool:
	return can_attack_var

# -------------------------------
# --- SISTEMA DE ROLL
# -------------------------------
func try_roll():
	if not is_rolling and roll_cooldown_timer <= 0:
		is_rolling = true
		roll_timer = roll_duration
		print("🎯 ROLL EJECUTADO - Jugador:", id)

# -------------------------------
# --- ANIMACIONES
# -------------------------------
func update_animation(dir: Vector2, attacking: bool = false, rolling: bool = false):
	if not current_sprite:
		return

	if not can_attack_var:
		return

	var anim_name := "Idle"

	if rolling:
		var vec = dir
		if vec == Vector2.ZERO:
			vec = get_global_mouse_position() - global_position
		anim_name = _get_direction_animation(vec.angle(), "roll")
	elif dir != Vector2.ZERO:
		anim_name = _get_direction_animation(dir.angle(), "run")

	if current_sprite.animation != anim_name:
		current_sprite.animation = anim_name
		animation_state = anim_name
		if id == Network.player_id:
			Network.send_player_state(anim_name)
		current_sprite.play()

func set_remote_animation(anim_name: String):
	if current_sprite and current_sprite.sprite_frames and current_sprite.sprite_frames.has_animation(anim_name):
		if current_sprite.animation != anim_name:
			current_sprite.animation = anim_name
			current_sprite.play()

func _get_direction_animation(angle: float, action: String) -> String:
	if not current_sprite:
		return "Idle"
	
	var direction := ""
	
	if angle >= -PI / 8 and angle < PI / 8:
		direction = "E"
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		direction = "SE"
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		direction = "S"
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		direction = "SW"
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		direction = "W"
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		direction = "NW"
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		direction = "N"
	elif angle >= -3 * PI / 8 and angle < -PI / 8:
		direction = "NE"
	
	if direction == "":
		return action
	else:
		return action + "_" + direction

# -------------------------------
# --- SISTEMA DE VIDA (ACTUALIZADO)
# -------------------------------
func update_hp(new_hp: int):
	hp = clamp(new_hp, 0, max_hp)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hplabel.text = str(hp) + "/" + str(max_hp)
	
	_update_player_info()
	if show_detailed_stats:
		_update_detailed_stats()
	
	print("❤️  ACTUALIZANDO HP - Jugador:", id, " HP:", hp, "/", max_hp)
	
	if hp <= 0:
		play_death_animation()

func take_damage(amount: int):
	print("💥 JUGADOR RECIBIÓ DAÑO - ID:", id, " Cantidad:", amount, " HP Antes:", hp)
	update_hp(hp - amount)

func play_death_animation():
	if not current_sprite:
		if id == Network.player_id:
			_convert_to_ghost()
		return

	print("💀 JUGADOR MUERTO - ID:", id)
	if current_sprite.sprite_frames and current_sprite.sprite_frames.has_animation("Die"):
		current_sprite.play("Die")
	else:
		current_sprite.play("Idle")
	
	if id == Network.player_id:
		Network.send_player_state("Die")
		await current_sprite.animation_finished
		_convert_to_ghost()

# -------------------------------
# --- COOLDOWNS
# -------------------------------
func _handle_cooldowns(delta):
	if not can_attack_var:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack_var = true

	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
			roll_cooldown_timer = roll_cooldown

	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta

# -------------------------------
# --- COLISIONES CON PROYECTILES
# -------------------------------
func _on_hitbox_area_entered(area):
	if area is Projectile:
		var projectile = area as Projectile
		print("🎯 PROYECTIL GOLPEÓ JUGADOR - Proyectil:", projectile.projectile_id, " Jugador:", id)
		
		if projectile.projectile_owner_id == id:
			print("🚫 AUTO-DAÑO IGNORADO")
			return
		
		Network.projectile_hit_player(projectile.projectile_id, id, projectile.projectile_damage)
		
		take_damage(projectile.projectile_damage)
		
		_create_hit_effect()

func _create_hit_effect():
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

# -------------------------------
# --- CONVERSIÓN A FANTASMA AL MORIR
# -------------------------------
func _convert_to_ghost():
	print("👻 CONVIRTIENDO JUGADOR EN FANTASMA - ID:", id)
	
	if Network.connected and Network.ws_ready:
		Network.player_became_ghost(id)
	
	if get_parent().has_method("replace_player_with_ghost"):
		get_parent().replace_player_with_ghost(id)
