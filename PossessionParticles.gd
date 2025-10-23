extends GPUParticles2D

func _ready():
	emitting = true
	# Auto-destrucción después de que termine la emisión
	await get_tree().create_timer(lifetime).timeout
	queue_free()
