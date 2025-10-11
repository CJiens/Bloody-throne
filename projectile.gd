extends Area2D

class_name Projectile

var projectile_id: int = -1
var projectile_direction: Vector2 = Vector2.ZERO
var projectile_speed: float = 400.0
var projectile_damage: int = 10
var projectile_owner_id: int = -1
var max_lifetime: float = 3.0
var lifetime: float = 0.0
var has_hit: bool = false
var is_remote: bool = false

func _ready():
	# Configurar colisiones
	body_entered.connect(_on_body_entered)
	
	print("🔧 PROYECTIL READY - ID:", projectile_id, " Owner:", projectile_owner_id, " Remote:", is_remote)
	print("   - Posición:", position)
	print("   - Dirección:", projectile_direction)
	print("   - Velocidad:", projectile_speed)
	print("   - Monitoring:", monitoring)

func _process(delta):
	if has_hit:
		return
	
	lifetime += delta
	
	# Verificar tiempo máximo de vida
	if lifetime >= max_lifetime:
		print("⏰ PROYECTIL DESTRUIDO POR TIEMPO - ID:", projectile_id)
		if not is_remote:
			Network.remove_projectile(projectile_id)
		queue_free()
		return
	
	# MOVER el proyectil - IMPORTANTE: TODOS los proyectiles se mueven
	var old_pos = position
	position += projectile_direction * projectile_speed * delta
	
	print("🔄 PROYECTIL MOVIÉNDOSE - ID:", projectile_id, " From:", old_pos, " To:", position, " Lifetime:", lifetime)
	
	# Solo el cliente propietario actualiza la posición en el servidor
	if not is_remote:
		Network.update_projectile_position(projectile_id, position.x, position.y)
	
	rotation = projectile_direction.angle()

func _on_body_entered(body):
	if has_hit or is_remote:
		return
	
	print("🎯 COLISIÓN DETECTADA - Body:", body.name, " Type:", body.get_class())
	
	# Verificar si es un jugador
	if body.has_method("get_player_id"):
		var target_id = body.get_player_id()
		print("🎯 ES JUGADOR - Target ID:", target_id, " Owner ID:", projectile_owner_id)
		
		# Solo aplicar daño si no es el propio jugador
		if target_id != projectile_owner_id:
			print("💥 APLICANDO DAÑO - Target:", target_id, " Damage:", projectile_damage)
			Network.attack("player", target_id, projectile_damage)
			
			# Marcar como golpeado y destruir SOLO si aplicó daño
			has_hit = true
			
			# Solo el propietario notifica al servidor
			if not is_remote:
				Network.remove_projectile(projectile_id)
			
			queue_free()
		else:
			print("🚫 AUTO-DAÑO IGNORADO - El proyectil continúa")
			# NO marcar has_hit = true y NO llamar queue_free()
			# El proyectil sigue su camino
	else:
		print("❌ NO ES JUGADOR - El proyectil continúa")
		# Para otros tipos de colisiones, también puedes decidir si continuar o no

func initialize(id: int, dir: Vector2, dmg: int, owner: int, remote: bool = false):
	projectile_id = id
	projectile_direction = dir.normalized()
	projectile_damage = dmg
	projectile_owner_id = owner
	is_remote = remote
	
	print("🎯 PROYECTIL INICIALIZADO - ID:", id, " Dir:", dir, " Damage:", dmg, " Owner:", owner, " Remote:", remote)