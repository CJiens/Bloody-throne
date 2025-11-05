# Base.gd
extends Node2D

var team: int = 1
var hp: int = 1000
var max_hp: int = 1000

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_bar: ProgressBar = $ProgressBar

func _ready():
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	
	# Color por equipo
	if team == 1:
		modulate = Color.BLUE
	else:
		modulate = Color.RED

func update_hp(new_hp: int):
	hp = new_hp
	hp_bar.value = hp
