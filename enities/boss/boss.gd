# Boss.gd
extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hptext: Label = $HPBarContainer/HPText
var boss_id: int = -1
var boss_type: String = "final_boss"
var current_phase: int = 1
var current_hp: int = 1000
var max_hp: int = 1000

# Sistema de estados
var current_state: String = "idle"
var previous_state: String = ""

# Señales para el boss
signal boss_phase_changed(phase)
signal boss_died()
signal boss_attacked(target_id, damage)
signal boss_health_updated(hp, max_hp)

func _ready():
	print("👹 BOSS INICIALIZANDO - ID:", boss_id, " Tipo:", boss_type, " Posición:", global_position)
	
	# Esperar un frame para asegurar que los nodos estén listos
	await get_tree().process_frame
	
	# Verificar que todos los nodos existan
	if animated_sprite:
		print("✅ AnimatedSprite2D encontrado")
		animated_sprite.visible = true
		
		# Verificar SpriteFrames
		if animated_sprite.sprite_frames == null:
			var anim_names = animated_sprite.sprite_frames.get_animation_names()
			print("📋 ANIMACIONES DISPONIBLES:", anim_names)
			
			# Reproducir animación por defecto
			if anim_names.has("idle"):
				play_animation("idle")
			elif anim_names.size() > 0:
				play_animation(anim_names[0])
			else:
				print("❌ NO HAY ANIMACIONES en SpriteFrames")
		else:
			print("❌ NO HAY SPRITE_FRAMES asignados")
			# Intentar cargar SpriteFrames por defecto
			var default_frames = load("res://enities/boss/boss.tres")
			if default_frames:
				animated_sprite.sprite_frames = default_frames
				print("✅ SpriteFrames por defecto cargados")
	else:
		print("❌ ANIMATED_SPRITE2D NO ENCONTRADO - Creando uno dinámicamente")
		_create_fallback_sprite()
	
	# Forzar actualización visual
	queue_redraw()
	
	print("✅ BOSS INICIALIZACIÓN COMPLETADA")

func _create_fallback_sprite():
	animated_sprite = AnimatedSprite2D.new()
	add_child(animated_sprite)
	
	# Cargar SpriteFrames por defecto
	var default_frames = load("res://enities/boss/boss.tres")
	if default_frames:
		animated_sprite.sprite_frames = default_frames
		print("🔄 AnimatedSprite2D creado dinámicamente con SpriteFrames")
	else:
		print("⚠️ No se pudieron cargar SpriteFrames por defecto")

func play_animation(anim_name: String):
	anim_name = "idle"
	if not animated_sprite:
		print("❌ animated_sprite es null en play_animation")
		return
		
	if not is_instance_valid(animated_sprite):
		print("❌ animated_sprite no es válido")
		return
		
	if not animated_sprite.sprite_frames:
		print("❌ No hay sprite_frames asignados")
		return
	
	# Verificar si la animación existe
	if animated_sprite.sprite_frames.has_animation(anim_name):
		if current_state != anim_name:
			previous_state = current_state
			current_state = anim_name
			
			animated_sprite.play(anim_name)
			print("🎭 BOSS CAMBIA ANIMACIÓN: ", previous_state, " -> ", anim_name)
			
			# Forzar actualización visual
			animated_sprite.visible = true
			animated_sprite.modulate = Color.WHITE
			queue_redraw()
	else:
		print("❌ Animación '", anim_name, "' no encontrada. Animaciones disponibles: ", animated_sprite.sprite_frames.get_animation_names())
		
		# Fallback a idle o primera animación disponible
		var available = animated_sprite.sprite_frames.get_animation_names()
		if available.has("idle"):
			animated_sprite.play("idle")
			current_state = "idle"
		elif available.size() > 0:
			animated_sprite.play(available[0])
			current_state = available[0]

func set_boss_id(id: int):
	boss_id = id
	name = "Boss_" + str(id)
	print("🆔 BOSS ID ASIGNADO:", id)

func set_boss_type(type: String):
	boss_type = type
	print("🎯 BOSS TIPO ASIGNADO:", type)

func update_hp(hp: int):
	current_hp = hp
	hptext.text = str(current_hp) + "/" + str(max_hp)
	print("❤️ BOSS HP ACTUALIZADO:", current_hp, "/", max_hp)
	emit_signal("boss_health_updated", current_hp, max_hp)

func _transition_to_phase(phase: int):
	current_phase = phase
	print("🔥 BOSS CAMBIA A FASE:", phase)
	
	# Efectos visuales para cambio de fase
	match phase:
		2:
			modulate = Color(1.0, 0.6, 0.3)
			play_animation("phase2")
			print("🎨 Cambiando color a Fase 2")
		3:
			modulate = Color(1.0, 0.3, 0.2)
			play_animation("phase3")
			print("🎨 Cambiando color a Fase 3")
	
	emit_signal("boss_phase_changed", phase)

func get_enemy_type() -> String:
	return boss_type

# Función para debug visual
func _draw():
	# Dibujar un círculo de colisión temporal para verificar posición
	draw_circle(Vector2.ZERO, 50, Color(1, 0, 0, 0.3))
	
	# Dibujar texto de debug
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	draw_string(font, Vector2(-30, -60), "BOSS " + str(boss_id), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

# Función para forzar visibilidad (debug)
func force_visibility():
	visible = true
	modulate = Color.WHITE
	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.modulate = Color.WHITE
	queue_redraw()
