#projectile.gd
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
		area_entered.connect(_on_area_entered)
		body_entered.connect(_on_body_entered)
		
		# ✅ CONFIGURACIÓN CORREGIDA DE LAYERS Y MÁSCARAS
		set_collision_layer_value(3, true)   # Layer 3: proyectiles
		set_collision_mask_value(6, true)    # ✅ SÍ detectar hitbox de jugadores (layer 6)
		set_collision_mask_value(7, true)    # ✅ SÍ detectar hitbox de enemigos (layer 7) - NUEVO
		set_collision_mask_value(4, true)    # ✅ SÍ detectar walls
		set_collision_mask_value(1, false)   # NO detectar players (movimiento)
		set_collision_mask_value(2, false)   # NO detectar enemigos (movimiento)
		set_collision_mask_value(5, false)   # NO detectar environment
		
		if collision_shape:
			collision_shape.disabled = false
			
		print("🔧 PROYECTIL LOCAL LISTO - Colisiones ACTIVADAS")
		print("   - Layers: 3 (proyectiles)")
		print("   - Mask: 6 (player_hitbox), 7 (enemy_hitbox), 4 (walls)")
	else:
		# Proyectiles remotos: desactivar TODAS las colisiones
		set_collision_layer_value(3, false)  # NO estar en layer de projectiles
		set_collision_mask_value(1, false)   # NO detectar players
		set_collision_mask_value(2, false)   # NO detectar enemigos
		set_collision_mask_value(3, false)   # NO detectar proyectiles
		set_collision_mask_value(4, false)   # NO detectar paredes
		set_collision_mask_value(5, false)   # NO detectar environment
		set_collision_mask_value(6, false)   # NO detectar hitbox de jugadores
		set_collision_mask_value(7, false)   # NO detectar hitbox de enemigos
		
		if collision_shape:
			collision_shape.disabled = true
			
		print("🔧 PROYECTIL REMOTO LISTO - Colisiones DESACTIVADAS")
	
	print("   - ID:", projectile_id, " Owner:", projectile_owner_id)
	print("   - Posición:", position)
	print("   - Dirección:", projectile_direction)
	print("   - Velocidad:", projectile_speed)
	print("   - Daño:", projectile_damage)

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

# COLISIÓN CON ÁREAS (hitbox de jugadores Y enemigos) - CORREGIDO
func _on_area_entered(area):
	if has_hit or is_remote:
		return
	
	print("🎯 COLISIÓN CON HITBOX - Proyectil:", projectile_id)
	print("   - Area:", area.name, " Parent:", area.get_parent().name if area.get_parent() else "N/A")
	print("   - Area Layers:", area.collision_layer)
	
	# ✅ DETECTAR HITBOX DE JUGADORES (layer 6)
	if area.get_collision_layer_value(6):
		var player = area.get_parent()
		if player and player.has_method("get_player_id"):
			var player_id = player.get_player_id()
			# Verificar que no sea auto-daño
			if player_id != projectile_owner_id:
				print("💥 PROYECTIL GOLPEÓ JUGADOR - Proyectil:", projectile_id, " Jugador:", player_id)
				# Notificar al servidor del golpe
				Network.projectile_hit_player(projectile_id, player_id, projectile_damage)
				has_hit = true
				_create_hit_effect()
				queue_free()
			else:
				print("🚫 AUTO-DAÑO IGNORADO - Proyectil:", projectile_id, " Jugador:", player_id)
	
	# ✅ DETECTAR HITBOX DE ENEMIGOS (layer 7) - NUEVO
	elif area.get_collision_layer_value(7):
		var enemy = area.get_parent()
		if enemy and enemy.has_method("get_enemy_id"):
			var enemy_id = enemy.get_enemy_id()
			print("💥 PROYECTIL GOLPEÓ ENEMIGO - Proyectil:", projectile_id, " Enemigo:", enemy_id)
			# Notificar al servidor del golpe
			Network.attack("enemy", enemy_id, projectile_damage)
			has_hit = true
			_create_hit_effect()
			queue_free()

# COLISIÓN CON CUERPOS (paredes)
func _on_body_entered(body):
	if has_hit or is_remote:
		return
	
	print("🧱 COLISIÓN CON PARED - Proyectil:", projectile_id)
	print("   - Body:", body.name, " Type:", body.get_class())
	print("   - Body Layers:", body.collision_layer)
	
	# Colisión con paredes u otros objetos
	if body is StaticBody2D or body is TileMap:
		print("🧱 COLISIÓN CON PARED - Proyectil:", projectile_id)
		_create_hit_effect()
		has_hit = true
		if not is_remote:
			Network.remove_projectile(projectile_id)
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
