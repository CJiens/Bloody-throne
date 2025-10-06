extends CharacterBody2D
class_name Player

var id: int
var hp: int = 100
var max_hp: int = 200

# -------------------------------
# --- ANIMACIONES
# -------------------------------
func update_animation(dir: Vector2, attacking: bool = false, rolling: bool = false):
	var sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return

	var anim_name = "Idle"

	if rolling:
		var vec = dir
		if vec == Vector2.ZERO:
			vec = get_global_mouse_position() - global_position
		anim_name = _get_direction_animation(vec.angle(), "roll")
	elif attacking:
		var vec = get_global_mouse_position() - global_position
		anim_name = _get_direction_animation(vec.angle(), "attack")
	elif dir != Vector2.ZERO:
		anim_name = _get_direction_animation(dir.angle(), "run")

	if sprite.animation != anim_name:
		sprite.animation = anim_name
		sprite.play()

func _get_direction_animation(angle: float, type: String) -> String:
	if angle >= -PI / 8 and angle < PI / 8:
		return type + "_E"
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return type + "_SE"
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return type + "_S"
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return type + "_SW"
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return type + "_W"
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return type + "_NW"
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return type + "_N"
	elif angle >= -3 * PI / 8 and angle < -PI / 8:
		return type + "_NE"

	return "Idle"

# -------------------------------
# --- DAÑO
# -------------------------------
func take_damage(amount: int):
	hp -= amount
	print("HP restante:", hp)
	if hp <= 0:
		queue_free()
