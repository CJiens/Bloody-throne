extends Area2D

class_name MageAreaProjectile

var damage: int = 10
var owner_id: int = -1
var owner_team: int = 1
var lifetime: float = 10.0
var elapsed_time: float = 0.0
var damage_interval: float = 0.5
var last_damage_time: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer

func _ready():
	print("🔥 PROYECTIL ÁREA MAGA CREADO - Posición:", position, " Duración:", lifetime, "s, Owner:", owner_id)
	
	z_index = -1
	
	# Configurar colisiones
	set_collision_layer_value(3, true)
	set_collision_mask_value(6, true)  # Jugadores
	set_collision_mask_value(7, true)  # Enemigos
	set_collision_mask_value(8, true)  # Bases
	
	# Conectar señales
	area_entered.connect(_on_area_entered)
	timer.timeout.connect(_on_timer_timeout)
	
	# Iniciar animación
	if animated_sprite:
		animated_sprite.play("start")
		await animated_sprite.animation_finished
		animated_sprite.play("burn_loop")
		timer.start(lifetime)
	else:
		print("❌ ERROR: AnimatedSprite2D no encontrado")

func _process(delta):
	elapsed_time += delta
	
	# Aplicar daño periódicamente
	if elapsed_time - last_damage_time >= damage_interval:
		last_damage_time = elapsed_time
		_apply_damage_to_all_targets()

func initialize(dmg: int, owner: int, team: int):
	damage = dmg
	owner_id = owner
	owner_team = team
	print("💥 PROYECTIL ÁREA MAGA INICIALIZADO - Daño:", damage, " Owner:", owner_id, " Team:", team)

func _on_timer_timeout():
	print("🔥 PROYECTIL ÁREA MAGA DESAPARECIENDO...")
	_start_disappear()

func _start_disappear():
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("end"):
			animated_sprite.play("end")
			await animated_sprite.animation_finished
		else:
			var tween = create_tween()
			tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0), 0.5)
			await tween.finished
	queue_free()

func _apply_damage_to_all_targets():
	var areas = get_overlapping_areas()
	var hit_count = 0
	
	for area in areas:
		if _can_damage_target(area):
			hit_count += 1
			_send_damage_to_target(area)
	
	if hit_count > 0:
		print("🔥 PROYECTIL ÁREA MAGA - Aplicando daño a", hit_count, " objetivos")

func _can_damage_target(area) -> bool:
	if not area.get_parent():
		return false
	
	# JUGADORES (layer 6) - Dañar a TODOS menos al owner
	if area.get_collision_layer_value(6):
		var player = area.get_parent()
		if player and (player.has_method("get_player_id") or "id" in player):
			var player_id = -1
			if player.has_method("get_player_id"):
				player_id = player.get_player_id()
			elif "id" in player:
				player_id = player.id
			
			# ✅ SOLO EVITAR AL OWNER, los demás SÍ reciben daño
			if player_id == owner_id:
				print("🚫 EVITANDO AUTO-DAÑO - Owner:", owner_id)
				return false
			
			print("🎯 JUGADOR PARA DAÑAR - ID:", player_id, " (Owner:", owner_id, ")")
			return true
	
	# ENEMIGOS (layer 7) - Dañar a TODOS
	elif area.get_collision_layer_value(7):
		var enemy = area.get_parent()
		if enemy and enemy.has_method("get_enemy_id"):
			print("🎯 ENEMIGO PARA DAÑAR - ID:", enemy.get_enemy_id())
			return true
	
	# BASES (layer 8) - Dañar a TODAS
	elif area.get_collision_layer_value(8):
		var base = area.get_parent()
		if base and (base.has_method("get_team") or "team" in base):
			print("🎯 BASE PARA DAÑAR")
			return true
	
	return false

func _send_damage_to_target(area):
	# JUGADORES
	if area.get_collision_layer_value(6):
		var player = area.get_parent()
		if player and (player.has_method("get_player_id") or "id" in player):
			var player_id = -1
			if player.has_method("get_player_id"):
				player_id = player.get_player_id()
			elif "id" in player:
				player_id = player.id
			
			print("🔥 ENVIANDO DAÑO A JUGADOR - ID:", player_id, " Daño:", damage)
			
			Network.socket.send_text(JSON.stringify({
				"type": "mage_area_damage_tick",
				"target_type": "player",
				"target_id": player_id,
				"damage": damage,
				"owner_id": owner_id
			}))
	
	# ENEMIGOS
	elif area.get_collision_layer_value(7):
		var enemy = area.get_parent()
		if enemy and enemy.has_method("get_enemy_id"):
			print("🔥 ENVIANDO DAÑO A ENEMIGO - ID:", enemy.get_enemy_id())
			
			Network.socket.send_text(JSON.stringify({
				"type": "mage_area_damage_tick",
				"target_type": "enemy",
				"target_id": enemy.get_enemy_id(),
				"damage": damage,
				"owner_id": owner_id
			}))
	
	# BASES
	elif area.get_collision_layer_value(8):
		var base = area.get_parent()
		var base_team = 0
		
		if base and base.has_method("get_team"):
			base_team = base.get_team()
		elif "team" in base:
			base_team = base.team
		
		print("🔥 ENVIANDO DAÑO A BASE - Team:", base_team)
		
		Network.socket.send_text(JSON.stringify({
			"type": "mage_area_damage_tick",
			"target_type": "base",
			"target_id": base_team,
			"damage": damage,
			"owner_id": owner_id
		}))

func _on_area_entered(area):
	if _can_damage_target(area):
		print("🎯 OBJETivo ENTRA EN ÁREA - Aplicando daño inmediato")
		_send_damage_to_target(area)
