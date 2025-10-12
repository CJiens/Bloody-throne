extends Area2D

class_name Projectile

# Propiedades del proyectil
var projectile_id: int = -1
var projectile_direction: Vector2 = Vector2.ZERO
var projectile_speed: float = 400.0
var projectile_damage: int = 10
var projectile_owner_id: int = -1
var max_lifetime: float = 3.0
var lifetime: float = 0.0
var has_hit: bool = false
var is_remote: bool = false

# Nodos
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	# CONFIGURACIÓN MEJORADA DE COLISIONES
	if not is_remote:
		# Proyectiles locales: detectan colisiones para feedback inmediato
		body_entered.connect(_on_body_entered)
		
		# Configurar layers y masks para proyectiles locales
		set_collision_layer_value(3, true)   # projectiles layer
		set_collision_mask_value(1, false)   # NO detectar players (el servidor maneja)
		set_collision_mask_value(4, true)    # ✅ SÍ detectar walls
		set_collision_mask_value(2, false)   # NO detectar enemigos (el servidor maneja)
		set_collision_mask_value(3, false)   # NO detectar otros proyectiles
		set_collision_mask_value(5, false)   # NO detectar environment
		
		if collision_shape:
			collision_shape.disabled = false
			
		print("🔧 PROYECTIL LOCAL LISTO - Colisiones ACTIVADAS (solo paredes)")
	else:
		# Proyectiles remotos: desactivar TODAS las colisiones
		set_collision_layer_value(3, false)  # NO estar en layer de projectiles
		set_collision_mask_value(1, false)   # NO detectar players
		set_collision_mask_value(2, false)   # NO detectar enemigos
		set_collision_mask_value(3, false)   # NO detectar proyectiles
		set_collision_mask_value(4, false)   # NO detectar paredes
		set_collision_mask_value(5, false)   # NO detectar environment
		
		if collision_shape:
			collision_shape.disabled = true
			
		print("🔧 PROYECTIL REMOTO LISTO - Colisiones DESACTIVADAS")

func _process(delta):
	if has_hit:
		return
	
	lifetime += delta
	
	# Verificar tiempo máximo de vida
	if lifetime >= max_lifetime:
		print("⏰ PROYECTIL DESTRUIDO POR TIEMPO - ID:", projectile_id)
		if not is_remote:
			# Solo el propietario notifica al servidor
			Network.remove_projectile(projectile_id)
		queue_free()
		return
	
	# MOVER el proyectil - TODOS los proyectiles se mueven visualmente
	var old_pos = position
	position += projectile_direction * projectile_speed * delta
	
	# DEBUG: Mostrar movimiento ocasionalmente
	if Engine.get_frames_drawn() % 60 == 0:
		print("🔄 PROYECTIL MOVIÉNDOSE - ID:", projectile_id, " From:", old_pos, " To:", position, " Lifetime:", lifetime)
	
	# Solo el cliente propietario actualiza la posición en el servidor
	if not is_remote:
		Network.update_projectile_position(projectile_id, position.x, position.y)
	
	# Rotar el proyectil según la dirección
	rotation = projectile_direction.angle()

# SOLO para feedback visual local - el servidor maneja las colisiones reales
func _on_body_entered(body):
	if has_hit or is_remote:
		return
	
	print("🎯 COLISIÓN VISUAL LOCAL DETECTADA - Proyectil:", projectile_id)
	print("   - Body:", body.name, " Type:", body.get_class())
	
	# Verificar si es un jugador
	if body.has_method("get_player_id"):
		var target_id = body.get_player_id()
		print("🎯 ES JUGADOR - Target ID:", target_id, " Owner ID:", projectile_owner_id)
		
		# Solo para feedback visual, no aplicar daño real
		if target_id != projectile_owner_id:
			print("💥 FEEDBACK VISUAL DE DAÑO - Target:", target_id)
			
			# Efectos visuales
			_create_hit_effect()
			
			# Marcar como golpeado para destrucción visual
			has_hit = true
			
			# El servidor ya manejó el daño real, solo destruir visualmente
			queue_free()
		else:
			print("🚫 AUTO-DAÑO IGNORADO (VISUAL) - El proyectil continúa")
			# NO marcar has_hit = true y NO llamar queue_free()
	
	# Colisión con paredes u otros objetos (solo visual)
	elif body is StaticBody2D or body is TileMap:
		print("🧱 COLISIÓN CON PARED (VISUAL) - Proyectil:", projectile_id)
		_create_hit_effect()
		has_hit = true
		queue_free()

# Efecto visual opcional al golpear
func _create_hit_effect():
	print("✨ CREANDO EFECTO VISUAL DE IMPACTO - Proyectil:", projectile_id)
	
	# Ejemplo: Podrías instanciar una escena de partículas aquí
	# var hit_effect = preload("res://Effects/HitEffect.tscn").instantiate()
	# get_parent().add_child(hit_effect)
	# hit_effect.global_position = global_position

# Inicializar el proyectil
func initialize(id: int, dir: Vector2, dmg: int, owner: int, remote: bool = false):
	projectile_id = id
	projectile_direction = dir.normalized()
	projectile_damage = dmg
	projectile_owner_id = owner
	is_remote = remote
	
	print("🎯 PROYECTIL INICIALIZADO - ID:", id, " Dir:", dir, " Damage:", dmg, " Owner:", owner, " Remote:", remote)

# Función para destrucción remota (cuando el servidor dice que fue destruido)
func remote_destroy():
	print("🗑️ DESTRUCCIÓN REMOTA DE PROYECTIL - ID:", projectile_id)
	has_hit = true
	_create_hit_effect()
	queue_free()

# Función para cuando el proyectil golpea algo (llamada desde el servidor)
func on_hit_success():
	print("💥 PROYECTIL GOLPEÓ EXITOSAMENTE - ID:", projectile_id)
	has_hit = true
	_create_hit_effect()
	queue_free()