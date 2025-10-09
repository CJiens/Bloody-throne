extends CharacterBody2D
class_name Player

var id: int
var hp: int = 100
var max_hp: int = 200
var animation_state: String = "Idle"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func update_animation(dir: Vector2, attacking: bool = false, rolling: bool = false):
	if not sprite:
		return

	var anim_name := "Idle"

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
		animation_state = anim_name
		Network.send_player_state(anim_name)
		sprite.play()

func _get_direction_animation(angle: float, type: String) -> String:
	if angle >= -PI / 8 and angle < PI / 8:
		sprite.scale.x = 1
		return type + "_E"
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return type + "_SE"
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return type + "_S"
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return type + "_SW"
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		sprite.scale.x = -1
		return type + "_W"
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return type + "_NW"
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return type + "_N"
	elif angle >= -3 * PI / 8 and angle < -PI / 8:
		return type + "_NE"

	return "Idle"

func take_damage(amount: int):
	hp -= amount
	print("HP restante:", hp)

	if hp <= 0:
		hp = 0
		play_death_animation()

func play_death_animation() -> void:
	if not sprite:
		get_tree().quit()
		return

	sprite.play("Die")
	Network.send_player_state("Die")
	await sprite.animation_finished
	get_tree().quit()
