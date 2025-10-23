extends CharacterBody2D
class_name Ghost

# Variables del fantasma
var ghost_id: int = -1
var is_local: bool = false
var speed: float = 250.0
var possessed_object: Node2D = null
var can_possess: bool = true

# Nodos
@onready var sprite: Sprite2D = $Sprite2D
@onready var possession_area: Area2D = $PossessionArea
@onready var possession_collision: CollisionShape2D = $PossessionArea/CollisionShape2D
@onready var possess_indicator: Sprite2D = $PossessIndicator
@onready var camera: Camera2D = $Camera2D

# Variables de visibilidad
var nearby_objects_count: int = 0

func _ready():
	print("👻 FANTASMA INICIALIZADO - ID:", ghost_id)
	
	# Configurar capas de colisión del fantasma
	set_collision_layer_value(9, true)    # Layer 9: Fantasmas
	set_collision_mask_value(4, false)     # Colisiona con paredes (Layer 4)
	set_collision_mask_value(1, false)    # No colisiona con jugadores
	set_collision_mask_value(2, false)    # No colisiona con enemigos
	set_collision_mask_value(3, false)    # No colisiona con proyectiles
	set_collision_mask_value(7, false)    # No colisiona con objetos poseíbles
	
	# Configurar área de posesión
	possession_area.set_collision_layer_value(9, false)   # No detecta fantasmas
	possession_area.set_collision_mask_value(7, true)     # Detecta objetos poseíbles (Layer 7)
	
	# Configurar cámara (inicialmente desactivada)
	if camera:
		camera.enabled = false
	
	# Ocultar indicador inicialmente
	if possess_indicator:
		possess_indicator.visible = false
	
	# Conectar señales del área de posesión
	if not possession_area.area_entered.is_connected(_on_possession_area_entered):
		possession_area.area_entered.connect(_on_possession_area_entered)
	if not possession_area.area_exited.is_connected(_on_possession_area_exited):
		possession_area.area_exited.connect(_on_possession_area_exited)

func _physics_process(delta):
	# Solo procesar movimiento si es el fantasma local y no está poseyendo objeto
	if not is_local or possessed_object != null:
		return
	
	_handle_movement()

func _process(delta):
	# Actualizar indicador visual de objetos cercanos (solo para fantasma local)
	if is_local and possessed_object == null:
		_update_possess_indicator()

func _handle_movement():
	var direction = Vector2.ZERO
	
	# Leer inputs de movimiento
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	
	# Aplicar movimiento
	velocity = direction.normalized() * speed
	move_and_slide()
	
	# Enviar posición al servidor si se movió
	if Network.connected and is_local and velocity != Vector2.ZERO:
		Network.move_ghost(position.x, position.y)  # Reutilizamos move_player

func _input(event):
	if not is_local:
		return
	
	# Tecla E para poseer objeto
	if event.is_action_pressed("possess") and can_possess and possessed_object == null:
		if get_possessable_objects().size() > 0:
			_try_possess_object()
		else:
			_show_no_objects_feedback()
	
	# Tecla Espacio para lanzar objeto
	if event.is_action_pressed("throw") and possessed_object != null:
		_throw_object()

func _try_possess_object():
	print("🎯 INTENTANDO POSESION - Fantasma:", ghost_id)
	var objects = get_possessable_objects()
	
	if objects.size() > 0:
		var closest_object = objects[0]
		possess(closest_object)
	else:
		print("❌ No hay objetos poseíbles cerca")

func get_possessable_objects() -> Array:
	var objects = []
	var areas = possession_area.get_overlapping_areas()
	for area in areas:
		if area.is_in_group("possessable") and area.possessed_by == -1:
			objects.append(area)
	return objects

func possess(object: Node2D):
	if not object or not is_instance_valid(object):
		print("❌ Error: Objeto no válido para posesión")
		return
		
	print("🎯 FANTASMA POSEYENDO OBJETO - Ghost:", ghost_id, " Object:", object.name)
	
	# ✅ CORREGIDO: Fantasma se mueve a la posición del objeto
	global_position = object.global_position
	
	possessed_object = object
	object.ppossessed_by(ghost_id)
	
	# Ocultar fantasma mientras posee objeto
	visible = false
	set_physics_process(false)
	
	# Notificar al servidor
	if Network.connected and ws_ready:
		Network.ghost_possession_started(ghost_id, object.get_instance_id())

func unpossess():
	if possessed_object:
		print("🎯 FANTASMA LIBERANDO OBJETO - Ghost:", ghost_id)
		
		# Mostrar fantasma y reactivar movimiento
		visible = true
		set_physics_process(true)
		
		# Liberar objeto
		possessed_object.unpossessed()
		if Network.connected:
			Network.ghost_possession_ended(ghost_id, possessed_object.get_instance_id())
		possessed_object = null

func _throw_object():
	if possessed_object:
		var direction = _get_throw_direction()
		if direction != Vector2.ZERO:
			print("🚀 LANZANDO OBJETO - Ghost:", ghost_id, " Direction:", direction)
			possessed_object.throw(direction)
			unpossess()

func _get_throw_direction() -> Vector2:
	var direction = Vector2.ZERO
	
	# Determinar dirección basada en teclas de movimiento
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	
	# Si no hay dirección de movimiento, lanzar hacia la derecha por defecto
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	
	return direction.normalized()

func _update_possess_indicator():
	if not possess_indicator:
		return
	
	var objects = get_possessable_objects()
	var has_nearby_objects = objects.size() > 0
	
	# Mostrar/ocultar indicador
	possess_indicator.visible = has_nearby_objects
	
	# Cambiar color del indicador según la cantidad de objetos
	if has_nearby_objects:
		var intensity = min(objects.size() / 3.0, 1.0)
		possess_indicator.modulate = Color(1, 1, 0, intensity)  # Amarillo más intenso con más objetos

func _show_no_objects_feedback():
	# Feedback visual cuando no hay objetos para poseer
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

func set_ghost_id(id: int):
	ghost_id = id
	print("👻 ID ASIGNADO AL FANTASMA:", ghost_id)

func set_is_local(local: bool):
	is_local = local
	if is_local:
		print("🎮 FANTASMA LOCAL ACTIVADO - ID:", ghost_id)
		# El fantasma local siempre se ve a sí mismo
		sprite.visible = true
		# Activar la cámara
		if camera:
			camera.enabled = true
			camera.make_current()
			print("📷 CÁMARA DE FANTASMA ACTIVADA - ID:", ghost_id)
	else:
		_update_visibility()
		if camera:
			camera.enabled = false

func _update_visibility():
	# Los fantasmas son visibles solo para otros fantasmas
	# Si es el fantasma local, siempre se ve a sí mismo
	if is_local:
		sprite.visible = true
		return
	
	# Para fantasmas remotos, solo son visibles si el jugador local es también un fantasma
	var main_nodes = get_tree().get_nodes_in_group("main")
	if main_nodes.size() > 0:
		var main_node = main_nodes[0]
		if main_node and main_node.has_method("is_local_player_ghost"):
			sprite.visible = main_node.is_local_player_ghost()
		else:
			sprite.visible = false
	else:
		sprite.visible = false

func _on_possession_area_entered(area: Area2D):
	if area.is_in_group("possessable"):
		print("📦 OBJETO CERCANO - Fantasma:", ghost_id, " puede poseer con E")
		nearby_objects_count += 1

func _on_possession_area_exited(area: Area2D):
	if area.is_in_group("possessable"):
		print("📦 OBJETO ALEJADO - Fantasma:", ghost_id)
		nearby_objects_count = max(0, nearby_objects_count - 1)
