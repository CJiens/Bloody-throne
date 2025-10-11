extends CharacterBody2D
class_name Player

# -------------------------------
# --- PROPIEDADES DEL JUGADOR
# -------------------------------
var id: int
var hp: int = 100
var max_hp: int = 200
var animation_state: String = "Idle"

# Movimiento
var move_dir := Vector2.ZERO
var speed := 200.0

# Ataque - VALORES POR DEFECTO
var attack_range: float = 40.0
var attack_cone_angle: float = deg_to_rad(45.0)
var attack_damage: int = 10
var attack_cooldown: float = 0.5  # Aumentado para que sea más visible
var attack_timer: float = 0.0
var can_attack_var: bool = true

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
@onready var hit_area: Area2D = $HitArea

# -------------------------------
# --- MÉTODOS DE ACCESO
# -------------------------------
func set_player_id(new_id: int) -> void:
	id = new_id

func get_player_id() -> int:
	return id

# -------------------------------
# --- PROCESO DEL JUGADOR
# -------------------------------
func _ready():
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp

	# DEBUG: Conectar señal de área entrante
	if hit_area:
		if not hit_area.area_entered.is_connected(_on_area_entered):
			hit_area.area_entered.connect(_on_area_entered)
		print("✅ HitArea conectado - Jugador:", id)
	else:
		print("❌ No se encontró HitArea - Jugador:", id)
	
	print("👤 JUGADOR LISTO - ID:", id)

func _process(delta):
	_handle_cooldowns(delta)

func _physics_process(delta):
	if id == Network.player_id:
		_handle_local_movement(delta)

# -------------------------------
# --- MOVIMIENTO LOCAL
# -------------------------------
func _handle_local_movement(delta: float):
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

	var current_speed = roll_speed if is_rolling else speed
	velocity = move_dir * current_speed
	move_and_slide()

	if Network.connected:
		Network.move_player(position.x, position.y)

	update_animation(move_dir, false, is_rolling)

# -------------------------------
# --- SISTEMA DE ATAQUE (MUY SIMPLE)
# -------------------------------
func execute_attack(mouse_pos: Vector2):
	if not can_attack_var:
		return

	print("🎯 ATAQUE EJECUTADO - Jugador:", id)  # DEBUG
	
	can_attack_var = false
	attack_timer = attack_cooldown
	
	var attack_dir = (mouse_pos - global_position).normalized()
	var anim_name = _get_direction_animation(attack_dir.angle(), "attack")
	
	# Simplemente reproducir la animación de ataque
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		print("🎬 Reproduciendo animación: ", anim_name)  # DEBUG
		sprite.animation = anim_name
		animation_state = anim_name
		if id == Network.player_id:
			Network.send_player_state(anim_name)
		sprite.play()
	else:
		print("❌ Animación no encontrada: ", anim_name)  # DEBUG

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
# --- ANIMACIONES (SIMPLIFICADO)
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
			print("✅ Ataque listo de nuevo - Jugador:", id)  # DEBUG

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
# --- DEBUG DE COLISIONES
# -------------------------------
func _on_area_entered(area):
	print("🔄 JUGADOR ", id, " DETECTÓ ÁREA:", area.name, " Tipo:", area.get_class())
	
	if area is Projectile:
		var projectile = area as Projectile
		print("💥 PROYECTIL COLISIONÓ CON JUGADOR ", id)
		print("   - Proyectil Owner:", projectile.projectile_owner_id)
		print("   - Proyectil Remote:", projectile.is_remote)
		print("   - Proyectil ID:", projectile.projectile_id)
		print("   - Proyectil Damage:", projectile.projectile_damage)
		
		# Verificar si el proyectil es del mismo jugador
		if projectile.projectile_owner_id == id:
			print("   🚫 AUTO-DAÑO - No se aplica daño")
		else:
			print("   💥 DAÑO APLICABLE - Target diferente al owner")