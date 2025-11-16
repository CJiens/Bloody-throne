#ArcherAreaProjectile.gd
extends Area2D
class_name ArcherAreaProjectile

var damage: int = 10
var owner_id: int = -1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	print("🎯 PROYECTIL ÁREA CREADO - Posición:", position)
	
	# Configurar colisiones
	set_collision_layer_value(3, true)   # Layer 3: proyectiles
	set_collision_mask_value(7, true)    # Mask 7: hitbox de enemigos
	
	# Conectar señal
	area_entered.connect(_on_area_entered)
	
	# Reproducir animación
	if animated_sprite:
		animated_sprite.play("default")
		# Auto-destrucción cuando termine la animación
		animated_sprite.animation_finished.connect(_on_animation_finished)
	else:
		print("❌ ERROR: AnimatedSprite2D no encontrado")
		queue_free()

func initialize(dmg: int, owner: int):
	damage = dmg
	owner_id = owner
	print("💥 PROYECTIL ÁREA INICIALIZADO - Daño:", damage)

func _on_animation_finished():
	print("✅ ANIMACIÓN TERMINADA - Destruyendo proyectil de área")
	queue_free()

func _on_area_entered(area):
	# Esto es solo para debug visual
	if area.get_collision_layer_value(7):  # Hitbox de enemigos
		print("🎯 PROYECTIL ÁREA - Enemigo detectado (daño manejado por servidor)")
