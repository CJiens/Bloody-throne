extends CharacterBody2D
class_name Enemy

# -------------------------------
# --- PROPIEDADES DEL ENEMIGO
# -------------------------------
var enemy_id: int
var enemy_type: String = "grunt" # grunt, archer, mage, boss
var hp: int = 50
var max_hp: int = 50
var team: int = 1 # 1 o 2 para equipos, 0 para neutral (jefe)

# Estadísticas por tipo
var stats := {
	"grunt": {
		"hp": 50,
		"speed": 300,
		"attack_damage": 200,
		"attack_range": 40,
		"attack_cooldown": 1.5,
		"is_ranged": false,
		"aggro_range": 150,
		"chase_range": 200
	},
	"archer": {
		"hp": 40,
		"speed": 100,
		"attack_damage": 8,
		"attack_range": 120,
		"attack_cooldown": 2.0,
		"is_ranged": true,
		"aggro_range": 180,
		"chase_range": 250
	},
	"mage": {
		"hp": 30,
		"speed": 70,
		"attack_damage": 12,
		"attack_range": 100,
		"attack_cooldown": 3.0,
		"is_ranged": true,
		"aggro_range": 160,
		"chase_range": 220
	},
	"boss": {
		"hp": 500,
		"speed": 50,
		"attack_damage": 25,
		"attack_range": 80,
		"attack_cooldown": 2.0,
		"is_ranged": false,
		"aggro_range": 200,
		"chase_range": 300,
		"phases": 2,
		"current_phase": 1
	}
}

# IA y Comportamiento
var target_position: Vector2 = Vector2.ZERO
var current_target: Node2D = null
var aggro_target: Node2D = null
var state: String = "idle" # idle, moving, chasing, attacking, dead
var move_speed: float = 80.0

# Ataque
var attack_timer: float = 0.0
var can_attack: bool = true
var attack_range: float = 40.0
var attack_damage: int = 10
var attack_cooldown: float = 1.5
var is_ranged: bool = false

# Nodos
@onready var hp_bar: ProgressBar = $ProgressBar
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_area: Area2D = $HitboxArea
@onready var attack_area: Area2D = $AttackArea
@onready var detection_area: Area2D = $DetectionArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Proyectiles para enemigos ranged
@export var projectile_scene: PackedScene

# -------------------------------
# --- INICIALIZACIÓN
# -------------------------------
func _ready():
	# Configurar colisiones
	setup_collisions()
	
	# Agregar a grupo de enemigos
	add_to_group("enemies")
	
	# Configurar estado inicial
	state = "moving"
	
	print("👹 ENEMIGO CREADO - ID:", enemy_id, " Tipo:", enemy_type, " HP:", hp)

func setup_collisions():
	# Configurar layers y masks
	set_collision_layer_value(2, true) # Layer de enemigos
	set_collision_mask_value(1, false) # NO jugadores
	set_collision_mask_value(2, false) # NO otros enemigos
	set_collision_mask_value(3, true) # SÍ proyectiles
	set_collision_mask_value(4, true) # SÍ paredes
	set_collision_mask_value(5, false) # NO environment
	
	# Configurar áreas de detección
	if detection_area:
		detection_area.set_collision_layer_value(1, true) # Detectar jugadores
		detection_area.set_collision_mask_value(1, true)
	
	if attack_area:
		attack_area.set_collision_layer_value(1, true) # Atacar jugadores
		attack_area.set_collision_mask_value(1, true)
	
	if hitbox_area:
		hitbox_area.set_collision_layer_value(7, true) # Layer de hitbox de enemigos
		hitbox_area.set_collision_mask_value(3, true) # Recibir proyectiles

# -------------------------------
# --- CONFIGURACIÓN
# -------------------------------
func set_enemy_id(id: int):
	enemy_id = id
	name = str(id)

func set_enemy_type(type: String):
	enemy_type = type
	var config = stats.get(type, stats["grunt"])
	
	# Aplicar configuración
	hp = config.hp
	max_hp = config.hp
	move_speed = config.speed
	attack_damage = config.attack_damage
	attack_range = config.attack_range
	attack_cooldown = config.attack_cooldown
	is_ranged = config.is_ranged
	
	# Configurar barra de vida
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	# Configurar animaciones
	setup_animations()

func setup_animations():
	if not sprite:
		return
	
	# Configurar animaciones según el tipo
	match enemy_type:
		"grunt":
			sprite.sprite_frames = load("res://assets/animations/enemies/grunt.tres")
		"archer":
			sprite.sprite_frames = load("res://assets/animations/enemies/archer.tres")
		"mage":
			sprite.sprite_frames = load("res://assets/animations/enemies/mage.tres")
		"boss":
			sprite.sprite_frames = load("res://assets/animations/enemies/boss.tres")
	
	sprite.animation = "idle"
	sprite.play()

