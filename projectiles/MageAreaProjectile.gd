extends Area2D

class_name MageAreaProjectile

var damage: int = 10
var owner_id: int = -1
var owner_team: int = 1
var lifetime: float = 10.0
var elapsed_time: float = 0.0
var damage_interval: float = 0.5  # Daño cada 0.5 segundos
var last_damage_time: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	print("🔥 PROYECTIL ÁREA MAGA CREADO - Posición:", position, " Duración:", lifetime, "s")
	
	# Configurar para que esté DEBAJO de los personajes
	z_index = -1
	
	# Configurar colisiones SOLO para objetivos válidos
	set_collision_layer_value(3, true)   # Layer 3: proyectiles
	set_collision_mask_value(6, true)    # Mask 6: hitbox de jugadores
	set_collision_mask_value(7, true)    # Mask 7: hitbox de enemigos
	set_collision_mask_value(8, true)    # Mask 8: bases
	
	# Conectar señales
	area_entered.connect(_on_area_entered)

	timer.timeout.connect(_on_timer_timeout)
	
	# Iniciar animación
	if animated_sprite:
		animated_sprite.play("start")
		# Esperar a que termine la animación de inicio
		await animated_sprite.animation_finished
		animated_sprite.play("burn_loop")
		
		# Iniciar timer de duración
		timer.start(lifetime)
	else:
		print("❌ ERROR: AnimatedSprite2D no encontrado")

func _process(delta):
	elapsed_time += delta
	
	# Aplicar daño periódicamente a todos los objetivos en el área
	if elapsed_time - last_damage_time >= damage_interval:
		last_damage_time = elapsed_time
		_apply_damage_to_targets_in_area()

func initialize(dmg: int, owner: int, team: int):
	damage = dmg
	owner_id = owner
	owner_team = team
	print("💥 PROYECTIL ÁREA MAGA INICIALIZADO - Daño:", damage, " Equipo:", team)

func _on_timer_timeout():
	print("🔥 PROYECTIL ÁREA MAGA DESAPARECIENDO...")
	_start_disappear()

func _start_disappear():
	if animated_sprite:
		# Reproducir animación de fin (inversa)
		if animated_sprite.sprite_frames.has_animation("end"):
			animated_sprite.play("end")
			await animated_sprite.animation_finished
		else:
			# Fallback: fade out
			var tween = create_tween()
			tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0), 0.5)
			await tween.finished
	
	queue_free()

func _apply_damage_to_targets_in_area():
	# Obtener todas las áreas que están dentro de la zona de daño
	var areas = get_overlapping_areas()
	var hit_count = 0
	
	for area in areas:
		if _should_damage_target(area):
			hit_count += 1
			_send_damage_to_target(area)
	
	if hit_count > 0:
		print("🔥 PROYECTIL ÁREA MAGA - Aplicando daño a", hit_count, " objetivos")

func _should_damage_target(area) -> bool:
	# No dañar si el área no tiene un padre válido
	if not area.get_parent():
		return false
	
	# Verificar hitbox de jugadores (layer 6)
	if area.get_collision_layer_value(6):
		var player = area.get_parent()
		if player and player.has_method("get_player_id"):
			var player_id = player.get_player_id()
			var player_team = player.team if "team" in player else 0
			# NO dañar al propio jugador ni aliados
			return player_id != owner_id and player_team != owner_team
	
	# Verificar hitbox de enemigos (layer 7)
	elif area.get_collision_layer_value(7):
		var enemy = area.get_parent()
		if enemy and enemy.has_method("get_enemy_id"):
			var enemy_team = enemy.team if "team" in enemy else 0
			# NO dañar enemigos aliados
			return enemy_team != owner_team
	
	# Verificar bases (layer 8)
	elif area.get_collision_layer_value(8):
		var base = area.get_parent()
		if base and base.has_method("get_team"):
			var base_team = base.get_team()
			# NO dañar bases aliadas
			return base_team != owner_team
	
	return false

func _send_damage_to_target(area):
	# Enviar mensaje al servidor para aplicar el daño
	if area.get_collision_layer_value(6):  # Jugador
		var player = area.get_parent()
		if player and player.has_method("get_player_id"):
			Network.socket.send_text(JSON.stringify({
				"type": "mage_area_damage_tick",
				"target_type": "player",
				"target_id": player.get_player_id(),
				"damage": damage,
				"owner_id": owner_id,
				"owner_team": owner_team
			}))
	
	elif area.get_collision_layer_value(7):  # Enemigo
		var enemy = area.get_parent()
		if enemy and enemy.has_method("get_enemy_id"):
			Network.socket.send_text(JSON.stringify({
				"type": "mage_area_damage_tick",
				"target_type": "enemy",
				"target_id": enemy.get_enemy_id(),
				"damage": damage,
				"owner_id": owner_id,
				"owner_team": owner_team
			}))
	
	elif area.get_collision_layer_value(8):  # Base
		var base = area.get_parent()
		if base and base.has_method("get_team"):
			Network.socket.send_text(JSON.stringify({
				"type": "mage_area_damage_tick",
				"target_type": "base",
				"target_id": base.get_team(),
				"damage": damage,
				"owner_id": owner_id,
				"owner_team": owner_team
			}))

func _on_area_entered(area):
	# Aplicar daño inmediatamente cuando un objetivo entra al área
	if _should_damage_target(area):
		_send_damage_to_target(area)
