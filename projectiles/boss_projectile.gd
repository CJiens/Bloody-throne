#boos_projectile.gd
extends Area2D
# -------------------------------
# --- PROPIEDADES DEL PROYECTIL
# -------------------------------
var projectile_damage: int = 25
var projectile_speed: float = 250.0
var direction: Vector2 = Vector2.ZERO
var owner_id: int = -1
var lifetime: float = 5.0
var age: float = 0.0

# Efectos visuales
@onready var sprite: Sprite2D = $Sprite2D

# -------------------------------
# --- INICIALIZACIÓN
# -------------------------------
func _ready():
	# Configurar colisiones
	set_collision_layer_value(4, true)  # Capa de proyectiles
	set_collision_mask_value(1, true)   # Colisiona con jugadores
	
	# Conectar señal de colisión
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

# -------------------------------
# --- PROCESO PRINCIPAL
# -------------------------------
func _process(delta):
	position += direction * projectile_speed * delta
	age += delta
	
	# Rotar el proyectil para efecto visual
	if sprite:
		sprite.rotation += delta * 10
	
	# Autodestrucción por tiempo
	if age >= lifetime:
		queue_free()

# -------------------------------
# --- CONFIGURACIÓN
# -------------------------------
func set_direction(new_direction: Vector2):
	direction = new_direction.normalized()

func set_damage(damage: int):
	projectile_damage = damage

func set_owner_id(id: int):
	owner_id = id

# -------------------------------
# --- COLISIONES
# -------------------------------
func _on_body_entered(body: Node):
	if body.is_in_group("players") and body.has_method("take_damage"):
		print("🎯 PROYECTIL DEL JEFE GOLPEÓ JUGADOR:", body.get_player_id())
		body.take_damage(projectile_damage)
		_explode()

func _explode():
	# Efecto de explosión (implementar según tu sistema)
	queue_free()
