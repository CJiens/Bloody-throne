extends CharacterBody2D

var id: int
var hp: int
var type: String = "grunt"

@onready var network = preload("./Network.tscn")

func _process(delta):
	# IA simple (opcional)
	pass

func take_damage(amount: int):
	hp -= amount
	print(hp)
	if hp <= 0:
		queue_free()
