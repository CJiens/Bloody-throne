#Enemy.gd
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
	"Zorro": {
		"hp": 70,
		"speed": 200,
		"attack_damage": 15,
		"attack_range": 60,
		"attack_cooldown": 1.2,
		"is_ranged": false,
		"aggro_range": 200,
		"chase_range": 300
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
@onready var vida_label: Label = $ProgressBar/vidaLabel
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

	#Barra de vida
	hp_bar.max_value = max_hp
	vida_label.text = str(hp) + "/" + str(max_hp)
	# ✅ APLICAR COLOR INMEDIATAMENTE SI EL EQUIPO YA ESTÁ ASIGNADO
	if team != -1:
		_apply_team_color_immediately()
	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)
	print("👹 ENEMIGO CREADO - ID:", enemy_id, " Tipo:", enemy_type, " HP:", hp, " Equipo:", team)

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
	var config = stats["Zorro"] 
	
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

	# Label de vida
	if vida_label:
		vida_label.text = str(hp) + "/" + str(max_hp)
	
	# Configurar animaciones
	setup_animations()
func setup_animations():
	if not sprite:
		return
	
	sprite.sprite_frames = load("res://assets/animations/enemies/Zorro.tres")
	sprite.animation = "Idle"
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
	
	# Verificar que el objetivo siga siendo válido
	if not _is_valid_target(aggro_target):
		aggro_target = null
		state = "moving"
		return
	
	# Calcular distancia al objetivo
	var distance_to_target = global_position.distance_to(aggro_target.global_position)
	
	# ✅ COMPORTAMIENTO MEJORADO PARA NEUTRALES
	if team == 0:  # Enemigos neutrales
		if distance_to_target <= attack_range:
			state = "attacking"
			_try_attack()
		elif distance_to_target <= 800:  # Radio de persecución grande
			state = "chasing"
			# ✅ MOVIMIENTO MÁS DIRECTO HACIA EL JUGADOR
			var direction = (aggro_target.global_position - global_position).normalized()
			velocity = direction * move_speed
		else:
			# Si el jugador se aleja demasiado, buscar nuevo objetivo
			aggro_target = null
			state = "moving"
	else:
		# Comportamiento original para enemigos con equipo
		if distance_to_target <= attack_range:
			state = "attacking"
			_try_attack()
		elif distance_to_target <= stats[enemy_type].chase_range:
			state = "chasing"
		else:
			state = "moving"
			aggro_target = null

func _find_target():
	# ✅ COMPORTAMIENTO DIFERENTE SEGÚN EQUIPO
	if team == 0:
		# ENEMIGOS NEUTRALES: Buscar jugadores cercanos
		_find_player_target()
	else:
		# ENEMIGOS CON EQUIPO: Buscar jugadores enemigos o ir a base
		_find_team_target()
func _find_player_target():
	# Buscar cualquier jugador vivo, sin importar equipo
	var players = get_tree().get_nodes_in_group("players")
	var closest_player = null
	var min_distance = INF
	
	for player in players:
		if _is_valid_player_target(player):
			var distance = global_position.distance_to(player.global_position)
			if distance < min_distance and distance <=  800:
				min_distance = distance
				closest_player = player
	
	if closest_player:
		aggro_target = closest_player
		# ✅ COMPORTAMIENTO MÁS AGRESIVO - Perseguir inmediatamente
		state = "chasing"
		print("🎯 ENEMIGO NEUTRAL ENCONTRÓ JUGADOR - ID:", enemy_id, " Jugador:", closest_player.name, " Distancia:", min_distance)
	else:
		# ✅ MOVIMIENTO MÁS DECIDIDO CUANDO NO HAY JUGADORES
		_move_aggressive_random()
func _is_valid_player_target(target: Node2D) -> bool:
	# Para enemigos neutrales: cualquier jugador vivo
	if target.is_in_group("players"):
		var player_hp = target.hp if "hp" in target else 0
		return player_hp > 0
	return false

func _is_valid_team_target(target: Node2D) -> bool:
	# Para enemigos con equipo: solo jugadores del equipo opuesto
	if target.is_in_group("players"):
		var player_hp = target.hp if "hp" in target else 0
		var player_team = target.team if "team" in target else 0
		return player_hp > 0 and player_team != team
	return false
func _move_aggressive_random():
	# Movimiento aleatorio más decidido para neutrales
	var random_angle = randf() * 2 * PI
	var random_distance = 300 + randf() * 200  # Distancias más largas
	target_position = global_position + Vector2(cos(random_angle), sin(random_angle)) * random_distance
	state = "moving"
	
	# ✅ TIMER PARA CAMBIO DE DIRECCIÓN MÁS LARGO
	var timer = get_tree().create_timer(3.0 + randf() * 2.0)  # 3-5 segundos
	await timer.timeout
	if state == "moving" and not aggro_target:
		_move_aggressive_random()
