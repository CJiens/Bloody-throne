extends RigidBody2D
class_name Barrel

# Variables del barril
var possessed_by: int = -1  # -1 = no poseído, ghost_id = poseído por
var is_possessed: bool = false
var throw_force: float = 800.0
var damage: int = 25
var original_position: Vector2

# Nodos
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $HitboxArea
@onready var hitbox_collision: CollisionShape2D = $HitboxArea/CollisionShape2D
@onready var trail_particles: GPUParticles2D = $TrailParticles

func _ready():
	add_to_group("possessable")
	original_position = position
	
	# Configurar como objeto estático inicialmente
	freeze = true
	gravity_scale = 1.0
	mass = 2.0  # Peso del barril
	
	# Configurar hitbox para dañar jugadores
	hitbox.set_collision_layer_value(8, true)   # Layer de objetos lanzados
	hitbox.set_collision_mask_value(1, true)    # Colisiona con jugadores
	hitbox.set_collision_mask_value(4, false)   # No colisiona con paredes
	hitbox.set_collision_mask_value(7, false)   # No colisiona con otros objetos
	
	# Configurar colisiones del barril
	set_collision_layer_value(7, true)   # Layer de objetos poseíbles
	set_collision_mask_value(4, true)    # Colisiona con paredes
	set_collision_mask_value(1, false)   # No colisiona con jugadores (el hitbox se encarga)
	
	# Conectar señal de hitbox
	if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	# Desactivar partículas inicialmente
	if trail_particles:
		trail_particles.emitting = false
	
	print("📦 BARRIL CREADO - ID:", get_instance_id())

func ppossessed_by(ghost_id: int):
	print("🎯 BARRIL POSEGIDO - Barril:", get_instance_id(), " Ghost:", ghost_id)
	possessed_by = ghost_id
	is_possessed = true
	
	# Congelar física mientras está poseído
	freeze = true
	collision.disabled = false
	
	# Efecto visual de posesión
	_start_possession_effect()

func _start_possession_effect():
	# Efecto visual simple - cambiar color temporalmente
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.5, 0.8, 1.0, 1.0), 0.2)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)

func unpossessed():
	print("🎯 BARRIL LIBERADO - Barril:", get_instance_id())
	possessed_by = -1
	is_possessed = false
	
	# Reactivar física
	freeze = false
	collision.disabled = false

func throw(direction: Vector2):
	print("🚀 BARRIL LANZADO - Barril:", get_instance_id(), " Direction:", direction)
	
	# Activar física para el lanzamiento
	freeze = false
	collision.disabled = false
	
	# Aplicar fuerza de lanzamiento con un poco de aleatoriedad
	var actual_force = throw_force * randf_range(0.9, 1.1)
	apply_impulse(direction * actual_force)
	
	# Aplicar rotación aleatoria
	apply_torque_impulse(randf_range(-10, 10))
	
	# Activar partículas de trayectoria
	if trail_particles:
		trail_particles.emitting = true
	
	# Notificar al servidor
	if Network.connected:
		Network.throw_object(get_instance_id(), direction)
	
	# Programar auto-destrucción después de 5 segundos
	_start_destruction_timer()

func _start_destruction_timer():
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		print("💥 BARRIL DESTRUIDO - ID:", get_instance_id())
		_create_destruction_effect()
		queue_free()

func _create_destruction_effect():
	# Efecto visual simple de destrucción
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.2)
	tween.tween_callback(queue_free)

func _on_hitbox_area_entered(area: Area2D):
	# Verificar si golpeó a un jugador
	var parent = area.get_parent()
	
	# ✅ CORREGIDO: Usar grupos en lugar de tipo Player
	if parent and parent.is_in_group("players") and not is_possessed:
		# Verificar que no sea auto-daño (el fantasma que lo lanzó)
		if parent.has_method("get_player_id") and parent.get_player_id() != possessed_by:
			print("💥 BARRIL GOLPEÓ JUGADOR - Barril:", get_instance_id(), " Player:", parent.get_player_id())
			
			# Efecto visual de impacto
			_create_impact_effect()
			
			# Aplicar daño al jugador
			if parent.has_method("take_damage"):
				parent.take_damage(damage)
			
			# Destruir barril inmediatamente
			queue_free()

func _create_impact_effect():
	# Efecto visual simple de impacto
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0, 1), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)

# Función para resetear el barril si es necesario
func reset():
	position = original_position
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	if trail_particles:
		trail_particles.emitting = false