# -------------------------------
# --- PROCESO PRINCIPAL
# -------------------------------
func _process(delta):
	if state == "dead":
		return
	
	# Actualizar cooldown de ataque
	_handle_attack_cooldown(delta)
	
	# Actualizar IA
	_update_ai(delta)

func _physics_process(delta):
	if state == "dead":
		return
	
	# Movimiento basado en el estado
	match state:
		"moving", "chasing":
			_move_towards_target(delta)
		"attacking":
			_face_target()
	
	# Aplicar movimiento
	move_and_slide()

# -------------------------------
# --- IA Y COMPORTAMIENTO
# -------------------------------
func _update_ai(delta):
	# Buscar objetivos si no hay uno
	if not aggro_target:
		_find_target()
		return
	
	# Calcular distancia al objetivo
	var distance_to_target = global_position.distance_to(aggro_target.global_position)
	
	# Determinar estado basado en la distancia
	if distance_to_target <= attack_range:
		state = "attacking"
		_try_attack()
	elif distance_to_target <= stats[enemy_type].chase_range:
		state = "chasing"
	else:
		state = "moving"
		aggro_target = null

func _find_target():
	# Buscar jugadores en el área de detección
	var players_in_range = detection_area.get_overlapping_bodies()
	
	for body in players_in_range:
		if body.is_in_group("players") and _is_valid_target(body):
			aggro_target = body
			print("🎯 ENEMIGO %d ENCONTRÓ OBJETIVO: %s" % [enemy_id, body.name])
			return
	
	# Si no hay jugadores, moverse hacia la base enemiga
	_move_to_base()

func _is_valid_target(target: Node2D) -> bool:
	# Verificar que el objetivo esté vivo
	if target.has_method("get_player_id"):
		var player_hp = target.hp if "hp" in target else 0
		return player_hp > 0
	return false

func _move_to_base():
	# Moverse hacia la base del equipo opuesto
	var target_base_position = Vector2.ZERO
	
	if team == 1:
		target_base_position = Vector2(-450, 1900) # Base derecha
	else:
		target_base_position = Vector2(450, -1900) # Base izquierda
	
	target_position = target_base_position
	state = "moving"

func _move_towards_target(delta):
	if not aggro_target and state == "chasing":
		state = "moving"
		return
	
	var target_pos = aggro_target.global_position if aggro_target else target_position
	var direction = (target_pos - global_position).normalized()
	
	velocity = direction * move_speed
	
	# Actualizar animación
	_update_animation(direction)

func _face_target():
	if aggro_target:
		var direction = (aggro_target.global_position - global_position).normalized()
		_update_animation(direction)
	
	velocity = Vector2.ZERO

func _try_attack():
	if not can_attack or not aggro_target:
		return
	
	if is_ranged:
		_ranged_attack()
	else:
		_melee_attack()
	
	can_attack = false
	attack_timer = attack_cooldown
	
	print("💥 ENEMIGO %d ATACA - Tipo: %s, Daño: %d" % [enemy_id, enemy_type, attack_damage])

func _melee_attack():
	# Verificar que el objetivo esté en rango
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("players"):
			# Aplicar daño al jugador
			if body.has_method("take_damage"):
				body.take_damage(attack_damage)
			
			# Reproducir animación de ataque
			if sprite:
				sprite.animation = "attack"
				sprite.play()
			
			break

func _ranged_attack():
	if not projectile_scene:
		print("❌ ENEMIGO RANGED SIN PROYECTIL ASIGNADO")
		return
	
	# Crear proyectil
	var projectile = projectile_scene.instantiate()
	projectile.position = global_position
	
	var direction = (aggro_target.global_position - global_position).normalized()
	
	# Configurar proyectil
	if projectile.has_method("initialize"):
		projectile.initialize(-enemy_id, direction, attack_damage, -enemy_id, false)
	else:
		projectile.set("projectile_direction", direction)
		projectile.set("projectile_damage", attack_damage)
		projectile.set("projectile_owner_id", -enemy_id)
	
	get_parent().add_child(projectile)
	
	# Reproducir animación de ataque
	if sprite:
		sprite.animation = "attack"
		sprite.play()

# -------------------------------
# --- SISTEMA DE VIDA
# -------------------------------
func update_hp(new_hp: int):
	hp = clamp(new_hp, 0, max_hp)
	
	if hp_bar:
		hp_bar.value = hp
	
	print("❤️ ENEMIGO HP ACTUALIZADO - ID:", enemy_id, " HP:", hp, "/", max_hp)
	
	if hp <= 0:
		die()

