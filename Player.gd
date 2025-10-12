extends CharacterBody2D
class_name Player

# -------------------------------
# --- PROPIEDADES DEL JUGADOR
# -------------------------------
var id: int
var hp: int = 100
var max_hp: int = 200
var animation_state: String = "Idle"
var classe: String = "warrior"

# Movimiento
var move_dir := Vector2.ZERO
var speed := 200.0

# Ataque - CONFIGURACIÓN POR CLASE
var attack_range: float = 40.0
var attack_cone_angle: float = deg_to_rad(45.0)
var attack_damage: int = 10
var attack_cooldown: float = 0.5
var attack_timer: float = 0.0
var can_attack_var: bool = true
var is_ranged: bool = false

# Roll
var is_rolling := false
var roll_speed := 450.0
var roll_duration := 0.35
var roll_cooldown := 1.0
var roll_timer := 0.0
var roll_cooldown_timer := 0.0

# Nodos
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $ProgressBar

# Configuraciones por clase
var class_configs := {
	"warrior": {
		"hp": 150,
		"speed": 180,
		"attack_damage": 15,
		"attack_range": 50,
		"is_ranged": false,
		"attack_cooldown": 0.6
	},
	"mage": {
		"hp": 80,
		"speed": 160,
		"attack_damage": 12,
		"attack_range": 300,
		"is_ranged": true,
		"attack_cooldown": 0.8
	},
	"archer": {
		"hp": 100,
		"speed": 200,
		"attack_damage": 10,
		"attack_range": 250,
		"is_ranged": true,
		"attack_cooldown": 0.5
	},
	"rogue": {
		"hp": 90,
		"speed": 220,
		"attack_damage": 12,
		"attack_range": 45,
		"is_ranged": false,
		"attack_cooldown": 0.4
	}
}

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
	
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	print("🎯 CLASE CONFIGURADA - ", classe, " Rango:", attack_range, " Ranged:", is_ranged)

# -------------------------------
# --- PROCESO DEL JUGADOR
# -------------------------------
func _ready():
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	# DESACTIVAR COLISIONES LOCALES COMPLETAMENTE - El servidor maneja las colisiones
	set_collision_layer_value(1, true)  # Estamos en layer de players
	set_collision_mask_value(1, false)  # NO detectar otros jugadores
	set_collision_mask_value(2, false)  # NO detectar enemigos
	set_collision_mask_value(3, false)  # NO detectar proyectiles
	set_collision_mask_value(4, false)  # NO detectar paredes
	set_collision_mask_value(5, false)  # NO detectar environment
	
	# Desactivar CollisionShape2D
	var collision_shape = $CollisionShape2D
	if collision_shape:
		collision_shape.disabled = true
	
	# Desactivar Area2D si existe
	var area = $Area2D if has_node("Area2D") else null
	if area:
		area.set_collision_layer_value(1, false)
		area.set_collision_mask_value(1, false)
		area.monitoring = false
		area.monitorable = false
	
	_apply_class_config()
	print("👤 JUGADOR LISTO - ID:", id, " Clase:", classe, " Colisiones: DESACTIVADAS")

func _process(delta):
	_handle_cooldowns(delta)

func _physics_process(delta):
	if id == Network.player_id:
		_handle_local_movement(delta)

# -------------------------------
# --- MOVIMIENTO LOCAL (SIN COLISIONES LOCALES)
# -------------------------------
func _handle_local_movement(delta: float):
	if is_rolling:
		# Durante el roll, mantener la dirección actual
		velocity = move_dir * roll_speed
	else:
		# Movimiento normal
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
			velocity = move_dir * speed
		else:
			velocity = Vector2.ZERO

	# MOVIMIENTO SIN COLISIONES LOCALES - El servidor corrige si hay colisión
	set_velocity(velocity)
	set_up_direction(Vector2.UP)
	move_and_slide()

	# Solo enviar posición al servidor si es el jugador local
	if Network.connected and id == Network.player_id:
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
	attack_timer = attack_cooldown
	
	var attack_dir = (mouse_pos - global_position).normalized()
	var anim_name = _get_direction_animation(attack_dir.angle(), "attack")
	
	# Reproducir animación de ataque
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		print("🎬 Reproduciendo animación: ", anim_name)
		sprite.animation = anim_name
		animation_state = anim_name
		if id == Network.player_id:
			Network.send_player_state(anim_name)
		sprite.play()
	else:
		print("❌ Animación no encontrada: ", anim_name)

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
	if not sprite:
		return

	# Si está en cooldown de ataque, no cambiar animación
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

	if sprite.animation != anim_name:
		sprite.animation = anim_name
		animation_state = anim_name
		if id == Network.player_id:
			Network.send_player_state(anim_name)
		sprite.play()

func set_remote_animation(anim_name: String):
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.animation = anim_name
			sprite.play()

func _get_direction_animation(angle: float, type: String) -> String:
	if not sprite:
		return "Idle"
		
	if angle >= -PI / 8 and angle < PI / 8:
		return type + "_E"
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return type + "_SE"
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return type + "_S"
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return type + "_SW"
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return type + "_W"
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return type + "_NW"
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return type + "_N"
	elif angle >= -3 * PI / 8 and angle < -PI / 8:
		return type + "_NE"

	return "Idle"

# -------------------------------
# --- SISTEMA DE VIDA
# -------------------------------
func update_hp(new_hp: int):
	hp = clamp(new_hp, 0, max_hp)
	if hp_bar:
		hp_bar.value = hp
	
	print("❤️  ACTUALIZANDO HP - Jugador:", id, " HP:", hp)
	
	if hp <= 0:
		play_death_animation()

func take_damage(amount: int):
	print("💥 JUGADOR RECIBIÓ DAÑO - ID:", id, " Cantidad:", amount, " HP Antes:", hp)
	update_hp(hp - amount)

func play_death_animation():
	if not sprite:
		get_tree().quit()
		return

	print("💀 JUGADOR MUERTO - ID:", id)
	sprite.play("Die")
	if id == Network.player_id:
		Network.send_player_state("Die")
	await sprite.animation_finished
	if id == Network.player_id:
		get_tree().quit()

# -------------------------------
# --- COOLDOWNS
# -------------------------------
func _handle_cooldowns(delta):
	# Cooldown de ataque
	if not can_attack_var:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack_var = true
			print("✅ Ataque listo de nuevo - Jugador:", id)

	# Roll activo
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
			roll_cooldown_timer = roll_cooldown

	# Cooldown de roll
	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta

# -------------------------------
# --- DEBUG DE COLISIONES (SOLO VISUAL)
# -------------------------------
func _on_area_entered(area):
	# Esto es solo para feedback visual, el servidor maneja las colisiones reales
	print("👀 COLISIÓN VISUAL - Jugador:", id, " con:", area.name)
	
	if area is Projectile:
		var projectile = area as Projectile
		print("   - Proyectil Owner:", projectile.projectile_owner_id)
		print("   - Proyectil Remote:", projectile.is_remote)
		
		# Solo para efectos visuales, el servidor ya manejó el daño
		if projectile.projectile_owner_id != id:
			# Efecto visual de golpe (opcional)
			modulate = Color.RED
			await get_tree().create_timer(0.1).timeout
			modulate = Color.WHITE