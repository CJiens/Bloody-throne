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
@onready var hp_bar: ProgressBar = $ProgressBar
@onready var hitbox_area: Area2D = $HitboxArea
@onready var hitbox_collision: CollisionShape2D = $HitboxArea/CollisionShape2D

# AnimatedSprites por clase
@onready var warrior_sprite: AnimatedSprite2D = $WarriorSprite
@onready var mage_sprite: AnimatedSprite2D = $MageSprite
@onready var archer_sprite: AnimatedSprite2D = $ArcherSprite
@onready var rogue_sprite: AnimatedSprite2D = $RogueSprite
@onready var knight_sprite: AnimatedSprite2D = $KnightSprite

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
	"knight": {
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
	projectile_scene = config.projectile
	
	# Configurar el sprite activo
	_setup_class_sprite()
	
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	print("🎯 CLASE CONFIGURADA - ", classe, " HP:", hp, " Rango:", attack_range, " Ranged:", is_ranged)

# -------------------------------
# --- CONFIGURACIÓN DE SPRITES POR CLASE
# -------------------------------
func _setup_class_sprite():
	# Configurar el sprite activo según la clase
	match classe:
		"warrior":
			current_sprite = knight_sprite
			class_configs["warrior"].sprite = warrior_sprite
		"knight":
			current_sprite = knight_sprite
			class_configs["knight"].sprite = knight_sprite
		"mage":
			current_sprite = mage_sprite
			class_configs["mage"].sprite = mage_sprite
		"archer":
			current_sprite = archer_sprite
			class_configs["archer"].sprite = archer_sprite
		"rogue":
			current_sprite = rogue_sprite
			class_configs["rogue"].sprite = rogue_sprite
		_:
			current_sprite = warrior_sprite
			class_configs["warrior"].sprite = warrior_sprite
	
	# Mostrar el sprite activo
	if current_sprite:
		current_sprite.visible = true
		print("👤 SPRITE ACTIVADO - Clase:", classe, " Sprite:", current_sprite.name)

# Obtener la escena del proyectil de la clase
func get_projectile_scene() -> PackedScene:
	return projectile_scene

# -------------------------------
# --- PROCESO DEL JUGADOR
# -------------------------------
func _ready():
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	# ✅ CONFIGURACIÓN DE COLISIONES MEJORADA
	
	# Colisiones de movimiento (solo paredes)
	set_collision_layer_value(1, true) # Layer de players
	set_collision_mask_value(1, false) # NO otros jugadores
	set_collision_mask_value(2, false) # NO enemigos
	set_collision_mask_value(3, false) # NO proyectiles
	set_collision_mask_value(4, true) # ✅ SÍ paredes (TileMap)
	set_collision_mask_value(5, false) # NO environment
	
	# Reactivar CollisionShape2D para movimiento
	var collision_shape = $CollisionShape2D
	if collision_shape:
		collision_shape.disabled = false
	
	# ✅ CONFIGURAR HITBOX PARA PROYECTILES
	if hitbox_area:
		# Hitbox en layer diferente para proyectiles
		hitbox_area.set_collision_layer_value(6, true) # Layer de hitbox de jugadores
		hitbox_area.set_collision_mask_value(3, true) # ✅ SÍ detectar proyectiles
		hitbox_area.set_collision_mask_value(1, false) # NO jugadores
		hitbox_area.set_collision_mask_value(2, false) # NO enemigos
		hitbox_area.set_collision_mask_value(4, false) # NO paredes
		hitbox_area.set_collision_mask_value(5, false) # NO environment
		
		# Conectar señal de área entrante
		if not hitbox_area.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox_area.area_entered.connect(_on_hitbox_area_entered)
		
		if hitbox_collision:
			hitbox_collision.disabled = false
	
	_apply_class_config()
	print("👤 JUGADOR LISTO - ID:", id, " Clase:", classe, " Hitbox: ACTIVADO")

func _process(delta):
	_handle_cooldowns(delta)

func _physics_process(delta):
	if id == Network.player_id:
		_handle_local_movement(delta)

# -------------------------------
# --- MOVIMIENTO LOCAL (CON COLISIONES LOCALES)
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

	# ✅ MOVIMIENTO CON COLISIONES LOCALES ACTIVADAS
	var last_position = position
	set_velocity(velocity)
	set_up_direction(Vector2.UP)
	move_and_slide()

	# ✅ Detectar colisiones después del movimiento
	if position == last_position and velocity != Vector2.ZERO:
		# El jugador no se movió a pesar de tener velocidad -> colisión con pared
		print("🧱 COLISIÓN LOCAL CON PARED - Jugador:", id)
		# Efecto visual opcional
		modulate = Color(1, 0.5, 0.5) # Rojo claro
		await get_tree().create_timer(0.1).timeout
		modulate = Color.WHITE

	# Solo enviar posición al servidor si es el jugador local Y si se movió realmente
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
	attack_timer = attack_cooldown
	
	var attack_dir = (mouse_pos - global_position).normalized()
	var anim_name = _get_direction_animation(attack_dir.angle(), "attack")
	
	# Reproducir animación de ataque
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
# --- ANIMACIONES (FORMATO: accion_direccion)
# -------------------------------
func update_animation(dir: Vector2, attacking: bool = false, rolling: bool = false):
	if not current_sprite:
		return

	# Si está en cooldown de ataque, no cambiar animación
	if not can_attack_var:
		return

	var anim_name := "Idle" # Formato simple: Idle, run_N, attack_SW, etc.

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
	
	# Determinar la dirección basada en el ángulo
	var direction := ""
	
	if angle >= -PI / 8 and angle < PI / 8:
		direction = "E" # Este
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		direction = "SE" # Sureste
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		direction = "S" # Sur
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		direction = "SW" # Suroeste
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		direction = "W" # Oeste
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		direction = "NW" # Noroeste
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		direction = "N" # Norte
	elif angle >= -3 * PI / 8 and angle < -PI / 8:
		direction = "NE" # Noreste
	
	# Formato: accion_direccion (sin prefijo de clase)
	# Ejemplos: attack_N, run_SW, roll_E, Idle
	if direction == "":
		return action
	else:
		return action + "_" + direction

# -------------------------------
# --- SISTEMA DE VIDA
# -------------------------------
func update_hp(new_hp: int):
	hp = clamp(new_hp, 0, max_hp)
	if hp_bar:
		hp_bar.value = hp
	
	print("❤️  ACTUALIZANDO HP - Jugador:", id, " HP:", hp, "/", max_hp)
	
	if hp <= 0:
		play_death_animation()

func take_damage(amount: int):
	print("💥 JUGADOR RECIBIÓ DAÑO - ID:", id, " Cantidad:", amount, " HP Antes:", hp)
	update_hp(hp - amount)

func play_death_animation():
	if not current_sprite:
		if id == Network.player_id:
			get_tree().quit()
		return

	print("💀 JUGADOR MUERTO - ID:", id)
	if current_sprite.sprite_frames and current_sprite.sprite_frames.has_animation("Die"):
		current_sprite.play("Die")
	else:
		current_sprite.play("Idle") # Fallback
	
	if id == Network.player_id:
		Network.send_player_state("Die")
		await current_sprite.animation_finished
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
# --- COLISIONES CON PROYECTILES (MANEJADAS LOCALMENTE)
# -------------------------------
func _on_hitbox_area_entered(area):
	if area is Projectile:
		var projectile = area as Projectile
		print("🎯 PROYECTIL GOLPEÓ JUGADOR - Proyectil:", projectile.projectile_id, " Jugador:", id)
		
		# Verificar que no sea auto-daño
		if projectile.projectile_owner_id == id:
			print("🚫 AUTO-DAÑO IGNORADO")
			return
		
		# Notificar al servidor del golpe
		Network.projectile_hit_player(projectile.projectile_id, id, projectile.projectile_damage)
		
		# Aplicar daño localmente
		take_damage(projectile.projectile_damage)
		
		# Efecto visual local
		_create_hit_effect()

func _create_hit_effect():
	# Efecto visual de golpe
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