func _find_team_target():
	# Buscar jugadores enemigos en el área de detección
	var players_in_range = detection_area.get_overlapping_bodies()
	
	for body in players_in_range:
		if body.is_in_group("players") and _is_valid_team_target(body):
			aggro_target = body
			return
	
	# Si no hay jugadores enemigos, moverse hacia la base enemiga
	_move_to_base()

func _is_valid_target(target: Node2D) -> bool:
	# Verificar que el objetivo esté vivo y sea de equipo contrario
	if target.is_in_group("players"):
		var player_hp = target.hp if "hp" in target else 0
		var player_team = target.team if "team" in target else 0
		return player_hp > 0 and player_team != team
	return false

func _move_to_base():
	# Moverse hacia la base del equipo opuesto
	var target_base_position = Vector2.ZERO
	if team == 1:
		target_base_position = Vector2(1400, 400)  # Base del equipo 2
	else:
		target_base_position = Vector2(-1600, -800) # Base del equipo 1
	
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
	
	# ✅ DAÑO ESPECIAL PARA NEUTRALES (5% de vida máxima del jugador)
	if team == 0 and aggro_target and aggro_target.has_method("get_max_hp"):
		var player_max_hp = aggro_target.get_max_hp()
		var neutral_damage = int(player_max_hp * 0.05)
		print("💥 ENEMIGO NEUTRAL ATACA - Daño:", neutral_damage, " (5% de ", player_max_hp, ")")
	
	print("💥 ENEMIGO %d ATACA - Tipo: %s, Daño: %d" % [enemy_id, enemy_type, attack_damage])
func _melee_attack():
	# Verificar que el objetivo esté en rango
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("players"):
			# Calcular dirección hacia el objetivo
			var direction_to_target = (body.global_position - global_position).normalized()
			var attack_dir = _get_direction_string(direction_to_target)
			var attack_anim = "Attack_" + attack_dir
			
			# Reproducir animación de ataque en la dirección correcta
			if sprite:
				sprite.animation = attack_anim
				sprite.play()
			
			# Aplicar daño al jugador
			if body.has_method("take_damage"):
				body.take_damage(attack_damage)
			
			print("💥 ZORRO ATACA - Dirección:", attack_dir, " Daño:", attack_damage)
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
	if vida_label:
		vida_label.text = str(hp) + "/" + str(max_hp)
	
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
	
	var anim_name = "Idle"
	
	if velocity.length() > 0:
		var dir_string = _get_direction_string(direction)
		anim_name = "Run_" + dir_string
	
	if sprite.animation != anim_name:
		sprite.animation = anim_name
		sprite.play()
func _get_direction_string(direction: Vector2) -> String:
	var angle = direction.angle()
	var angle_deg = rad_to_deg(angle)
	
	# Ajustar ángulo para que esté entre 0 y 360
	if angle_deg < 0:
		angle_deg += 360
	
	# Dividir en 8 direcciones de 45 grados cada una
	if angle_deg >= 22.5 and angle_deg < 67.5:
		return "SE"
	elif angle_deg >= 67.5 and angle_deg < 112.5:
		return "S"
	elif angle_deg >= 112.5 and angle_deg < 157.5:
		return "SW"
	elif angle_deg >= 157.5 and angle_deg < 202.5:
		return "W"
	elif angle_deg >= 202.5 and angle_deg < 247.5:
		return "NW"
	elif angle_deg >= 247.5 and angle_deg < 292.5:
		return "N"
	elif angle_deg >= 292.5 and angle_deg < 337.5:
		return "NE"
	else:
		return "E"
func _on_animation_finished():
	# Si la animación que terminó es de ataque, volver a idle
	if sprite.animation.begins_with("Attack_"):
		sprite.animation = "Idle"
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
# -------------------------------
# --- CONFIGURACIÓN DE EQUIPO
# -------------------------------
func set_team(new_team: int):
	team = new_team
	print("🎯 EQUIPO ASIGNADO - Enemigo:", enemy_id, " Equipo:", team)
	
	# ✅ APLICAR COLOR INMEDIATAMENTE, SIN ESPERAR
	_apply_team_color_immediately()

# -------------------------------
# --- IDENTIFICADORES VISUALES POR EQUIPO
# -------------------------------
func _apply_team_color_immediately():

	match team:
		1:
			modulate = Color(0.6, 0.6, 1.0)  # Azul claro para equipo 1
		2:
			modulate = Color(1.0, 0.6, 0.6)  # Rojo claro para equipo 2
		0:
			modulate = Color(1.0, 1.0, 1.0)  # Blanco para neutrales
		_:
			modulate = Color(1.0, 1.0, 1.0)  # Blanco por defecto
	print("🎨 COLOR DE EQUIPO ASIGNADO - Enemigo:", enemy_id, " Equipo:", team, " Color:", modulate)
