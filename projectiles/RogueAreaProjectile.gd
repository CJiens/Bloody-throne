#RogueAreaProjectile.gd
extends Node2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer

func _ready():
	# Iniciar la animación
	animated_sprite.play("default")
	
	# Configurar y iniciar el timer
	timer.wait_time = 1.0
	timer.start()
	
	# Conectar la señal del timer
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	# Destruir este nodo cuando el timer termine
	queue_free()