func take_damage(amount: int):
	print("💥 ENEMIGO RECIBIÓ DAÑO - ID:", enemy_id, " Cantidad:", amount, " HP Antes:", hp)
	
	hp -= amount
	hp = max(0, hp)
	
	# Efecto visual de daño
	_create_hit_effect()
	
	# Actualizar barra de vida
	if hp_bar:
		hp_bar.value = hp
	
	if hp <= 0:
		die()
	else:
		# Notificar al servidor
		if Network.connected:
			Network.attack("enemy", enemy_id, amount)

func _create_hit_effect():
	# Efecto visual de golpe
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func die():
	if state == "dead":
		return
	
	print("💀 ENEMIGO MUERTO - ID:", enemy_id, " Tipo:", enemy_type)
	
	state = "dead"
	velocity = Vector2.ZERO
	
	# Reproducir animación de muerte
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("die"):
		sprite.animation = "die"
		sprite.play()
		await sprite.animation_finished
	else:
		# Si no tiene animación de muerte, desaparecer inmediatamente
		queue_free()
		return
	
	# Deshabilitar colisiones
	collision_shape.disabled = true
	hitbox_area.monitoring = false
	detection_area.monitoring = false
	attack_area.monitoring = false
	
	# Fade out y eliminar
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(queue_free)

# -------------------------------
# --- ANIMACIONES
# -------------------------------
func _update_animation(direction: Vector2):
	if not sprite or state == "attacking":
		return
	
	var anim_name = "idle"
	
	if velocity.length() > 0:
		anim_name = "walk"
		
		# Determinar dirección para el sprite
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				sprite.flip_h = false
			else:
				sprite.flip_h = true
		else:
			if direction.y > 0:
				# Hacia abajo
				pass
			else:
				# Hacia arriba
				pass
	
	if sprite.animation != anim_name:
		sprite.animation = anim_name
		sprite.play()

# -------------------------------
# --- COOLDOWNS
# -------------------------------
func _handle_attack_cooldown(delta):
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

# -------------------------------
# --- SEÑALES DE ÁREAS
# -------------------------------
func _on_detection_area_body_entered(body):
	if body.is_in_group("players") and _is_valid_target(body):
		if not aggro_target:
			aggro_target = body
			print("🎯 ENEMIGO %d DETECTÓ JUGADOR: %s" % [enemy_id, body.name])

func _on_detection_area_body_exited(body):
	if body == aggro_target:
		aggro_target = null
		print("🎯 ENEMIGO %d PERDIÓ OBJETIVO" % enemy_id)

func _on_attack_area_body_entered(body):
	if body.is_in_group("players") and _is_valid_target(body):
		if not aggro_target:
			aggro_target = body

func _on_attack_area_body_exited(body):
	if body == aggro_target:
		# Mantener el aggro por un tiempo incluso si sale del área de ataque
		pass

func _on_hitbox_area_area_entered(area):
	if area is Projectile:
		var projectile = area as Projectile
		
		# Verificar que no sea auto-daño (proyectil de otro enemigo)
		if projectile.projectile_owner_id < 0: # IDs negativos para enemigos
			return
		
		print("🎯 PROYECTIL GOLPEÓ ENEMIGO - Proyectil:", projectile.projectile_id, " Enemigo:", enemy_id)
		
		# Aplicar daño
		take_damage(projectile.projectile_damage)
		
		# Destruir proyectil
		if projectile.has_method("on_hit_success"):
			projectile.on_hit_success()
		else:
			projectile.queue_free()

# -------------------------------
# --- SISTEMA DE FASES (PARA JEFE)
# -------------------------------
func _check_phase_transition():
	if enemy_type != "boss":
		return
	
	var boss_config = stats["boss"]
	var phase_threshold = boss_config.hp / boss_config.phases
	
	if hp <= phase_threshold and boss_config.current_phase == 1:
		_enter_phase_two()

func _enter_phase_two():
	print("👹 JEFE ENTRA EN FASE 2 - HP:", hp)
	
	# Mejorar estadísticas
	stats["boss"].current_phase = 2
	move_speed *= 1.2
	attack_damage *= 1.5
	attack_cooldown *= 0.7
	
	# Cambiar animación/color para indicar fase 2
	modulate = Color(1, 0.5, 0.5) # Rojo más intenso
	
	# Efecto visual
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 1.0)

# -------------------------------
# --- UTILIDADES
# -------------------------------
func get_enemy_id() -> int:
	return enemy_id

func get_enemy_type() -> String:
	return enemy_type

func is_alive() -> bool:
	return hp > 0 and state != "dead"

# Función para debugging
func _debug_info():
	if Engine.get_frames_drawn() % 60 == 0: # Cada segundo aproximadamente
		print("👹 DEBUG - Enemigo %d: Estado=%s, HP=%d/%d, Target=%s" % [
			enemy_id,
			state,
			hp,
			max_hp,
			aggro_target.name if aggro_target else "Ninguno"
		])
