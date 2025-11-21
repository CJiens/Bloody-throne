extends Area2D
class_name PistoleraProjectile

# Propiedades del proyectil ENEMIGO
var projectile_id: int = -1
var projectile_direction: Vector2 = Vector2.ZERO
var projectile_speed: float = 250.0  # Velocidad ajustada para enemigos
var projectile_damage: int = 10
var projectile_owner_id: int = -1    # ID negativo para enemigos
var enemy_team: int = 0              # Team del enemigo que dispara
var max_lifetime: float = 4.0
var lifetime: float = 0.0
var has_hit: bool = false
var is_remote: bool = false

# Nodos
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	# CONFIGURACIÓN ESPECÍFICA PARA PROYECTILES ENEMIGOS
	if not is_remote:
		area_entered.connect(_on_area_entered)
		body_entered.connect(_on_body_entered)
		
		# ✅ CONFIGURACIÓN SIMPLIFICADA - SOLO LO NECESARIO
		set_collision_layer_value(3, true)   # Layer 3: proyectiles
		set_collision_mask_value(4, true)    # ✅ SÍ detectar walls
		
		# Según el team del enemigo, detectar diferentes objetivos
		if enemy_team == 0:
			# Enemigos neutrales: detectar SOLO JUGADORES
			set_collision_mask_value(6, true)    # ✅ Hitbox de jugadores
			set_collision_mask_value(8, false)   # ❌ NO hitbox de bases
			print("🔫 PROYECTIL NEUTRAL - Target: Jugadores")
		else:
			# Enemigos con equipo: detectar SOLO BASES ENEMIGAS
			set_collision_mask_value(6, false)   # ❌ NO hitbox de jugadores  
			set_collision_mask_value(8, true)    # ✅ Hitbox de bases
			print("🔫 PROYECTIL DE EQUIPO - Target: Bases")
		
# Desactivar todas las demás máscaras
		for i in [1, 2, 5, 7]:
			set_collision_mask_value(i, false)
		
		if collision_shape:
			collision_shape.disabled = false
	else:
		# Proyectiles remotos: desactivar TODAS las colisiones
		set_collision_layer_value(3, false)
		for i in range(1, 9):
			set_collision_mask_value(i, false)
		
		if collision_shape:
			collision_shape.disabled = true
	
	print("🔫 PISTOLERA PROJECTILE CREADO - Team:", enemy_team, " Owner:", projectile_owner_id)

func _process(delta):
	if has_hit:
		return
	
	lifetime += delta
	
	# Verificar tiempo máximo de vida
	if lifetime >= max_lifetime:
		print("⏰ PROYECTIL PISTOLERA DESTRUIDO POR TIEMPO - ID:", projectile_id)
		queue_free()
		return
	
	# MOVER el proyectil
	position += projectile_direction * projectile_speed * delta
	
	# Rotar el proyectil según la dirección
	rotation = projectile_direction.angle()

# COLISIÓN CON ÁREAS (hitbox de jugadores O bases)
func _on_area_entered(area):
	if has_hit or is_remote:
		return
	
	print("🎯 COLISIÓN PISTOLERA CON HITBOX - Proyectil:", projectile_id)
	print("   - Area:", area.name, " Layers:", area.collision_layer)
	
	# ✅ DETECTAR HITBOX DE JUGADORES (solo para enemigos neutrales - team 0)
	if enemy_team == 0 and area.get_collision_layer_value(6):
		var player = area.get_parent()
		if player and player.has_method("get_player_id"):
			var player_id = player.get_player_id()
			print("💥 PROYECTIL PISTOLERA GOLPEÓ JUGADOR - Proyectil:", projectile_id, " Jugador:", player_id)
			
			# Notificar al servidor del golpe
			Network.projectile_hit_player(projectile_id, player_id, projectile_damage)
			has_hit = true
			_create_hit_effect()
			queue_free()
	
	# ✅ DETECTAR HITBOX DE BASES (solo para enemigos con equipo - team 1/2)
	elif enemy_team != 0 and area.get_collision_layer_value(8):
		var base = area.get_parent()
		if base and base.has_method("get_team"):
			var base_team = base.get_team()
			# Verificar que sea base enemiga
			if base_team != enemy_team:
				print("💥 PROYECTIL PISTOLERA GOLPEÓ BASE - Proyectil:", projectile_id, " Base Team:", base_team)
				
				# Notificar al servidor del golpe a la base
				Network.attack("base", base_team, projectile_damage)
				has_hit = true
				_create_hit_effect()
				queue_free()

# COLISIÓN CON PAREDES
func _on_body_entered(body):
	if has_hit or is_remote:
		return
	
	print("🧱 PROYECTIL PISTOLERA COLISIÓN CON PARED - ID:", projectile_id)
	
	# Colisión con paredes u objetos estáticos
	if body is StaticBody2D or body is TileMap:
		_create_hit_effect()
		has_hit = true
		queue_free()

# Inicializar el proyectil con team del enemigo
func initialize(id: int, dir: Vector2, dmg: int, owner: int, remote: bool = false, team: int = 0):
	projectile_id = id
	projectile_direction = dir.normalized()
	projectile_damage = dmg
	projectile_owner_id = owner
	is_remote = remote
	enemy_team = team
	
	print("🎯 PROYECTIL PISTOLERA INICIALIZADO - ID:", id, " Team:", team, " Damage:", dmg)

# Efecto visual al golpear
func _create_hit_effect():
	print("✨ EFECTO VISUAL PISTOLERA - Proyectil:", projectile_id)
	# Aquí se pueden agregar partículas o efectos

# Función para destrucción remota
func remote_destroy():
	print("🗑️ DESTRUCCIÓN REMOTA PISTOLERA - ID:", projectile_id)
	has_hit = true
	_create_hit_effect()
	queue_free()
